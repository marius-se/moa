#include "hello_world.hpp"
#include "hip_macros.hpp"
#include <hip/hip_runtime.h>
#include <hip/hip_runtime_api.h>
#include <iostream>

using namespace std;

__global__ void helloworld(char *in, char *out) {
    int num = hipThreadIdx_x + hipBlockDim_x * hipBlockIdx_x;
    out[num] = in[num] + 1;
}

int HelloWorld::helloWorld() {
    hipDeviceProp_t devProp;
    HIP_CHECK(hipGetDeviceProperties(&devProp, 0));
    cout << "-----" << endl;
    cout << " System Minor " << devProp.minor << endl;
    cout << " System Major " << devProp.major << endl;
    cout << " Device Name " << devProp.name << endl;
    cout << " Max Allocatable Memory: " << devProp.totalGlobalMem / (1024 * 1024 * 1024) << "GB" << endl;
    cout << "-----" << endl;

    /* Initial input,output for the host and create memory objects for the kernel*/
    const char *input = "GdkknVnqkc";
    size_t strlength = strlen(input);
    cout << "Super secret encoded string: " << input << endl;
    char *output = (char *)malloc(strlength + 1);

    char *inputBuffer;
    char *outputBuffer;
    HIP_CHECK(hipMalloc((void **)&inputBuffer, (strlength + 1) * sizeof(char)));
    HIP_CHECK(hipMalloc((void **)&outputBuffer, (strlength + 1) * sizeof(char)));

    HIP_CHECK(hipMemcpy(inputBuffer, input, (strlength + 1) * sizeof(char), hipMemcpyHostToDevice));

    hipLaunchKernelGGL(helloworld, dim3(1), dim3(strlength), 0, 0, inputBuffer, outputBuffer);

    HIP_CHECK(hipMemcpy(output, outputBuffer, (strlength + 1) * sizeof(char), hipMemcpyDeviceToHost));

    HIP_CHECK(hipFree(inputBuffer));
    HIP_CHECK(hipFree(outputBuffer));

    output[strlength] = '\0'; // Add the terminal character to the end of output.
    cout << "Decoded string: " << output << endl;

    free(output);

    return 1;
}

HelloWorld::~HelloWorld() {}

HelloWorld::HelloWorld() {}
