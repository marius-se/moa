FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.4.0
)

FetchContent_MakeAvailable(Catch2)

find_package(HIP REQUIRED)

add_executable(tests test_csv_loader.cpp test_graph.cpp test_hello_world.cpp)
target_include_directories(tests PRIVATE ../src)

target_link_libraries(tests PRIVATE moa Catch2::Catch2WithMain hip)

