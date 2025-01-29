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
cmake ..
make && ./helloworld 
