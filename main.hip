#include <iostream>
#include <limits>
#include "hip/hip_runtime.h"

using namespace std;

class Graph {
public:
    Graph(int vertices[], int numberOfVertices, int edges[], int numberOfEdges);
    void bfs(int startVertex);

private:
    int *vertices;
    int numberOfVertices;
    int *edges;
    int numberOfEdges;
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

__global__ void bfsKernel(int vertices[], int edges[], bool frontier[], bool visited[], int cost[]) {
    int tid = hipBlockIdx_x * hipBlockDim_x + hipThreadIdx_x;

    if (tid < 4 && frontier[tid]) {
        printf("Thread ID: %d\n", tid);
        frontier[tid] = false;
        visited[tid] = true;

        // for all neighbors
        int nid = vertices[tid];
        while (edges[nid] != -1) {
            int neighbor = edges[nid];

            if (neighbor >= 0 && neighbor < 4) {
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
    int *d_vertices, *d_edges, *d_cost;
    bool *d_frontier, *d_visited;

    hipMalloc((void**)&d_vertices, numberOfVertices * sizeof(int));
    hipMalloc((void**)&d_edges, numberOfEdges * sizeof(int));
    hipMalloc((void**)&d_frontier, numberOfVertices * sizeof(bool));
    hipMalloc((void**)&d_visited, numberOfVertices * sizeof(bool));
    assert(hipMalloc((void**)&d_cost, numberOfVertices * sizeof(int)) == hipSuccess);

    // Copy data to GPU
    hipMemcpy(d_vertices, vertices, numberOfVertices * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_edges, edges, numberOfEdges * sizeof(int), hipMemcpyHostToDevice);
    hipMemcpy(d_frontier, frontier, numberOfVertices * sizeof(bool), hipMemcpyHostToDevice);
    hipMemcpy(d_visited, visited, numberOfVertices * sizeof(bool), hipMemcpyHostToDevice);
    assert(hipMemcpy(d_cost, cost, numberOfVertices * sizeof(int), hipMemcpyHostToDevice) == hipSuccess);

    const unsigned threadsPerBlock = 256;
    const unsigned blocks = (numberOfVertices + threadsPerBlock - 1) / threadsPerBlock;
    setbuf(stdout, NULL);
    while (true) {
        // call kernel
        hipLaunchKernelGGL(bfsKernel, dim3(blocks), dim3(threadsPerBlock), 0, 0, d_vertices, d_edges, d_frontier, d_visited, d_cost);

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

    for (auto i = 0; i < numberOfVertices; ++i) {
        cout << "Distance from " << startVertex << " to " << i << " is: " << cost[i] << endl;
    }

    delete [] frontier;
    delete [] visited;
    delete [] cost;
}

int main(void) {

    hipDeviceProp_t devProp;
    hipGetDeviceProperties(&devProp, 1);
    cout << " System minor " << devProp.minor << endl;
    cout << " System major " << devProp.major << endl;
    cout << " agent prop name " << devProp.name << endl;

    int vertices[] = { 0, 3, 5, 7 };
    int numberOfVertices = 4;

    int edges[] = { 2, 3, -1, 3, -1, 0, -1, 2, 2, -1 };
    int numberOfEdges = 10;

    Graph g(vertices, numberOfVertices, edges, numberOfEdges);

    g.bfs(0);

    return 0;
}

