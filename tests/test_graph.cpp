#include <catch2/catch_test_macros.hpp>
#include <cstdio>
#include <graph.hpp>

TEST_CASE("Construct Graph from CSV file") {
    constexpr int expectedNumberOfEdges = 12;
    constexpr int expectedEdgesArraySize = 19; // 12 edges + 7 seperators;
    constexpr int expectedNumberOfVertices = 7;
    int expectedVertices[] = { 0, 4, 7, 9, 13, 18, 16 };
    int expectedEdges[] = { 1, 2, 3, -1, 3, 4, -1, 5, -1, 2, 5, 6, -1, 3, 6, -1, 5, -1, -1 };

    Graph graph("./tests/test_csv.csv", false, expectedNumberOfVertices, expectedNumberOfEdges);

    REQUIRE(expectedEdgesArraySize == expectedNumberOfEdges + expectedNumberOfVertices);

    REQUIRE(graph.numberOfEdges == expectedNumberOfEdges);
    REQUIRE(graph.numberOfVertices == expectedNumberOfVertices);

    for (int i = 0; i < expectedNumberOfVertices; ++i) {
        REQUIRE(graph.vertices[i] == expectedVertices[i]);
    }

    for (int i = 0; i < expectedEdgesArraySize; ++i) {
        REQUIRE(graph.edges[i] == expectedEdges[i]);
    }
}
