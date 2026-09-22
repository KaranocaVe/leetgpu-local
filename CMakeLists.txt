cmake_minimum_required(VERSION 3.24)

project(leetgpu_local LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 20)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(LEETGPU_BUILD_ALL "Build every CUDA challenge as part of the default build" OFF)
option(LEETGPU_ENABLE_TESTS "Register local correctness tests with CTest" ON)
set(LEETGPU_CUDA_ARCHITECTURES "native" CACHE STRING "CUDA architectures used for local challenge builds")
set(LEETGPU_UPSTREAM_TAG "main" CACHE STRING "AlphaGPU/leetgpu-challenges git tag/branch/commit")
set(LEETGPU_UPSTREAM_DIR "" CACHE PATH "Use an existing leetgpu-challenges checkout instead of fetching it")
set(
  LEETGPU_FETCHCONTENT_BASE_DIR
  "${PROJECT_SOURCE_DIR}/.cache/fetchcontent"
  CACHE PATH
  "Persistent FetchContent cache shared by all CMake build directories"
)

find_program(UV_EXECUTABLE uv REQUIRED)
include(CTest)
include(FetchContent)
include(cmake/LeetGPU.cmake)

leetgpu_configure()
