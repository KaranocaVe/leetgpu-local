# leetgpu-local

[![CI](https://github.com/KaranocaVe/leetgpu-local/actions/workflows/ci.yml/badge.svg)](https://github.com/KaranocaVe/leetgpu-local/actions/workflows/ci.yml)

Local CUDA development harness for [LeetGPU](https://leetgpu.com/challenges), with CMake, clangd-friendly compilation databases, and local correctness tests.

The upstream challenge definitions are **not vendored**. CMake fetches `AlphaGPU/leetgpu-challenges` and copies each CUDA starter into `solutions/` only when that solution does not already exist. Your edits are never overwritten.

## Requirements

- CMake >= 3.24
- Ninja (recommended)
- CUDA Toolkit / `nvcc`
- Python 3
- PyTorch with CUDA support (only needed for local correctness tests)
- clangd (optional, for completion/navigation)

## First configure

Plain CMake:

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
ln -sf build/compile_commands.json compile_commands.json
```

Or use the included preset:

```bash
cmake --preset default
ln -sf build/compile_commands.json compile_commands.json
```

On first configure, every upstream `starter.cu` is copied to:

```text
solutions/<difficulty>/<number_name>/solution.cu
```

For example:

```text
solutions/easy/1_vector_add/solution.cu
```

CMake will not overwrite an existing `solution.cu`, so your work is safe when the upstream challenge repository updates.

## Build and test one challenge

Target names are derived from difficulty + upstream folder name.

```bash
cmake --build build --target lgpu_easy_1_vector_add
cmake --build build --target check_easy_1_vector_add
```

The `check_*` target builds the CUDA shared library and runs the official functional tests from that challenge's `challenge.py` against your `solve` function.

List all targets:

```bash
cmake --build build --target leetgpu-list
```

## Build everything

```bash
cmake --build build --target leetgpu-all -j
```

This is intentionally not the default build because some advanced challenges may need architecture/toolkit features unavailable on your current GPU/toolchain.

## CTest

After building a challenge library, you can also run its registered test:

```bash
ctest --test-dir build -R easy_1_vector_add --output-on-failure
```

CTest does not build missing targets automatically, so `check_*` is the most convenient day-to-day command.

## clangd

CMake emits `build/compile_commands.json`. Most clangd clients discover `build/` automatically; if yours does not, create the symlink shown above.

The included `.clangd` strips several nvcc-only options and tells clangd to parse CUDA as C++20. If CUDA is not installed at `/usr/local/cuda`, change the `--cuda-path=` entry.

## Use an existing upstream checkout

To avoid CMake fetching GitHub itself:

```bash
cmake --preset default \
  -DLEETGPU_UPSTREAM_DIR=/path/to/leetgpu-challenges
```

You can pin an upstream revision instead of tracking `main`:

```bash
cmake --preset default -DLEETGPU_UPSTREAM_TAG=<commit-or-tag>
```

## Typical workflow

```bash
cmake --preset default
ln -sf build/compile_commands.json compile_commands.json

nvim solutions/easy/1_vector_add/solution.cu
cmake --build build --target check_easy_1_vector_add
```

When the local functional tests pass, paste `solution.cu` into LeetGPU for the official judge/benchmark.

## Upstream licensing

Challenge statements, starter code, tests, and reference implementations belong to the upstream LeetGPU challenge repository and remain subject to its license. This repository intentionally fetches them from upstream instead of redistributing them.

## Continuous integration

`.github/workflows/ci.yml` validates the harness on every push and pull request.

The hosted job runs inside an NVIDIA CUDA development container, pins the upstream challenge set to a known commit for reproducibility, configures with `sm_75` instead of `native` (GitHub-hosted runners do not have a physical GPU), verifies that every upstream CUDA starter produced a local solution and a `compile_commands.json` entry, then compiles all generated CUDA starter libraries.

At the pinned upstream revision, the repository contains 101 CUDA challenges: 19 Easy, 66 Medium, and 16 Hard. The CI validator derives these numbers from the upstream tree rather than hard-coding them.

A second `gpu-smoke` job is available through **Actions → CI → Run workflow → run_gpu_smoke**. It targets a self-hosted runner labeled `gpu` and replaces the Vector Add starter with a known-good fixture before running the official LeetGPU functional cases through the local `ctypes`/PyTorch harness. This job is optional because GitHub's ordinary hosted runner has no CUDA device.
