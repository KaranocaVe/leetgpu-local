#!/usr/bin/env bash
set -euo pipefail

uv sync
cmake --preset container-no-gpu

cat <<'EOF'

LeetGPU no-GPU development environment is ready.

- CUDA compilation: available through nvcc
- GPU runtime tests: unavailable unless the container is explicitly given a GPU
- CMake preset: container-no-gpu
- Example compile-only target:
    cmake --build "$HOME/.cache/leetgpu-local/build-no-gpu" --target lgpu_easy_1_vector_add

EOF
