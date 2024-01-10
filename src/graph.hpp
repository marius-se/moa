#ifndef GRAPH
#define GRAPH

#include <string>
#include <vector>

class Graph {
  public:
    Graph(std::vector<int> vertices, std::vector<int> edges);
    Graph(const std::string csvFilePath, const bool reverseColumns, const size_t numberOfVertices,
          const size_t numberOFEdges);
    std::vector<int> bfsCPU(int startVertex);
    std::vector<int> bfsGPU(int startVertex, int maxLevel = -1);
    ~Graph();
    std::vector<int> vertices;
    std::vector<int> edges;
};

#endif
