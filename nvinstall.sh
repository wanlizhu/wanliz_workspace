#!/bin/bash

if [[ -z $1 ]]; then
    echo "http://linuxqa.nvidia.com/dvsbuilds/gpu_drv_bugfix_main_Release_Linux_AMD64_unix-build_Test_Driver/?C=M;O=D"
    echo "http://linuxqa/builds/release/display/x86_64/?C=M;O=D"
    echo "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/?C=M;O=D"
    echo 
    echo "[release|debug|develop] - install full build drivers"
    echo "123.45 - install driver by version"
    echo "d20250130 - install driver by date"
    echo "current   - install driver with latest date"
    echo "directory - install driver found in directory"
    echo "file path - install driver by path"
    echo ".dso file - install .dso driver module"
    echo "reset.dso - reset default driver modules"
    exit 
fi

if [[ $1 == 'http'* ]]; then
    if [[ "$1" =~ *"debug"* || "$1" =~ *"Debug"* ]]; then
        buildtype=-debug
    elif [[ "$1" =~ *"develop"* || "$1" =~ *"Develop"* ]]; then
        buildtype=-develop
    else
        buildtype=""
    fi
    pushd ~/Downloads >/dev/null
    name="${1##*/}"
    wget --no-check-certificate -O NVIDIA-Linux-x86_64-$name$buildtype.run $1 || exit -1
    popd >/dev/null
    $0 $HOME/Downloads/NVIDIA-Linux-x86_64-$name$buildtype.run
elif [[ $1 == "d"* ]]; then
    pushd ~/Downloads 
    echo "Available build types for $1: release, debug and develop"
    read -e -i "release" -p "Build type: " buildtype
    if [[ $buildtype == release ]]; then
        echo "Pulling driver list..."
        wanted=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/?C=M;O=D" | grep '<td><a href="20' | grep "${1//[!0-9]/}_" | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
        if [[ ! -f NVIDIA-Linux-x86_64-${wanted}.run ]]; then
            echo "Downloading NVIDIA-Linux-x86_64-${wanted}.run"
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-${wanted}.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/$wanted/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$wanted.run || exit -1
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-$wanted.run
    elif [[ $buildtype == debug ]]; then
        echo "Pulling driver list..."
        wanted=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/?C=M;O=D" | grep '<td><a href="20' | grep "${1//[!0-9]/}_" | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
        if [[ ! -f NVIDIA-Linux-x86_64-${wanted}-debug.run ]]; then
            echo "Downloading NVIDIA-Linux-x86_64-${wanted}-debug.run"
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-${wanted}-debug.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/$wanted/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$wanted.run || exit -1
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-${wanted}-debug.run
    elif [[ $buildtype == develop ]]; then
        echo "Pulling driver list..."
        wanted=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/?C=M;O=D" | grep '<td><a href="20' | grep "${1//[!0-9]/}_" | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
        if [[ ! -f NVIDIA-Linux-x86_64-${wanted}-develop.run ]]; then
            echo "Downloading NVIDIA-Linux-x86_64-${wanted}-develop.run"
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-${wanted}-develop.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/$wanted/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$wanted.run || exit -1
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-${wanted}-develop.run
    fi
    popd 
elif [[ $1 == current ]]; then
    pushd ~/Downloads 
    echo "Available build types for $1: release, debug and develop"
    read -e -i "release" -p "Build type: " buildtype
    if [[ $buildtype == release ]]; then
        echo "Pulling driver list..."
        current=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/?C=M;O=D" | grep '<td><a href="20' | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
        if [[ ! -f NVIDIA-Linux-x86_64-${current}.run ]]; then
            echo "Downloading NVIDIA-Linux-x86_64-${current}.run"
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-${current}.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/$current/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$current.run || exit -1
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-$current.run
    elif [[ $buildtype == debug ]]; then
        echo "Pulling driver list..."
        current=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/?C=M;O=D" | grep '<td><a href="20' | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
        if [[ ! -f NVIDIA-Linux-x86_64-${current}-debug.run ]]; then
            echo "Downloading NVIDIA-Linux-x86_64-${current}-debug.run"
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-${current}-debug.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/$current/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$current.run || exit -1
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-${current}-debug.run
    elif [[ $buildtype == develop ]]; then
        echo "Pulling driver list..."
        current=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/?C=M;O=D" | grep '<td><a href="20' | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
        if [[ ! -f NVIDIA-Linux-x86_64-${current}-develop.run ]]; then
            echo "Downloading NVIDIA-Linux-x86_64-${current}-develop.run"
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-${current}-develop.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/$current/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$current.run || exit -1
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-${current}-develop.run
    fi
    popd 
elif [[ $1 =~ ^[0-9]+\.[0-9]+$ || $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Available build types for $1: release, debug and develop"
    read -e -i "release" -p "Build type: " buildtype
    pushd ~/Downloads 
    if [[ $buildtype == release ]]; then
        if [[ ! -f NVIDIA-Linux-x86_64-$1.run ]]; then
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1.run http://linuxqa/builds/release/display/x86_64/$1/NVIDIA-Linux-x86_64-$1.run || exit -1
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-$1.run
    elif [[ $buildtype == debug ]]; then
        if [[ ! -f NVIDIA-Linux-x86_64-$1-debug.run ]]; then
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1-debug.run http://linuxqa/builds/release/display/x86_64/debug/$1/NVIDIA-Linux-x86_64-$1.run || exit -1 
        fi 
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-$1-debug.run
    elif [[ $buildtype == develop ]]; then
        if [[ ! -f NVIDIA-Linux-x86_64-$1-develop.run ]]; then
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1-develop.run http://linuxqa/builds/release/display/x86_64/develop/$1/NVIDIA-Linux-x86_64-$1.run || exit -1 
        fi
        $0 $HOME/Downloads/NVIDIA-Linux-x86_64-$1-develop.run
    fi
    popd
elif [[ $1 == release || $1 == debug || $1 == develop ]]; then
    outdir=$P4ROOT/_out/Linux_amd64_$1
    srcversion=$(grep '^#define NV_VERSION_STRING' $P4ROOT/drivers/common/inc/nvUnixVersion.h  | awk '{print $3}' | sed 's/"//g')
    if [[ -f  $outdir/NVIDIA-Linux-x86_64-$srcversion.run ]]; then
        echo "32-bits compatible packages are available"
        read -e -i "yes" -p "Install PPP (amd64 + x86) driver? (yes/no): " ans
        if [[ $ans == yes ]]; then
            $0 $outdir/NVIDIA-Linux-x86_64-$srcversion.run
        else
            $0 $outdir/NVIDIA-Linux-x86_64-$srcversion-internal.run
        fi
    else
        $0 $outdir/NVIDIA-Linux-x86_64-$srcversion-internal.run
    fi 
elif [[ -d $(realpath $1) ]]; then
    idx=0
    for file in $(realpath $1/*.run); do 
        if [[ -f $file ]]; then
            echo "[$idx] $file"
            echo "$file" > /tmp/$idx
        fi
        idx=$((idx + 1))
    done
    if [[ $idx == 0 ]]; then
        echo "Driver not found in $1"
        exit -1
    else
        read -e -i 0 -p "Select: " idx
        $0 $(cat /tmp/$idx)
    fi
elif [[ $1 == *".dso" ]]; then
    if [[ ! -f $1 ]]; then
        echo "Driver module not found: $filename"
        exit -1
    fi

    modversion=$(modinfo nvidia | grep ^version | awk '{print $2}')
    filepath=$(realpath $1)
    filename=$(basename $1).$modversion 

    if [[ $1 == "reset.dso" ]]; then
        find $HOME/so.$modversion.backup -type f -name "*.so.$modversion" -exec sh -c 'sudo cp -fv --remove-destination "$1" "/lib/x86_64-linux-gnu/$(basename "$1")"' _ {} \;
        sudo rm -rf $HOME/so.$modversion.backup
    else
        if [[ ! -f $HOME/so.$modversion.backup/$filename ]]; then
            mkdir -p $HOME/so.$modversion.backup
            sudo cp -fv /lib/x86_64-linux-gnu/$filename $HOME/so.$modversion.backup/$filename
        fi
        sudo cp -fv --remove-destination $filepath /lib/x86_64-linux-gnu/$filename
    fi 
else 
    if [[ $XDG_SESSION_TYPE != tty ]]; then
        echo "Please run through a tty or ssh session"
        exit -1
    fi

    driver=$(realpath $1)
    if [[ ! -e $driver ]]; then
        echo "Driver not found: $driver"
        exit -1
    fi

    echo "NVIDIA driver: $driver"
    read -p "Press [ENTER] to continue: " _
    sudo systemctl isolate multi-user
    chmod +x $driver 
    sudo $driver && 
    sudo systemctl isolate graphical || {
        # TODO: handle known errors
        echo "Failed to install NVIDIA driver"
        cat /var/log/nvidia-installer.log
    }
fi