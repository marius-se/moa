#include <catch2/catch_test_macros.hpp>
#include <graph.hpp>
#include <vector>

TEST_CASE("Construct Graph from CSV file") {
    constexpr int expectedNumberOfEdges = 13;
    constexpr int expectedEdgesArraySize = 20; // 12 edges + 7 seperators;
    constexpr int expectedNumberOfVertices = 7;
    const std::vector<int> expectedVertices = {0, 4, 7, 9, 13, 16, 18};
    const std::vector<int> expectedEdges = {1, 2, 3, -1, 3, 4, -1, 5, -1, 2, 5, 6, -1, 3, 6, -1, 1, -1, 5, -1};

    Graph graph("./tests/test_csv.csv", false, expectedNumberOfVertices, expectedNumberOfEdges);

    REQUIRE(expectedEdgesArraySize == expectedNumberOfEdges + expectedNumberOfVertices);


    REQUIRE(graph.vertices == expectedVertices);
    REQUIRE(graph.edges == expectedEdges);
}

TEST_CASE("Calculate BFS using GPU") {
    Graph graph("./tests/test_csv.csv", false, 7, 13);

    std::vector<int> expectedCosts{0, 1, 1, 1, 2, 2, 2};
    std::vector<int> distance = graph.bfsGPU(0);
    REQUIRE(expectedCosts == distance);
}

TEST_CASE("Calculate BFS using CPU") {
    Graph graph("./tests/test_csv.csv", false, 7, 13);

    std::vector<int> expectedCosts{0, 1, 1, 1, 2, 2, 2};
    std::vector<int> costs = graph.bfsCPU(0);
    REQUIRE(expectedCosts == costs);
}

TEST_CASE("Benchmark on poc dataset") {
    printf("Benchmarking pokec\n");
    Graph graph("/home/marius/Downloads/soc-pokec-relationships.csv", false, 1632803, 30622564);

    std::vector<int> distanceGPU = graph.bfsGPU(5);
    std::vector<int> distanceCPU = graph.bfsCPU(5);

    REQUIRE(distanceCPU == distanceGPU);
}

TEST_CASE("Benchmark on ogb dataset") {
    printf("Benchmarking OGB Papers100M\n");
    Graph graph("/home/marius/Developer/edges.csv", true, 111059956, 1615685872);

    std::vector<int> distanceCPU = graph.bfsCPU(5);
    std::vector<int> distanceGPU = graph.bfsGPU(5);

    REQUIRE(distanceCPU == distanceGPU);
}


