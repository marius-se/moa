#include "csv_loader.h"

#include <array>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace std;

vector<array<int, 2>> CSVLoader::readCSV(string filePath) {
  ifstream input{filePath};

  if (!input.is_open()) {
    cerr << "Couldn't read file: " << filePath << endl;
    vector<vector<int>>();
  }

  vector<array<int, 2>> csvRows;

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

  printf("Finished parsing CSV\n");

  return csvRows;
}
