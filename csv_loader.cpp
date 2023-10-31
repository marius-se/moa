#include "csv_loader.h"

#include <fstream>
#include <sstream>
#include <iostream>
#include <string>
#include <iomanip>
#include <vector>

using namespace std;

vector<vector<string>> CSVLoader::readCSV(string filePath) {
    ifstream input{filePath};

    if (!input.is_open()) {
        cerr << "Couldn't read file: " << filePath << endl;
        vector<vector<string>>();
    }

    vector<vector<string>> csvRows;

    for (string line; getline(input, line);) {
        stringstream ss(std::move(line));
        vector<string> row;

        if (!csvRows.empty()) {
            row.reserve(csvRows.front().size());
        }

        for (string value; getline(ss, value, ',');) {
            row.push_back(std::move(value));
        }

        csvRows.push_back(std::move(row));
    }

    return csvRows;
}
