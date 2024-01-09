#include <algorithm>
#include <hip/amd_detail/amd_hip_runtime.h>
#include <hip/driver_types.h>
#include <hip/hip_runtime.h>
#include <iostream>
#include <limits>
#include <list>
#include <map>
#include <vector>

#include "csv_loader.hpp"
#include "graph.hpp"
#include "hip_macros.hpp"

// TODO: Sometimes two threads access the same element in frontier array. This likely causes the crash.
// Most efficient solution: Go straight to Merrils BFS, since that's what we want anyway

using namespace std;

Graph::Graph(vector<int> vertices, vector<int> edges) : vertices(vertices), edges(edges) {}

/**
 * Turns a csv file into a Graph. Assumes the following csv structure:
 * "from vertex, to vertex"
 * - where the from vertex column is ordered in ascending order
 * - there are no duplicates
 * - there is no header row
 */
Graph::Graph(const string csvFilePath, const bool reverseColumns, const int numberOfVertices, const int numberOfEdges) {
    vector<array<int, 2>> csvRows = CSVLoader::readCSV(csvFilePath);
    int edgesArraySize = numberOfEdges + numberOfVertices;
    this->edges = vector<int>(edgesArraySize, -1);
    cout << edges.size() << endl;
    // by default point all vertices to the last element in edges, which will always be -1, and thus represent a
    // vertex without any edges
    this->vertices = vector<int>(numberOfVertices, edgesArraySize - 1); 

    vertices[0] = 0;
    int currentVertex = 0;
    int previousPointer = -1;
    printf("Number of CSV rows: %zu\n", csvRows.size());
    for (int i = 0; i < csvRows.size(); ++i) {
        int fromVertexColumn = reverseColumns ? 1 : 0;
        int toVertexColumn = reverseColumns ? 0 : 1;
        int fromVertex = csvRows[i][fromVertexColumn] - 1;
        int toVertex = csvRows[i][toVertexColumn] - 1;

        if (currentVertex != fromVertex) {
            previousPointer += 2; // jump over the -1 separator
            edges[previousPointer] = toVertex;
            vertices[fromVertex] = previousPointer;
            currentVertex = fromVertex;
        } else {
            previousPointer++;
            edges[previousPointer] = toVertex;
        }
    }
}

Graph::~Graph() {}

__global__ void simpleBfs(int N, int level, int *d_adjacencyList, int *d_edgesOffset, int *d_distance, int *d_parent,
                          int *changed) {
    int thid = blockIdx.x * blockDim.x + threadIdx.x;
    int valueChange = 0;

    printf("thid: %d. d_distance[thid]: %d. Level: %d\n", thid, d_distance[thid], level);
    if (thid < N && d_distance[thid] == level) {
        printf("N: %d. Level: %d. Changed: %d\n", N, level, *changed);
        int u = thid;
        for (int i = d_edgesOffset[u]; d_adjacencyList[i] != -1; i++) {
            int v = d_adjacencyList[i];
            if (level + 1 < d_distance[v]) {
                // d_distance[v] = level + 1;
                // d_parent[v] = i;
                valueChange = 1;
            }
        }
    }

    if (valueChange) {
        *changed = valueChange;
    }
}

__global__ void bfsKernel(int *d_edges, int *d_edgesOffset, int *d_distance, int *changed, int N, int level) {
    int thid = blockIdx.x * blockDim.x + threadIdx.x;
    int valueChange = 0;

    if (thid < N && d_distance[thid] == level) {
        int u = thid;
        for (int i = d_edgesOffset[u]; d_edges[i] != -1; i++) {
            int v = d_edges[i];
            if (level + 1 < d_distance[v]) {
                d_distance[v] = level + 1;
                valueChange = 1;
            }
        }
    }

    if (valueChange) {
        atomicMax(changed, valueChange);
    }
}

vector<int> Graph::bfsGPU(int startVertex) {
    const int numberOfVertices = vertices.size();
    const int numberOfEdges = edges.size();
    vector<int> distance(numberOfVertices, numeric_limits<int>::max());
    const int n_blocks = (numberOfVertices + 256 - 1) / 256;

    // Initialization of GPU variables
    int *d_adjacencyList;
    int *d_edgesOffset;
    int *d_edgesSize;
    int *d_changed;
    int *d_distance; // output

    // Initialization of CPU variables
    int level = 0;
    int changed = 1;

    // Allocation on device
    const int size = numberOfVertices * sizeof(int);
    const int adjacencySize = (numberOfEdges + numberOfVertices) * sizeof(int);
    hipMalloc((void **)&d_adjacencyList, adjacencySize);
    hipMalloc((void **)&d_edgesOffset, size);
    hipMalloc((void **)&d_edgesSize, size);
    hipMalloc((void **)&d_changed, sizeof(int));
    hipMalloc((void **)&d_distance, size);

    // Copy inputs to device

    hipMemcpy(d_adjacencyList, edges.data(), adjacencySize, hipMemcpyHostToDevice);
    hipMemcpy(d_edgesOffset, vertices.data(), size, hipMemcpyHostToDevice);
    hipMemcpy(d_changed, &changed, sizeof(int), hipMemcpyHostToDevice);

    auto startTime = chrono::steady_clock::now();
    distance = vector<int>(numberOfVertices, INT_MAX);
    distance[startVertex] = 0;
    hipMemcpy(d_distance, distance.data(), size, hipMemcpyHostToDevice);

    while (changed) {
        changed = 0;
        hipMemcpy(d_changed, &changed, sizeof(int), hipMemcpyHostToDevice);
        // computeNextQueue<<<n_blocks, N_THREADS_PER_BLOCK>>> (d_adjacencyList,
        // d_edgesOffset, d_edgesSize, d_distance, currentQueueSize, d_currentQueue,
        // d_nextQueueSize, d_nextQueue, level);
        // hipLaunchKernelGGL(bfsKernel, dim3(n_blocks), dim3(N_THREADS_PER_BLOCK),
        // 0, 0, G.numVertices, level, d_adjacencyList, d_edgesOffset, d_edgesSize,
        // d_distance, d_changed);
        hipLaunchKernelGGL(bfsKernel, dim3(n_blocks), dim3(256), 0, 0, d_adjacencyList, d_edgesOffset, d_distance,
                           d_changed, numberOfVertices, level);
        hipDeviceSynchronize();
        ++level;
        hipMemcpy(&changed, d_changed, sizeof(int), hipMemcpyDeviceToHost);
    }

    hipMemcpy(&distance[0], d_distance, size, hipMemcpyDeviceToHost);
    auto endTime = std::chrono::steady_clock::now();
    auto duration = chrono::duration_cast<chrono::milliseconds>(endTime - startTime).count();
    printf("Elapsed time for naive linear GPU implementation (without copying "
           "graph) : %li ms.\n",
           duration);

    // Cleanup
    hipFree(d_adjacencyList);
    hipFree(d_edgesOffset);
    hipFree(d_edgesSize);
    hipFree(d_changed);
    hipFree(d_distance);

    return distance;
}

vector<int> Graph::bfsCPU(int startVertex) {
    const int numberOfVertices = vertices.size();
    const int numberOfEdges = edges.size();

    vector<bool> visited(numberOfVertices, false);
    vector<int> cost(numberOfVertices, numeric_limits<int>::max());
    list<int> queue;

    visited[startVertex] = true;
    cost[startVertex] = 0;
    queue.push_back(startVertex);

    printf("\n");
    while (!queue.empty()) {
        int vertex = queue.front();
        queue.pop_front();

        int edgesOffset = vertices[vertex];

        // loop over all edges from currentPointer on to next -1 separator
        for (int i = edgesOffset; edges[i] != -1; ++i) {
            int neighbor = edges[i];

            if (!visited[neighbor]) {
                cost[neighbor] = cost[vertex] + 1;
                visited[neighbor] = true;
                queue.push_back(neighbor);
            }
        }
    }
    printf("\n");
    return cost;
}
