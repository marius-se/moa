#include <bits/chrono.h>
#include <graph.hpp>
#include <vector>

using namespace std;

int main(void) {
    Graph graph("/home/marius/Developer/edges.csv", true, 111059956, 1615685872);

    // 0 = self only
    // 1 = friends
    // 2 = friends of friends
    // 3 = friends of friends of friends
    constexpr int maxLevel = 3;
    constexpr int node = 0;
    std::vector<int> distances = graph.bfsGPU(node, maxLevel);

    unsigned i = 0;
    unsigned numberOfNeighbors = 0;
    for (auto distance : distances) {
        if (distance <= maxLevel) {
            numberOfNeighbors++;
        }
        ++i;
    }

    printf("Node %d has %d neighbors (max level: %d)\n", node + 1, numberOfNeighbors, maxLevel);

    return 0;
}

