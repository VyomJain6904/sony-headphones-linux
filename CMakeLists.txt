cmake_minimum_required(VERSION 3.24)
project(sony-headphones-linux VERSION 0.2.3 LANGUAGES CXX)

option(SONY_WITH_LIBMDR "Build the BlueZ/libmdr hardware backend" OFF)
set(SONY_LIBMDR_SOURCE_DIR "" CACHE PATH "Path to the pinned SonyHeadphonesClient source")
set(SONY_LIBMDR_BUILD_DIR "" CACHE PATH "Path to its configured build directory")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")

include(CTest)
add_subdirectory(native)
