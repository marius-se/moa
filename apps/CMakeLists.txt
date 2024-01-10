find_package(HIP REQUIRED)

add_executable(moaRun main.cpp)
target_include_directories(moaRun PRIVATE ../src)

target_link_libraries(moaRun PRIVATE moa hip)

