cmake_minimum_required(VERSION 3.15)
project(meckchat LANGUAGES CXX)

set(BINARY_NAME "meckchat")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)

set(PUBLIC_HEADER_VISIBILITY PUBLIC "$<BUILD_INTERFACE:;>$<INSTALL_INTERFACE:include>")

set(CMAKE_CXX_STANDARD 20)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE "Release")
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  set(DEBUG_MODE "ON")
endif()

set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build")

set(FLUTTER_MANAGED_DIR "${PROJECT_SOURCE_DIR}/flutter")

set(FLUTTER_ROOT "${FLUTTER_MANAGED_DIR}/ephemeral")

set(FLUTTER_VERSION_MAJOR 0)
set(FLUTTER_VERSION_MINOR 1)
set(FLUTTER_VERSION_PATCH 0)
set(FLUTTER_VERSION "${FLUTTER_VERSION_MAJOR}.${FLUTTER_VERSION_MINOR}.${FLUTTER_VERSION_PATCH}")
set(FLUTTER_VERSION_RC "${FLUTTER_VERSION}-rc.0")

include("${FLUTTER_ROOT}/packages/flutter_tools/cmake/flutter.cmake")

add_subdirectory(plugins)

add_executable(${BINARY_NAME} WIN32
  "runner.cpp"
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
)

apply_flutter_cmake_patches(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE
  "_CRT_SECURE_NO_WARNINGS"
)

target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${BINARY_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
)

add_dependencies(${BINARY_NAME} flutter_assemble)
