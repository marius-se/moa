#ifndef GRAPH
#define GRAPH

#include <string>
#include <vector>

class Graph {
  public:
    Graph(int vertices[], const int numberOfVertices, int edges[], const int numberOfEdges);
    Graph(const std::string csvFilePath, const bool reverseColumns, const int numberOfVertices, const int numberOFEdges);
    std::vector<int> bfs(int startVertex);
    std::vector<int> bfsCPU(int startVertex);
    ~Graph();
    const int numberOfVertices;
    const int numberOfEdges;
    int *vertices;
    int *edges;
};

#endif
