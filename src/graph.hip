#include <hip/hip_runtime.h>
#include <limits>
#include <list>
#include <vector>

#include "csv_loader.hpp"
#include "graph.hpp"


// TODO: Sometimes two threads access the same element in frontier array. This likely causes the crash.
// Most efficient solution: Go straight to Merrils BFS, since that's what we want anyway

using namespace std;

Graph::Graph(int vertices[], const int numberOfVertices, int edges[], const int numberOfEdges)
    : numberOfVertices(numberOfVertices), numberOfEdges(numberOfEdges) {
    this->vertices = new int[numberOfVertices];
    for (auto i = 0; i < numberOfVertices; ++i) {
        this->vertices[i] = vertices[i];
    }

    this->edges = new int[numberOfEdges];
    for (auto i = 0; i < numberOfEdges; ++i) {
        this->edges[i] = edges[i];
    }
}

/**
 * Turns a csv file into a Graph. Assumes the following csv structure:
 * "from vertex, to vertex"
 * - where the from vertex column is ordered in ascending order
 * - there are no duplicates
 * - there is no header row
 */
Graph::Graph(const string csvFilePath, const bool reverseColumns, const int numberOfVertices, const int numberOfEdges)
    : numberOfVertices(numberOfVertices), numberOfEdges(numberOfEdges) {
    vector<array<int, 2>> csvRows = CSVLoader::readCSV(csvFilePath);
    vertices = new int[numberOfVertices];
    int edgesArraySize = numberOfEdges + numberOfVertices;
    edges = new int[edgesArraySize];

    for (int i = 0; i < numberOfVertices; ++i) {
        // by default point all vertices to the last element in edges, which will always be -1, and thus represent a
        // vertex without any edges
        vertices[i] = edgesArraySize - 1;
    }

    for (int i = 0; i < edgesArraySize; ++i) {
        edges[i] = -1;
    }

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

Graph::~Graph() {
    delete[] vertices;
    delete[] edges;
}

__global__ void bfsKernel(const int vertices[], const int edges[], bool frontier[], bool visited[], int cost[],
                          const int *numberOfVerticesPointer) {
    int tid = hipBlockIdx_x * hipBlockDim_x + hipThreadIdx_x;
    int numberOfVertices = *numberOfVerticesPointer;

    if (tid < numberOfVertices && frontier[tid]) {
        frontier[tid] = false;
        visited[tid] = true;

        // for all neighbors
        int edgeOffset = vertices[tid];
        for (int i = edgeOffset; edges[i] != -1; ++i) {
            int neighbor = edges[i];

            if (!visited[neighbor]) {
                printf("Thread ID: %d. Neighbor: %d\n", tid, neighbor);
                cost[neighbor] = cost[tid] + 1;
                frontier[neighbor] = true;
            }
        }
    }
}

vector<int> Graph::bfs(int startVertex) {
    bool *frontier = new bool[numberOfVertices];
    for (auto i = 0; i < numberOfVertices; ++i) {
        frontier[i] = false;
    }

    bool *visited = new bool[numberOfVertices];
    for (auto i = 0; i < numberOfVertices; ++i) {
        visited[i] = false;
    }

    int *cost = new int[numberOfVertices];
    for (auto i = 0; i < numberOfVertices; ++i) {
        cost[i] = numeric_limits<int>::max();
    }

    frontier[startVertex] = true;
    cost[startVertex] = 0;

    // Allocate GPU memory
    int *d_vertices, *d_edges, *d_cost, *d_numberOfVertices;
    bool *d_frontier, *d_visited;

    hipMalloc((void **)&d_vertices, numberOfVertices * sizeof(int));
    hipMalloc((void **)&d_edges, numberOfEdges * sizeof(int));
    hipMalloc((void **)&d_frontier, numberOfVertices * sizeof(bool));
    hipMalloc((void **)&d_visited, numberOfVertices * sizeof(bool));
    hipMalloc((void **)&d_cost, numberOfVertices * sizeof(int));
    hipMalloc((void **)&d_numberOfVertices, sizeof(int));

    // Copy data to GPU
    hipMemcpy(d_vertices, vertices, numberOfVertices * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_edges, edges, numberOfEdges * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_frontier, frontier, numberOfVertices * sizeof(bool), hipMemcpyHostToDevice);
    hipMemcpy(d_visited, visited, numberOfVertices * sizeof(bool), hipMemcpyHostToDevice);
    hipMemcpy(d_cost, cost, numberOfVertices * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_numberOfVertices, &numberOfVertices, sizeof(int), hipMemcpyHostToDevice);

    const unsigned threadsPerBlock = 256;
    const unsigned blocks = (numberOfVertices + threadsPerBlock - 1) / threadsPerBlock;
   
    int level = 0;
    while (true) {
        printf("Level: %d\n\n", level);
        level++;
        // call kernel
        hipLaunchKernelGGL(bfsKernel, dim3(blocks), dim3(threadsPerBlock), 0, 0, d_vertices, d_edges, d_frontier,
                           d_visited, d_cost, d_numberOfVertices);

        // we only process one BFS level at a time so we wait:
        hipDeviceSynchronize();

        // copy visited array back to CPU so we can perform the while loop condition check
        hipMemcpy(frontier, d_frontier, numberOfVertices * sizeof(bool), hipMemcpyDeviceToHost);
        
        // check if we're done
        bool frontierEmpty = true;
        for (auto i = 0; i < numberOfVertices; ++i) {
            printf("%d, ", frontier[i]);
            if (frontier[i]) {
                frontierEmpty = false;
                break;
            }
        }
        printf("\n");
        if (frontierEmpty) {
            break;
        }
    }

    // copy cost array back to CPU so we can get the results
    hipMemcpy(cost, d_cost, numberOfVertices * sizeof(int), hipMemcpyDeviceToHost);

    hipFree(d_vertices);
    hipFree(d_edges);
    hipFree(d_cost);
    hipFree(d_frontier);
    hipFree(d_visited);
    hipFree(d_numberOfVertices);

    /* for (auto i = 0; i < numberOfVertices; ++i) {
        cout << "Distance from " << startVertex << " to " << i << " is: " << cost[i] << endl;
    }*/

    vector<int> vectorCost;
    vectorCost.resize(numberOfVertices);

    for (int i = 0; i < numberOfVertices; ++i) {
        vectorCost[i] = cost[i];
    }

    delete[] frontier;
    delete[] visited;
    delete[] cost;

    return vectorCost;
}

vector<int> Graph::bfsCPU(int startVertex) {
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
