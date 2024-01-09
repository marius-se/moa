#include <catch2/catch_test_macros.hpp>
#include <graph.hpp>
#include <vector>

TEST_CASE("Construct Graph from CSV file") {
    constexpr int expectedNumberOfEdges = 13;
    constexpr int expectedEdgesArraySize = 20; // 12 edges + 7 seperators;
    constexpr int expectedNumberOfVertices = 7;
    constexpr int expectedVertices[] = {0, 4, 7, 9, 13, 16, 18};
    constexpr int expectedEdges[] = {1, 2, 3, -1, 3, 4, -1, 5, -1, 2, 5, 6, -1, 3, 6, -1, 1, -1, 5, -1};

    Graph graph("./tests/test_csv.csv", false, expectedNumberOfVertices, expectedNumberOfEdges);

    REQUIRE(expectedEdgesArraySize == expectedNumberOfEdges + expectedNumberOfVertices);

    REQUIRE(graph.edges.size() == expectedEdgesArraySize);
    REQUIRE(graph.vertices.size() == expectedNumberOfVertices);

    for (int i = 0; i < expectedNumberOfVertices; ++i) {
        REQUIRE(graph.vertices[i] == expectedVertices[i]);
    }

    for (int i = 0; i < expectedEdgesArraySize; ++i) {
        REQUIRE(graph.edges[i] == expectedEdges[i]);
    }
}

TEST_CASE("Calculate BFS using new GPU function") {
    Graph graph("./tests/test_csv.csv", false, 7, 12);

    std::vector<int> expectedCosts{0, 1, 1, 1, 2, 2, 2};
    std::vector<int> distance = graph.bfsGPU(0);
    REQUIRE(expectedCosts == distance);
}

TEST_CASE("Calculate BFS using CPU") {
    Graph graph("./tests/test_csv.csv", false, 7, 12);

    std::vector<int> expectedCosts{0, 1, 1, 1, 2, 2, 2};
    std::vector<int> costs = graph.bfsCPU(0);
    REQUIRE(expectedCosts == costs);
}

