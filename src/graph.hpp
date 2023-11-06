#ifndef GRAPH
#define GRAPH

#include <string>

class Graph {
  public:
    Graph(int vertices[], const int numberOfVertices, int edges[], const int numberOfEdges);
    Graph(const std::string csvFilePath, const bool reverseColumns, const int numberOfVertices, const int numberOFEdges);
    void bfs(int startVertex);
    void bfsCPU(int startVertex);
    ~Graph();
    const int numberOfVertices;
    const int numberOfEdges;
    int *vertices;
    int *edges;
};

#endif
