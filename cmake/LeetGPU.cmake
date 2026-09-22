include_guard(GLOBAL)

function(_leetgpu_slugify INPUT OUTPUT)
  string(TOLOWER "${INPUT}" _s)
  string(REGEX REPLACE "[^a-z0-9_]+" "_" _s "${_s}")
  string(REGEX REPLACE "_+" "_" _s "${_s}")
  set(${OUTPUT} "${_s}" PARENT_SCOPE)
endfunction()

function(_leetgpu_ensure_upstream OUT_DIR)
  if(LEETGPU_UPSTREAM_DIR)
    if(NOT EXISTS "${LEETGPU_UPSTREAM_DIR}/challenges")
      message(FATAL_ERROR "LEETGPU_UPSTREAM_DIR does not look like AlphaGPU/leetgpu-challenges: ${LEETGPU_UPSTREAM_DIR}")
    endif()
    get_filename_component(_upstream "${LEETGPU_UPSTREAM_DIR}" ABSOLUTE)
  else()
    if(LEETGPU_UPSTREAM_TAG MATCHES "^[0-9a-fA-F]{40}$")
      set(_leetgpu_git_shallow FALSE)
    else()
      set(_leetgpu_git_shallow TRUE)
    endif()

    # Keep the fetched repository outside CMake's build directory so CLion's
    # multiple profiles (Debug/Release/etc.) share one checkout.
    file(MAKE_DIRECTORY "${LEETGPU_FETCHCONTENT_BASE_DIR}")
    file(
      LOCK "${LEETGPU_FETCHCONTENT_BASE_DIR}/.populate.lock"
      GUARD FUNCTION
      TIMEOUT 300
      RESULT_VARIABLE _leetgpu_lock_result
    )
    if(NOT _leetgpu_lock_result EQUAL 0)
      message(FATAL_ERROR "Could not lock LeetGPU upstream cache: ${_leetgpu_lock_result}")
    endif()

    set(FETCHCONTENT_BASE_DIR "${LEETGPU_FETCHCONTENT_BASE_DIR}")

    # Once the checkout exists, point FetchContent directly at it. This skips
    # download/update logic entirely on normal CMake reloads.
    set(_cached_source "${LEETGPU_FETCHCONTENT_BASE_DIR}/leetgpu_challenges-src")
    if(EXISTS "${_cached_source}/challenges")
      set(FETCHCONTENT_SOURCE_DIR_LEETGPU_CHALLENGES "${_cached_source}")
    endif()

    FetchContent_Declare(
      leetgpu_challenges
      GIT_REPOSITORY https://github.com/AlphaGPU/leetgpu-challenges.git
      GIT_TAG        ${LEETGPU_UPSTREAM_TAG}
      GIT_SHALLOW    ${_leetgpu_git_shallow}
      GIT_PROGRESS   TRUE
      # We only consume files from the challenge repository. Even if upstream
      # grows a CMakeLists.txt later, don't add it to this build.
      SOURCE_SUBDIR  __leetgpu_local_no_subdirectory__
    )
    FetchContent_MakeAvailable(leetgpu_challenges)
    set(_upstream "${leetgpu_challenges_SOURCE_DIR}")
  endif()

  set(${OUT_DIR} "${_upstream}" PARENT_SCOPE)
endfunction()

function(_leetgpu_register_one UPSTREAM_ROOT STARTER_FILE)
  file(RELATIVE_PATH _rel "${UPSTREAM_ROOT}/challenges" "${STARTER_FILE}")
  string(REPLACE "/" ";" _parts "${_rel}")
  list(LENGTH _parts _nparts)
  if(_nparts LESS 4)
    return()
  endif()
  list(GET _parts 0 _difficulty)
  list(GET _parts 1 _challenge)

  _leetgpu_slugify("${_difficulty}_${_challenge}" _slug)
  set(_solution_dir "${PROJECT_SOURCE_DIR}/solutions/${_difficulty}/${_challenge}")
  set(_solution "${_solution_dir}/solution.cu")
  set(_challenge_dir "${UPSTREAM_ROOT}/challenges/${_difficulty}/${_challenge}")

  file(MAKE_DIRECTORY "${_solution_dir}")
  if(NOT EXISTS "${_solution}")
    file(COPY_FILE "${STARTER_FILE}" "${_solution}" ONLY_IF_DIFFERENT)
    message(STATUS "LeetGPU: created ${_solution}")
  endif()

  set(_target "lgpu_${_slug}")
  if(LEETGPU_BUILD_ALL)
    add_library(${_target} SHARED "${_solution}")
  else()
    add_library(${_target} SHARED EXCLUDE_FROM_ALL "${_solution}")
  endif()

  set_target_properties(${_target} PROPERTIES
    PREFIX ""
    OUTPUT_NAME "${_slug}"
    CUDA_ARCHITECTURES "${LEETGPU_CUDA_ARCHITECTURES}"
    CUDA_SEPARABLE_COMPILATION OFF
  )
  target_compile_features(${_target} PRIVATE cxx_std_20 cuda_std_20)
  target_compile_options(${_target} PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>
  )

  set(_check_target "check_${_slug}")
  add_custom_target(${_check_target}
    COMMAND "${UV_EXECUTABLE}" run --locked --extra gpu python
            "${PROJECT_SOURCE_DIR}/tools/run_challenge.py"
            --challenge-dir "${_challenge_dir}"
            --library "$<TARGET_FILE:${_target}>"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    DEPENDS ${_target}
    USES_TERMINAL
    COMMAND_EXPAND_LISTS
    VERBATIM
  )

  if(LEETGPU_ENABLE_TESTS AND BUILD_TESTING)
    add_test(NAME ${_slug}
      COMMAND "${UV_EXECUTABLE}" run --locked --extra gpu python
              "${PROJECT_SOURCE_DIR}/tools/run_challenge.py"
              --challenge-dir "${_challenge_dir}"
              --library "$<TARGET_FILE:${_target}>"
    )
    set_tests_properties(${_slug} PROPERTIES
      LABELS "${_difficulty};leetgpu"
      WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    )
  endif()

  set_property(GLOBAL APPEND PROPERTY LEETGPU_TARGETS ${_target})
  set_property(GLOBAL APPEND PROPERTY LEETGPU_CHECK_TARGETS ${_check_target})
endfunction()

function(_leetgpu_add_update_target UPSTREAM_ROOT)
  if(LEETGPU_UPSTREAM_DIR)
    add_custom_target(leetgpu-update
      COMMAND "${CMAKE_COMMAND}" -E echo
              "LEETGPU_UPSTREAM_DIR is user-managed; update it manually: ${LEETGPU_UPSTREAM_DIR}"
      USES_TERMINAL
    )
    return()
  endif()

  find_package(Git QUIET)
  if(NOT Git_FOUND OR NOT EXISTS "${UPSTREAM_ROOT}/.git")
    return()
  endif()

  add_custom_target(leetgpu-update
    COMMAND "${GIT_EXECUTABLE}" -C "${UPSTREAM_ROOT}" fetch --depth=1 origin "${LEETGPU_UPSTREAM_TAG}"
    COMMAND "${GIT_EXECUTABLE}" -C "${UPSTREAM_ROOT}" checkout --detach FETCH_HEAD
    COMMAND "${CMAKE_COMMAND}" -E echo
            "LeetGPU upstream updated. Reload CMake once to discover any newly added challenges."
    USES_TERMINAL
    VERBATIM
  )
endfunction()

function(leetgpu_configure)
  _leetgpu_ensure_upstream(_upstream)
  set(LEETGPU_UPSTREAM_RESOLVED "${_upstream}" CACHE INTERNAL "Resolved upstream checkout")

  file(GLOB_RECURSE _starters CONFIGURE_DEPENDS
    "${_upstream}/challenges/easy/*/starter/starter.cu"
    "${_upstream}/challenges/medium/*/starter/starter.cu"
    "${_upstream}/challenges/hard/*/starter/starter.cu"
  )
  list(SORT _starters)
  list(LENGTH _starters _count)
  if(_count EQUAL 0)
    message(FATAL_ERROR "No CUDA starters found under ${_upstream}/challenges")
  endif()

  foreach(_starter IN LISTS _starters)
    _leetgpu_register_one("${_upstream}" "${_starter}")
  endforeach()

  get_property(_targets GLOBAL PROPERTY LEETGPU_TARGETS)
  if(_targets)
    add_custom_target(leetgpu-all DEPENDS ${_targets})
  endif()

  add_custom_target(leetgpu-list
    COMMAND "${UV_EXECUTABLE}" run --locked python
            "${PROJECT_SOURCE_DIR}/tools/list_challenges.py"
            --upstream "${_upstream}"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    USES_TERMINAL
    VERBATIM
  )

  _leetgpu_add_update_target("${_upstream}")

  message(STATUS "LeetGPU: registered ${_count} CUDA challenge(s)")
  message(STATUS "LeetGPU: upstream cache: ${_upstream}")
  message(STATUS "LeetGPU: Python runtime managed by uv (${UV_EXECUTABLE})")
  message(STATUS "LeetGPU: edit solutions/<difficulty>/<challenge>/solution.cu")
  message(STATUS "LeetGPU: run a challenge with: cmake --build build --target check_<difficulty>_<challenge>")
endfunction()
