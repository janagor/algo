include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(algo_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(algo_setup_options)
  option(algo_ENABLE_HARDENING "Enable hardening" ON)
  option(algo_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    algo_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    algo_ENABLE_HARDENING
    OFF)

  algo_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR algo_PACKAGING_MAINTAINER_MODE)
    option(algo_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(algo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(algo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(algo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(algo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(algo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(algo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(algo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(algo_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(algo_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(algo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(algo_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(algo_ENABLE_IPO "Enable IPO/LTO" ON)
    option(algo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(algo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(algo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(algo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(algo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(algo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(algo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(algo_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(algo_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(algo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(algo_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      algo_ENABLE_IPO
      algo_WARNINGS_AS_ERRORS
      algo_ENABLE_SANITIZER_ADDRESS
      algo_ENABLE_SANITIZER_LEAK
      algo_ENABLE_SANITIZER_UNDEFINED
      algo_ENABLE_SANITIZER_THREAD
      algo_ENABLE_SANITIZER_MEMORY
      algo_ENABLE_UNITY_BUILD
      algo_ENABLE_CLANG_TIDY
      algo_ENABLE_CPPCHECK
      algo_ENABLE_COVERAGE
      algo_ENABLE_PCH
      algo_ENABLE_CACHE)
  endif()

  algo_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (algo_ENABLE_SANITIZER_ADDRESS OR algo_ENABLE_SANITIZER_THREAD OR algo_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(algo_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(algo_global_options)
  if(algo_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    algo_enable_ipo()
  endif()

  algo_supports_sanitizers()

  if(algo_ENABLE_HARDENING AND algo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR algo_ENABLE_SANITIZER_UNDEFINED
       OR algo_ENABLE_SANITIZER_ADDRESS
       OR algo_ENABLE_SANITIZER_THREAD
       OR algo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${algo_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${algo_ENABLE_SANITIZER_UNDEFINED}")
    algo_enable_hardening(algo_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(algo_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(algo_warnings INTERFACE)
  add_library(algo_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  algo_set_project_warnings(
    algo_warnings
    ${algo_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    algo_enable_sanitizers(
      algo_options
      ${algo_ENABLE_SANITIZER_ADDRESS}
      ${algo_ENABLE_SANITIZER_LEAK}
      ${algo_ENABLE_SANITIZER_UNDEFINED}
      ${algo_ENABLE_SANITIZER_THREAD}
      ${algo_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(algo_options PROPERTIES UNITY_BUILD ${algo_ENABLE_UNITY_BUILD})

  if(algo_ENABLE_PCH)
    target_precompile_headers(
      algo_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(algo_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    algo_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(algo_ENABLE_CLANG_TIDY)
    algo_enable_clang_tidy(algo_options ${algo_WARNINGS_AS_ERRORS})
  endif()

  if(algo_ENABLE_CPPCHECK)
    algo_enable_cppcheck(${algo_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(algo_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    algo_enable_coverage(algo_options)
  endif()

  if(algo_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(algo_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(algo_ENABLE_HARDENING AND NOT algo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR algo_ENABLE_SANITIZER_UNDEFINED
       OR algo_ENABLE_SANITIZER_ADDRESS
       OR algo_ENABLE_SANITIZER_THREAD
       OR algo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    algo_enable_hardening(algo_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
