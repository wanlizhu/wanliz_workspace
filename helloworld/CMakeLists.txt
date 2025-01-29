cmake_minimum_required(VERSION 3.10)
project(helloworld)

set(CMAKE_CXX_STANDARD 17)

find_package(glfw3 REQUIRED)
find_package(OpenGL REQUIRED)

add_executable(helloworld src/main.cpp src/shader.cpp)

target_include_directories(helloworld PRIVATE /usr/local/include)
target_link_directories(helloworld PRIVATE /usr/local/lib)

target_link_libraries(helloworld glfw OpenGL::GL)
