cmake_minimum_required(VERSION 3.10)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake OPTIONAL)

# Serves the same purpose as list(TRANSFORM ... PREPEND ...),
# which isn't available in CMake 3.10.
function(list_prepend LIST_NAME PREFIX)
  set(NEW_LIST "")
  foreach(ITEM ${${LIST_NAME}})
    list(APPEND NEW_LIST "${PREFIX}${ITEM}")
  endforeach()
  set(${LIST_NAME} "${NEW_LIST}" PARENT_SCOPE)
endfunction()

# The CMake project for the client.
project(flutter LANGUAGES CXX)

# === Flutter Library ===
set(FLUTTER_LIB_NAME "flutter_linux_gtk")

# Wraps the flutter library into an imported target.
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter INTERFACE
  ${FLUTTER_LIB_NAME}
)
target_link_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)

# === Flutter Assemble ===
# Target that builds the assets and compiles the Dart code.
add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  ${FLUTTER_ASSETS}
)

add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_LIB_NAME}
         ${FLUTTER_ASSETS}
         ${CMAKE_CURRENT_BINARY_DIR}/_phony_
  COMMAND ${CMAKE_COMMAND} -E env
          ${FLUTTER_TOOL_ENVIRONMENT}
          "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.sh"
          ${FLUTTER_TARGET_PLATFORM} ${CMAKE_BUILD_TYPE}
  VERBATIM
)
