#ifndef HIP_MACROS
#define HIP_MACROS

#define HIP_CHECK(call)                                                                                                \
    do {                                                                                                               \
        hipError_t gpuErr = call;                                                                                      \
        if (hipSuccess != gpuErr) {                                                                                    \
            printf("GPU Error - %s:%d: '%s'\n", __FILE__, __LINE__, hipGetErrorString(gpuErr));                        \
            exit(1);                                                                                                   \
        }                                                                                                              \
    } while (0)

#endif
