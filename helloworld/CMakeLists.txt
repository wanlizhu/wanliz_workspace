cmake_minimum_required(VERSION 3.10)
project(helloworld)

set(CMAKE_CXX_STANDARD 17)

find_package(glfw3 REQUIRED)
find_package(OpenGL REQUIRED)

add_executable(helloworld 
    src/main.cpp 
    src/shader.cpp 
    src/glad.c)

target_include_directories(helloworld PRIVATE 
    ${CMAKE_CURRENT_LIST_DIR}
    ${CMAKE_CURRENT_LIST_DIR}/src
    /usr/local/include)

target_link_directories(helloworld PRIVATE /usr/local/lib)
target_link_libraries(helloworld glfw OpenGL::GL)
