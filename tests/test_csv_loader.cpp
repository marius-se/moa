#include <vector>
#define CATCH_CONFIG_MAIN

#include <catch2/catch_test_macros.hpp>
#include <csv_loader.hpp>

using namespace std;

// https://faculty.cs.niu.edu/~freedman/340/340notes/gifImages/340graph2.gif

TEST_CASE("CSV is loaded") {
    vector<array<int, 2>> expectedCSV = {
        { 1, 2 },
        { 1, 3 },
        { 1, 4 },
        { 2, 4 },
        { 2, 5 },
        { 3, 6 },
        { 4, 3 },
        { 4, 6 },
        { 4, 7 },
        { 5, 4 },
        { 5, 7 },
        { 7, 6 }
    };
    REQUIRE(CSVLoader::readCSV("./tests/test_csv.csv") == expectedCSV);
}
