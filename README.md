# Moa

## Compiling

```
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/rocm
cmake --build build --target tests
```
