mkdir -p nvidiahook/build
cd nvidiahook/build
cmake ..
cmake --build . || exit -1

LD_PRELOAD=$HOME/wanliz_workspace/nvidiahook/build/libnvidiahook.so \
LD_LIBRARY_PATH=$HOME/wanliz_workspace/nvidiahook/build \
"$@"
