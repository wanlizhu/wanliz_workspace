packages=(
    build-essential
    cmake
    git
    xorg-dev
    libgl1-mesa-dev
    libglfw3-dev
)

for pkg in "${packages[@]}"; do
    if ! dpkg -l | grep -qw "$pkg"; then
        sudo apt install -y "${pkg}"
    fi
done

mkdir -p build && cd build

if ! -d glad; then
    git clone https://github.com/Dav1dde/glad.git && cd glad
    git checkout v2.0.8
    cd ..
fi 

cmake ..
make && ./helloworld 
