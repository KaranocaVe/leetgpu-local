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
if(WIN32 AND DEFINED ENV{LOCALAPPDATA})
  set(_leetgpu_default_cache "$ENV{LOCALAPPDATA}/leetgpu-local/fetchcontent")
elseif(APPLE AND DEFINED ENV{HOME})
  set(_leetgpu_default_cache "$ENV{HOME}/Library/Caches/leetgpu-local/fetchcontent")
elseif(DEFINED ENV{XDG_CACHE_HOME})
  set(_leetgpu_default_cache "$ENV{XDG_CACHE_HOME}/leetgpu-local/fetchcontent")
elseif(DEFINED ENV{HOME})
  set(_leetgpu_default_cache "$ENV{HOME}/.cache/leetgpu-local/fetchcontent")
else()
  set(_leetgpu_default_cache "${PROJECT_SOURCE_DIR}/.cache/fetchcontent")
endif()
set(
  LEETGPU_FETCHCONTENT_BASE_DIR
  "${_leetgpu_default_cache}"
  CACHE PATH
  "Persistent FetchContent cache shared by all CMake build directories"
)
unset(_leetgpu_default_cache)

find_program(UV_EXECUTABLE uv REQUIRED)
include(CTest)
include(FetchContent)
include(cmake/LeetGPU.cmake)

leetgpu_configure()
