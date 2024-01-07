#include <catch2/catch_test_macros.hpp>
#include <hello_world.hpp>

TEST_CASE("Check if GPU is working at all") {
    HelloWorld helloWorld;
    int result = helloWorld.helloWorld();
    REQUIRE(result == 1);
}

