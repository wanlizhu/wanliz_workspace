#pragma once

#include <glad/glad.h>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>

class Shader {
public:
    unsigned int ID;
    
public:
    Shader(const char* vertexPath, const char* fragmentPath);
    void use();
};
