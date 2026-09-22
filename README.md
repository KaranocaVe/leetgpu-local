# leetgpu-local

[![CI](https://github.com/KaranocaVe/leetgpu-local/actions/workflows/ci.yml/badge.svg)](https://github.com/KaranocaVe/leetgpu-local/actions/workflows/ci.yml)

Local CUDA development harness for [LeetGPU](https://leetgpu.com/challenges), with CMake, clangd-friendly compilation databases, and local correctness tests.

The upstream challenge definitions are **not vendored**. On the first configure, CMake fetches `AlphaGPU/leetgpu-challenges` into a persistent user cache and copies each CUDA starter into `solutions/` only when that solution does not already exist. Your edits are never overwritten.

The upstream checkout is shared by every CMake build directory/profile and lives outside the project tree so CLion does not index it. Defaults are `~/.cache/leetgpu-local/fetchcontent` on Linux, `~/Library/Caches/leetgpu-local/fetchcontent` on macOS, and `%LOCALAPPDATA%/leetgpu-local/fetchcontent` on Windows. Normal CMake reloads are fully local: once the cache exists, FetchContent is pointed directly at that checkout, so CLion opening/reloading the project does not perform a Git fetch or update.

## Requirements

- CMake >= 3.24
- Ninja (recommended)
- CUDA Toolkit / `nvcc`
- [uv](https://docs.astral.sh/uv/) >= 0.12.15, < 0.13
- clangd (optional, for completion/navigation)

Python itself and Python dependencies are managed by uv. The repository pins Python 3.13 in `.python-version`, commits `uv.lock` for reproducible environments, and requires uv 0.12.x because uv only guarantees lockfile compatibility within a minor release. PyTorch is an optional `gpu` extra: Linux resolves the CUDA 13.0 build, while non-Linux platforms resolve the CPU build.

## Python environment

Check uv first:

```bash
uv --version
```

If it is older than 0.12.15, upgrade it. Standalone-installer builds can use `uv self update`; otherwise upgrade uv with the package manager that installed it.

Create/sync the lightweight base environment:

```bash
uv sync --locked
```

The base environment has no heavy runtime dependencies. Local correctness tests need PyTorch and will automatically request the `gpu` extra through CMake; you can also install it explicitly:

```bash
uv sync --locked --extra gpu
```

Dependency changes should go through uv, for example `uv add --optional gpu <package>`, followed by committing both `pyproject.toml` and `uv.lock`.

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

The `check_*` target builds the CUDA shared library and runs the official functional tests from that challenge's `challenge.py` against your `solve` function. Python is invoked as `uv run --locked --extra gpu python ...`, so the test environment always matches the committed lockfile.

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

The cached checkout is deliberately **not** updated during normal configure/reload. To refresh it explicitly:

```bash
cmake --build build --target leetgpu-update
cmake --fresh --preset default
```

If you use CLion, run the `leetgpu-update` target only when you actually want newer upstream challenges, then use **Reload CMake Project** once. This keeps ordinary IDE startup independent of GitHub/network latency.

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

`.github/workflows/ci.yml` validates the harness on every push and pull request. It also verifies that `uv.lock` matches `pyproject.toml` and runs Python helper checks through uv.

The hosted job runs inside an NVIDIA CUDA development container, pins the upstream challenge set to a known commit for reproducibility, configures with `sm_75` instead of `native` (GitHub-hosted runners do not have a physical GPU), verifies that every upstream CUDA starter produced a local solution and a `compile_commands.json` entry, verifies that a second configure succeeds with the cached upstream repository's remote deliberately made unreachable, then compiles all generated CUDA starter libraries.

At the pinned upstream revision, the upstream repository has 101 challenge directories, but 100 CUDA starters: 18 Easy, 66 Medium, and 16 Hard. `easy/41_simple_inference` currently has no `starter.cu`, so it is intentionally not registered as a CUDA target. The CI validator derives the CUDA count from the upstream tree rather than hard-coding it.

A second `gpu-smoke` job is available through **Actions → CI → Run workflow → run_gpu_smoke**. It targets a self-hosted runner labeled `gpu` and replaces the Vector Add starter with a known-good fixture before running the official LeetGPU functional cases through the local `ctypes`/PyTorch harness. This job is optional because GitHub's ordinary hosted runner has no CUDA device.
