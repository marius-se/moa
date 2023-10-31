#ifndef CSV_LOADER
#define CSV_LOADER

#include <string>
#include <vector>

class CSVLoader {
public:
    static std::vector<std::vector<std::string>> readCSV(std::string filePath);
};

#endif
