cmake_minimum_required(VERSION 3.6)
project(my_project VERSION 0.0.1 LANGUAGES HIP C CXX)

include(FetchContent)
include(CTest)

set(CMAKE_EXPORT_COMPILE_COMMANDS 1)

add_subdirectory(src)
add_subdirectory(tests)

