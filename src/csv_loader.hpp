#ifndef CSV_LOADER
#define CSV_LOADER

#include <string>
#include <vector>
#include <array>

class CSVLoader {
public:
    static std::vector<std::array<int, 2>> readCSV(std::string filePath, size_t expectedNumberOfRows = -1);
};

#endif
