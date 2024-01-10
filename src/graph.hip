#include <hip/amd_detail/amd_hip_runtime.h>
#include <hip/driver_types.h>
#include <hip/hip_runtime.h>
#include <limits>
#include <list>
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
Graph::Graph(const string csvFilePath, const bool reverseColumns, const size_t numberOfVertices, const size_t numberOfEdges) {
    vector<array<int, 2>> csvRows = CSVLoader::readCSV(csvFilePath, numberOfEdges);
    int edgesArraySize = numberOfEdges + numberOfVertices;
    edges = vector<int>(edgesArraySize, -1);
    // by default point all vertices to the last element in edges, which will always be -1, and thus represent a
    // vertex without any edges
    vertices = vector<int>(numberOfVertices, edgesArraySize - 1);

    vertices[0] = 0;
    int currentVertex = 0;
    int previousPointer = -1;
    bool isFirstVertex = true;
    printf("Constructing graph from csv...\n");
    for (int i = 0; i < csvRows.size(); ++i) {
        int fromVertexColumn = reverseColumns ? 1 : 0;
        int toVertexColumn = reverseColumns ? 0 : 1;
        int fromVertex = csvRows[i][fromVertexColumn] - 1;
        int toVertex = csvRows[i][toVertexColumn] - 1;

        if (currentVertex != fromVertex && !isFirstVertex) {
            previousPointer += 2; // jump over the -1 separator
            edges[previousPointer] = toVertex;
            vertices[fromVertex] = previousPointer;
            currentVertex = fromVertex;
        } else {
            previousPointer++;
            edges[previousPointer] = toVertex;
            isFirstVertex = false;
        }
    }
    printf("Successfully constructed graph from CSV (%zu vertices, %zu edges)\n", vertices.size(),
           edges.size() - vertices.size());
}

Graph::~Graph() {}

__global__ void bfsKernel(int *d_edges, int *d_edgesOffset, int *d_distance, int *changed, int N, int level) {
    int thid = blockIdx.x * blockDim.x + threadIdx.x;
    int valueChange = 0;

    if (thid < N && d_distance[thid] == level) {
        int u = thid;
        for (int i = d_edgesOffset[u]; d_edges[i] != -1; i++) {
            int v = d_edges[i];
            if (level + 1 < d_distance[v]) {
                atomicExch(&d_distance[v], level + 1);
                d_distance[v] = level + 1;
                valueChange = 1;
            }
        }
    }

    if (valueChange) {
        atomicMax(changed, valueChange);
    }
}

vector<int> Graph::bfsGPU(int startVertex, int maxLevel) {
    const size_t numberOfVertices = vertices.size();
    const size_t numberOfEdges = edges.size();
    vector<int> distance(numberOfVertices, numeric_limits<int>::max());
    const int workgroup_size = 1024;
    const int n_blocks = (numberOfVertices + workgroup_size - 1) / workgroup_size;

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
    const size_t size = numberOfVertices * sizeof(int);
    const size_t adjacencySize = numberOfEdges * sizeof(int);
    printf("Allocating %f GB for adjacency list\n", static_cast<double>(adjacencySize) / (1024 * 1024 * 1024));
    HIP_CHECK(hipMalloc((void **)&d_adjacencyList, adjacencySize));
    HIP_CHECK(hipMalloc((void **)&d_edgesOffset, size));
    HIP_CHECK(hipMalloc((void **)&d_changed, sizeof(int)));
    HIP_CHECK(hipMalloc((void **)&d_distance, size));

    // Copy inputs to device

    HIP_CHECK(hipMemcpy(d_adjacencyList, edges.data(), adjacencySize, hipMemcpyHostToDevice));
    HIP_CHECK(hipMemcpy(d_edgesOffset, vertices.data(), size, hipMemcpyHostToDevice));
    HIP_CHECK(hipMemcpy(d_changed, &changed, sizeof(int), hipMemcpyHostToDevice));

    auto startTime = chrono::steady_clock::now();
    distance = vector<int>(numberOfVertices, INT_MAX);
    distance[startVertex] = 0;
    HIP_CHECK(hipMemcpy(d_distance, distance.data(), size, hipMemcpyHostToDevice));

    while (changed && ((maxLevel == -1) ? true : level <= maxLevel)) {
        printf("Level %d\r", level);
        changed = 0;
        HIP_CHECK(hipMemcpy(d_changed, &changed, sizeof(int), hipMemcpyHostToDevice));
        // computeNextQueue<<<n_blocks, N_THREADS_PER_BLOCK>>> (d_adjacencyList,
        // d_edgesOffset, d_edgesSize, d_distance, currentQueueSize, d_currentQueue,
        // d_nextQueueSize, d_nextQueue, level);
        // hipLaunchKernelGGL(bfsKernel, dim3(n_blocks), dim3(N_THREADS_PER_BLOCK),
        // 0, 0, G.numVertices, level, d_adjacencyList, d_edgesOffset, d_edgesSize,
        // d_distance, d_changed);
        hipLaunchKernelGGL(bfsKernel, dim3(n_blocks), dim3(workgroup_size), 0, 0, d_adjacencyList, d_edgesOffset, d_distance,
                           d_changed, numberOfVertices, level);
        HIP_CHECK(hipDeviceSynchronize());
        ++level;
        HIP_CHECK(hipMemcpy(&changed, d_changed, sizeof(int), hipMemcpyDeviceToHost));
    }

    printf("Level %d\n", level);

    HIP_CHECK(hipMemcpy(&distance[0], d_distance, size, hipMemcpyDeviceToHost));
    auto endTime = std::chrono::steady_clock::now();
    auto duration = chrono::duration_cast<chrono::milliseconds>(endTime - startTime).count();
    printf("Elapsed time for GPU implementation (without copying graph) : %li ms.\n", duration);

    // Cleanup
    HIP_CHECK(hipFree(d_adjacencyList));
    HIP_CHECK(hipFree(d_edgesOffset));
    HIP_CHECK(hipFree(d_changed));
    HIP_CHECK(hipFree(d_distance));

    return distance;
}

vector<int> Graph::bfsCPU(int startVertex) {
    auto startTime = chrono::steady_clock::now();
    const int numberOfVertices = vertices.size();

    vector<bool> visited(numberOfVertices, false);
    vector<int> cost(numberOfVertices, numeric_limits<int>::max());
    list<int> queue;

    visited[startVertex] = true;
    cost[startVertex] = 0;
    queue.push_back(startVertex);

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
    auto endTime = std::chrono::steady_clock::now();
    auto duration = chrono::duration_cast<chrono::milliseconds>(endTime - startTime).count();
    printf("Elapsed time for CPU implementation: %li ms.\n", duration);
    return cost;
}
