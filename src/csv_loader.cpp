#include "csv_loader.hpp"

#include <array>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace std;

vector<array<int, 2>> CSVLoader::readCSV(string filePath, size_t expectedNumberOfRows) {
    ifstream input{filePath};

    if (!input.is_open()) {
        cerr << "Couldn't read file: " << filePath << endl;
        vector<vector<int>>();
    }

    vector<array<int, 2>> csvRows;
    if (expectedNumberOfRows != -1) {
        csvRows.reserve(expectedNumberOfRows);
    }

    for (string line; getline(input, line);) {
        stringstream ss(std::move(line));
        array<int, 2> row;

        string value;
        getline(ss, value, ',');
        row[0] = stoi(value);

        getline(ss, value, ',');
        row[1] = stoi(value);

        csvRows.push_back(std::move(row));
    }

    printf("Finished parsing CSV with %zu rows.\n", csvRows.size());

    return csvRows;
}
