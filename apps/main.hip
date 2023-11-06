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


// TODO: Migrate to list or vector, add cpu bfs, write tests, load large csv and benchmark


int main(void) {
    setbuf(stdout, NULL);

    Graph* g = csvToGraph("/home/marius/Developer/ogb/edges.csv", true);

    printf("Number of vertices: %d\n", g->numberOfVertices);
    printf("Size of edge array: %d\n", g->numberOfEdges);
    printf("... minus number of vertices: %d\n", g->numberOfEdges - g->numberOfVertices);

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

