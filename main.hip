#include "csv_loader.h"

#include <bits/chrono.h>
#include <chrono>
#include <iostream>
#include <limits>
#include <list>
#include <set>
#include <string>
#include <vector>
#include "hip/hip_runtime.h"

using namespace std;

class Graph {
public:
    Graph(int vertices[], int numberOfVertices, int edges[], int numberOfEdges);
    void bfs(int startVertex);
    void bfsCPU(int startVertex);
    ~Graph();
    int numberOfVertices;
    int numberOfEdges;

private:
    int *vertices;
    int *edges;
};

// TODO: Migrate to list or vector, add cpu bfs, write tests, load large csv and benchmark

Graph::Graph(int vertices[], int numberOfVertices, int edges[], int numberOfEdges) {
    this->vertices = new int[numberOfVertices];
    for (auto i = 0; i < numberOfVertices; ++i) {
        this->vertices[i] = vertices[i];
    }
    this->numberOfVertices = numberOfVertices;

    this->edges = new int[numberOfEdges];
    for (auto i = 0; i < numberOfEdges; ++i) {
        this->edges[i] = edges[i];
    }
    this->numberOfEdges = numberOfEdges;
}

Graph::~Graph() {
    delete[] vertices;
    delete[] edges;
}

__global__ void bfsKernel(const int vertices[], const int edges[], bool frontier[], bool visited[], int cost[], const int* numberOfVerticesPointer) {
    int tid = hipBlockIdx_x * hipBlockDim_x + hipThreadIdx_x;
    int numberOfVertices = *numberOfVerticesPointer;

    if (tid < numberOfVertices && frontier[tid]) {
        // printf("Thread ID: %d\n", tid);
        frontier[tid] = false;
        visited[tid] = true;

        // for all neighbors
        int nid = vertices[tid];
        while (edges[nid] != -1) {
            int neighbor = edges[nid];

            if (neighbor >= 0 && neighbor < numberOfVertices) {
              if (!visited[neighbor]) {
                cost[neighbor] = cost[tid] + 1;
                frontier[neighbor] = true;
              }
            }

            nid++;
        }
    }
}

void Graph::bfs(int startVertex) {
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

    hipMalloc((void**)&d_vertices, numberOfVertices * sizeof(int));
    hipMalloc((void**)&d_edges, numberOfEdges * sizeof(int));
    hipMalloc((void**)&d_frontier, numberOfVertices * sizeof(bool));
    hipMalloc((void**)&d_visited, numberOfVertices * sizeof(bool));
    hipMalloc((void**)&d_cost, numberOfVertices * sizeof(int));
    hipMalloc((void**)&d_numberOfVertices, sizeof(int));

    // Copy data to GPU
    hipMemcpy(d_vertices, vertices, numberOfVertices * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_edges, edges, numberOfEdges * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_frontier, frontier, numberOfVertices * sizeof(bool), hipMemcpyHostToDevice);
    hipMemcpy(d_visited, visited, numberOfVertices * sizeof(bool), hipMemcpyHostToDevice);
    hipMemcpy(d_cost, cost, numberOfVertices * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_numberOfVertices, &numberOfVertices, sizeof(int), hipMemcpyHostToDevice);

    const unsigned threadsPerBlock = 256;
    const unsigned blocks = (numberOfVertices + threadsPerBlock - 1) / threadsPerBlock;

    while (true) {
        // call kernel
        hipLaunchKernelGGL(bfsKernel, dim3(blocks), dim3(threadsPerBlock), 0, 0, d_vertices, d_edges, d_frontier, d_visited, d_cost, d_numberOfVertices);

        // we only process one BFS level at a time so we wait:
        hipDeviceSynchronize();

        // copy visited array back to CPU so we can perform the while loop condition check
        hipMemcpy(frontier, d_frontier, numberOfVertices * sizeof(bool), hipMemcpyDeviceToHost);

        // check if we're done
        bool frontierEmpty = true;
        for (auto i = 0; i < numberOfVertices; ++i) {
            if (frontier[i]) {
                frontierEmpty = false;
                break;
            }
        }
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

    delete [] frontier;
    delete [] visited;
    delete [] cost;
}

void Graph::bfsCPU(int startVertex) { 
    vector<bool> visited(numberOfVertices, false);
    vector<int> cost(numberOfVertices, numeric_limits<int>::max());
    list<int> queue;

    visited[startVertex] = true;
    cost[startVertex] = 0;
    queue.push_back(startVertex);

    printf("\n");
    int maxCost = 0;
    while(!queue.empty()) {
        int currentPointer = queue.front();
        queue.pop_front();

        for (int i = currentPointer; edges[i] != -1; ++i) {
            int neighbor = edges[i];

            if (!visited[neighbor] && neighbor < numberOfVertices) {
                cost[neighbor] = cost[currentPointer] + 1;
                maxCost = max(cost[neighbor], maxCost);
                printf("\rCurrent level: %d", maxCost);
                visited[neighbor] = true;
                queue.push_back(neighbor);
            }
        }
    }
    printf("\n");
}
/**
 * Turns a csv file into a Graph. Assumes the following csv structure:
 * "from vertex, to vertex"
 * - where the from vertex column is ordered in ascending order
 * - there are no duplicates
 * - there is no header row
 */
Graph* csvToGraph(string filePath, bool reverseColumns) {
    vector<array<int, 2>> csvRows = CSVLoader::readCSV(filePath);
    vector<int> vertexPointers { 0 };
    vector<int> destinations;
    
    int currentVertex = 0;
    int previousPointer = 0;
    printf("Number of CSV rows: %zu\n", csvRows.size());
    for (int i = 0; i < csvRows.size(); ++i) {
        int fromVertexColumn = reverseColumns ? 1 : 0;
        int toVertexColumn = reverseColumns ? 0 : 1;
        int fromVertex = csvRows[i][fromVertexColumn] - 1;
        int toVertex = csvRows[i][toVertexColumn] - 1;

        if (currentVertex != fromVertex) {
            destinations.push_back(-1);
            destinations.push_back(toVertex);
            previousPointer += 2;
            vertexPointers.push_back(previousPointer);
            currentVertex = fromVertex;
        } else {
            destinations.push_back(toVertex);
            previousPointer++;
        }
    }

    int numberOfVertices = vertexPointers.size();
    int* vertices = &vertexPointers[0];
    int numberOfEdges = destinations.size();
    int* edges = &destinations[0];

    return new Graph(vertices, numberOfVertices, edges, numberOfEdges);
}

int main(void) {

    setbuf(stdout, NULL);

    hipDeviceProp_t devProp;
    hipGetDeviceProperties(&devProp, 1);
    cout << " System minor " << devProp.minor << endl;
    cout << " System major " << devProp.major << endl;
    cout << " agent prop name " << devProp.name << endl;

    Graph* g = csvToGraph("/home/marius/Developer/ogb/edges.csv", true);

    printf("Number of vertices: %d\n", g->numberOfVertices);
    printf("Number of edges: %d\n", g->numberOfEdges);
    printf("True number of edges: %d\n", g->numberOfEdges - g->numberOfVertices);

    // g.bfs(4);
    
    for (int i = 60000; i < 60009; ++i) {
        // auto t1 = chrono::high_resolution_clock::now();
        // g->bfsCPU(i);
        // auto t2 = chrono::high_resolution_clock::now();
        // auto ms_int = chrono::duration_cast<chrono::milliseconds>(t2 - t1);
        // printf("CPU: %ldms\n", ms_int.count());

        auto tgpu1 = chrono::high_resolution_clock::now();
        g->bfs(i);
        auto tgpu2 = chrono::high_resolution_clock::now();
        auto ms_gpu = chrono::duration_cast<chrono::milliseconds>(tgpu2 - tgpu1);
        printf("GPU: %ldms\n", ms_gpu.count());
    }

    delete g;

    return 0;
}

