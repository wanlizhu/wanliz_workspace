#!/bin/bash
export P4CLIENT=wanliz-p4sw-bugfix_main
export P4ROOT=$HOME/$P4CLIENT
export P4IGNORE=$HOME/.p4ignore
export P4PORT=p4proxy-sc.nvidia.com:2006
export P4USER=wanliz

if [[ -z $1 ]]; then
    read -e -i "yes" -p "Make a full build? (yes/no): " fullbuild
    read -e -i "release" -p "Set build type: " buildtype
    read -e -i "$(nproc)" -p "Number of building threads: " threads
    if [[ $fullbuild == yes ]]; then
        args="drivers dist linux amd64 $buildtype -j$threads"
    else
        args="linux amd64 $buildtype -j$threads"
    fi
    echo "nvmake arguments: $args"
    read -p "Press [ENTER] to continue: " _
else
    args="$@"
fi

read -e -i "no" -p "Update build tools? (yes/no): " update
if [[ $update == yes ]]; then
    backup1=$P4CLIENT 
    backup2=$P4ROOT
    export P4CLIENT=wanliz-p4sw-common
    export P4ROOT=$HOME/$P4CLIENT
    p4 sync //sw/... 
    export P4CLIENT=$backup1
    export P4ROOT=$backup2
fi

time $HOME/wanliz-p4sw-common/misc/linux/unix-build \
    --tools  $HOME/wanliz-p4sw-common/tools \
    --devrel $HOME/wanliz-p4sw-common/devrel/SDK/inc/GL \
    --unshare-namespaces \
    nvmake \
    NV_COLOR_OUTPUT=1 \
    NV_GUARDWORD= \
    NV_COMPRESS_THREADS=$(nproc) \
    NV_FAST_PACKAGE_COMPRESSION=zstd $args

