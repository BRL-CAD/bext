cmake_minimum_required(VERSION 3.26)
project(QtRuntimeProbe LANGUAGES CXX)
find_package(Qt6 REQUIRED COMPONENTS Core)
add_executable(qt_runtime_probe runtime.cpp)
set_target_properties(qt_runtime_probe PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(qt_runtime_probe PRIVATE Qt6::Core)
enable_testing()
add_test(NAME qt_runtime_probe COMMAND "${CMAKE_COMMAND}" -E env
  BEXT_QT_RUNTIME_TEST=present $<TARGET_FILE:qt_runtime_probe>)
