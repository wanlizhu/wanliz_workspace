cmake_minimum_required(VERSION 3.10)
project(nvidiahooks)

set(CMAKE_CXX_STANDARD          17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN 1)
set(CMAKE_BUILD_TYPE Release) 

find_package(OpenGL REQUIRED)
add_library(nvidiahooks SHARED main.cpp)

set_target_properties(nvidiahooks      PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(nvidiahooks PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${OPENGL_INCLUDE_DIRS})
target_link_libraries(nvidiahooks      PRIVATE ${CMAKE_DL_LIBS} ${OPENGL_LIBRARIES})

