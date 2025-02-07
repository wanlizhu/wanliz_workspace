if   [[ $HOSTNAME == wanliz-dev  ]]; then
    export P4CLIENT=wanliz-p4sw-bugfix_main
elif [[ $HOSTNAME == wanliz-test ]]; then
    export P4CLIENT=wanliz_p4sw_test
fi
if [[ -z $DISPLAY ]]; then
    export DISPLAY=:0
fi  
#if [[ -z $XAUTHORITY ]]; then
#    export XAUTHORITY=$HOME/.Xauthority
#fi
#if [[ ! -f $XAUTHORITY ]]; then
#    pushd ~ >/dev/null
#    touch $XAUTHORITY
#    sudo chown $USER:$USER $XAUTHORITY
#    chmod 600 $XAUTHORITY
#    xauth generate $DISPLAY . trusted
#    xauth list 
#    popd >/dev/null
#fi
export P4ROOT=$HOME/$P4CLIENT
export P4IGNORE=$HOME/.p4ignore
export P4PORT=p4proxy-sc.nvidia.com:2006
export P4USER=wanliz
export PATH=$HOME/wanliz_workspace:$PATH
export PATH=$HOME/wanliz_workspace/test_vp:$PATH
export PATH=$HOME/wanliz_workspace/test_wayland:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/viewperf2020:$PATH
export PATH=$HOME/nsight_systems/bin:$PATH
export PATH=$HOME/nvidia-nomad-internal/host/linux-desktop-nomad-x64:$PATH
export PATH=$HOME/PIC-X_Package/SinglePassCapture:$PATH
export PATH=$HOME/apitrace/bin:$PATH
export PATH=$HOME:$PATH
export __GL_DEBUG_BYPASS_ASSERT=c 
export DEBUGINFOD_URLS="https://debuginfod.ubuntu.com"
ulimit -c unlimited
alias  ss="source ~/.bashrc"
alias  pp="pushd ~/wanliz_workspace >/dev/null && git pull && popd >/dev/null && source ~/.bashrc"
alias  uu="pushd ~/wanliz_workspace >/dev/null && git add . && git commit -m uu && git push && popd >/dev/null"

function install-if-not-yet {
    for item in "$@"; do 
        if [[ $item == *":"* ]]; then
            if [[ -z $(which $(echo $item | awk -F ':' '{print $1}')) ]]; then
                pkgname=$(echo $item | awk -F ':' '{print $2}')
                sudo apt install -y $pkgname || echo "Failed to install $pkgname"
            fi
        else 
            if [[ -z $(which $item) ]]; then
                sudo apt install -y $item || echo "Failed to install $item"
            fi
        fi
    done 
}

function install-any {
    for item in "$@"; do 
        sudo apt install -y $item 
    done
}

#function chd {
#    case $1 in
#        gl|opengl|glcore) cd $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL ;;
#        glx) cd $P4ROOT/dev/gpu_drv/bugfix_main/OpenGL/win/glx ;;
#        egl) cd $P4ROOT/dev/gpu_drv/bugfix_main/OpenGL/win/egl/build ;;
#        *) cd $P4ROOT/dev/gpu_drv/bugfix_main ;;
#    esac
#}

function p4sync {
    if [[ ! -d $P4ROOT ]]; then
        read -e -i "yes" -p "Checkout perforce client $P4CLIENT? : " checkout
        if [[ $checkout == yes ]]; then
            mkdir -p $P4ROOT
            cd $P4ROOT
            p4 sync -f //sw/... &&
                echo "Sync $P4CLIENT (forced)  [OK]" ||
                echo "Sync $P4CLIENT (forced)  [FAILED]"
        fi
    else
        p4 sync //sw/... 
    fi
}

function clone-p4sw-gitmirror {
    git clone https://soprano.nvidia.com/git-client/sw $HOME/sw || return -1
}

function find-commit-id-by-changelist {
    git log --all --grep="$1" --oneline
}

function nvidia-src-version {
    grep '^#define NV_VERSION_STRING' $P4ROOT/dev/gpu_drv/bugfix_main/drivers/common/inc/nvUnixVersion.h  | awk '{print $3}' | sed 's/"//g'
}

function nvidia-mod-version {
    modinfo nvidia | grep ^version | awk '{print $2}'
}

function nvidia-build-type {
    if [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "debug build") ]]; then
        echo debug
    elif [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "develop build") ]]; then
        echo develop
    else
        echo release
    fi
}

function nvidia-version {
    echo "Nvidia MOD ($(nvidia-build-type) build) version: $(nvidia-mod-version)" 
    echo "Nvidia SRC ($P4CLIENT) version: $(nvidia-src-version)"
}

function nvidia-build-info {
    if [[ -z $1 ]]; then
        read -p "Enter the version string: " version
    else
        version=$1
    fi

    read -e -i "no" -p "Open web page for details? (yes/no): " ans
    if [[ $ans == yes ]]; then
        url="https://dvsweb.nvidia.com/DVSWeb/view/content/od/odBuilds.jsf?versionNumber=$version"
        xdg-open $url || gio open $url
    fi 

    if [[ -z $(which curl) ]]; then
        sudo apt install -y curl 
    fi

    curl --range 0-1023 -o /tmp/head-of-$version http://linuxqa/builds/release/display/x86_64/$version/logs/Build-20$version.log
    cat /tmp/head-of-$version | grep CHANGELIST
    cat /tmp/head-of-$version | grep NV_DVS_COMPONENT
}

function nvidia-install-ssl-certificate {
    sudo apt install -y ca-certificates
    for url in "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2016-10-13-1.crt" \
               "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2016-10-13-2.crt" \
               "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2016-10-13-3.crt" \
               "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2016-10-13-4.crt" \
               "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2016-10-12-1.crt" \
               "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2016-10-12-2.crt" \
               "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2016-10-4.crt" \
               "//sw/pvt/aplattner/ssl/intermediates/HQNVCA122-CA-2015-10-1.crt" \
               "//sw/pvt/aplattner/ssl/roots/HQNVCA121-CA-2017-06-20.crt" \
               "//sw/pvt/aplattner/ssl/roots/HQNVCA121-CA-2022-02-27.crt"; do
        p4 print -o ~/Downloads/nvidia.crt.d/$(basename $url) $url 
        sudo cp -f ~/Downloads/nvidia.crt.d/$(basename $url) /usr/local/share/ca-certificates/
    done
    sudo update-ca-certificates
}

function nvidia-install {
    if [[ -z $(which curl) ]]; then
        sudo apt install -y curl
    fi
    if [[ -z $1 ]]; then
        echo "Download by changelist:"
        echo "    http://linuxqa.nvidia.com/dvsbuilds/gpu_drv_bugfix_main_Release_Linux_AMD64_unix-build_Test_Driver/?C=M;O=D"
        echo "    http://linuxqa.nvidia.com/dvsbuilds/gpu_drv_bugfix_main_Debug_Linux_AMD64_unix-build_Driver/?C=M;O=D"
        echo "Download by version:"
        echo "    http://linuxqa/builds/release/display/x86_64/?C=M;O=D"
        echo "    http://linuxqa/builds/release/display/x86_64/debug/?C=M;O=D"
        echo "    http://linuxqa/builds/release/display/x86_64/develop/?C=M;O=D"
        echo "Download by date:"
        echo "    http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/?C=M;O=D"
        echo "    http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/?C=M;O=D"
        echo "    http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/?C=M;O=D"
    elif [[ $1 == 'http'* ]]; then
        if [[ "$1" =~ *"debug"* || "$1" =~ *"Debug"* ]]; then
            buildtype=-debug
        elif [[ "$1" =~ *"develop"* || "$1" =~ *"Develop"* ]]; then
            buildtype=-develop
        else
            buildtype=""
        fi
        pushd ~/Downloads >/dev/null
        name="${1##*/}"
        wget --no-check-certificate -O NVIDIA-Linux-x86_64-$name$buildtype.run $1 || return -1
        popd >/dev/null
        nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-$name$buildtype.run
    elif [[ $1 == "d"* ]]; then
        pushd ~/Downloads 
        echo "Available build types for $1: release, debug and develop"
        read -e -i "release" -p "Build type: " buildtype
        if [[ $buildtype == release ]]; then
            echo "Pulling driver list..."
            wanted=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/?C=M;O=D" | grep '<td><a href="20' | grep "${1//[!0-9]/}_" | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
            if [[ ! -f NVIDIA-Linux-x86_64-${wanted}.run ]]; then
                echo "Downloading NVIDIA-Linux-x86_64-${wanted}.run"
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-${wanted}.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/$wanted/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$wanted.run || return -1
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-$wanted.run
        elif [[ $buildtype == debug ]]; then
            echo "Pulling driver list..."
            wanted=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/?C=M;O=D" | grep '<td><a href="20' | grep "${1//[!0-9]/}_" | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
            if [[ ! -f NVIDIA-Linux-x86_64-${wanted}-debug.run ]]; then
                echo "Downloading NVIDIA-Linux-x86_64-${wanted}-debug.run"
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-${wanted}-debug.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/$wanted/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$wanted.run || return -1
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-${wanted}-debug.run
        elif [[ $buildtype == develop ]]; then
            echo "Pulling driver list..."
            wanted=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/?C=M;O=D" | grep '<td><a href="20' | grep "${1//[!0-9]/}_" | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
            if [[ ! -f NVIDIA-Linux-x86_64-${wanted}-develop.run ]]; then
                echo "Downloading NVIDIA-Linux-x86_64-${wanted}-develop.run"
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-${wanted}-develop.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/$wanted/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$wanted.run || return -1
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-${wanted}-develop.run
        fi
        popd 
    elif [[ $1 == current || $1 == tot ]]; then
        pushd ~/Downloads 
        echo "Available build types for $1: release, debug and develop"
        read -e -i "release" -p "Build type: " buildtype
        if [[ $buildtype == release ]]; then
            echo "Pulling driver list..."
            current=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/?C=M;O=D" | grep '<td><a href="20' | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
            if [[ ! -f NVIDIA-Linux-x86_64-${current}.run ]]; then
                echo "Downloading NVIDIA-Linux-x86_64-${current}.run"
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-${current}.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/$current/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$current.run || return -1
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-$current.run
        elif [[ $buildtype == debug ]]; then
            echo "Pulling driver list..."
            current=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/?C=M;O=D" | grep '<td><a href="20' | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
            if [[ ! -f NVIDIA-Linux-x86_64-${current}-debug.run ]]; then
                echo "Downloading NVIDIA-Linux-x86_64-${current}-debug.run"
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-${current}-debug.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/$current/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$current.run || return -1
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-${current}-debug.run
        elif [[ $buildtype == develop ]]; then
            echo "Pulling driver list..."
            current=$(curl -s "http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/?C=M;O=D" | grep '<td><a href="20' | head -n 1 | awk -F '"' '{print $8}' | awk -F '/' '{print $1}')
            if [[ ! -f NVIDIA-Linux-x86_64-${current}-develop.run ]]; then
                echo "Downloading NVIDIA-Linux-x86_64-${current}-develop.run"
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-${current}-develop.run http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/$current/NVIDIA-Linux-x86_64-dev_gpu_drv_bugfix_main-$current.run || return -1
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-${current}-develop.run
        fi
        popd 
    elif [[ $1 =~ ^[0-9]+\.[0-9]+$ || $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Available build types for $1: release, debug and develop"
        read -e -i "release" -p "Build type: " buildtype
        pushd ~/Downloads 
        if [[ $buildtype == release ]]; then
            if [[ ! -f NVIDIA-Linux-x86_64-$1.run ]]; then
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1.run http://linuxqa/builds/release/display/x86_64/$1/NVIDIA-Linux-x86_64-$1.run || return -1
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-$1.run
        elif [[ $buildtype == debug ]]; then
            if [[ ! -f NVIDIA-Linux-x86_64-$1-debug.run ]]; then
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1-debug.run http://linuxqa/builds/release/display/x86_64/debug/$1/NVIDIA-Linux-x86_64-$1.run || return -1 
            fi 
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-$1-debug.run
        elif [[ $buildtype == develop ]]; then
            if [[ ! -f NVIDIA-Linux-x86_64-$1-develop.run ]]; then
                wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1-develop.run http://linuxqa/builds/release/display/x86_64/develop/$1/NVIDIA-Linux-x86_64-$1.run || return -1 
            fi
            nvidia-install $HOME/Downloads/NVIDIA-Linux-x86_64-$1-develop.run
        fi
        popd
    elif [[ $1 == local ]]; then
        echo "[1] Linux_amd64_release $([[ -d $P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_release ]] || echo '(NULL)')"
        echo "[2] Linux_amd64_debug   $([[ -d $P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_debug   ]] || echo '(NULL)')"
        echo "[3] Linux_amd64_develop $([[ -d $P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_develop ]] || echo '(NULL)')"
        read -p ">> " subdir
        case $subdir in
            1) outdir=$P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_release ;;
            2) outdir=$P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_debug   ;;
            3) outdir=$P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_develop ;;
        esac
        if [[ -f  $outdir/NVIDIA-Linux-x86_64-$(nvidia-src-version).run ]]; then
            echo "32-bits compatible packages are available"
            read -e -i "yes" -p "Install PPP (amd64 + x86) driver? (yes/no): " ans
            if [[ $ans == yes ]]; then
                nvidia-install $outdir/NVIDIA-Linux-x86_64-$(nvidia-src-version).run
            else
                nvidia-install $outdir/NVIDIA-Linux-x86_64-$(nvidia-src-version)-internal.run
            fi
        else
            nvidia-install $outdir/NVIDIA-Linux-x86_64-$(nvidia-src-version)-internal.run
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
            return -1
        else
            read -e -i 0 -p "Select: " idx
            nvidia-install $(cat /tmp/$idx)
        fi
    else 
        if [[ $XDG_SESSION_TYPE != tty ]]; then
            echo "Please run through a tty or ssh session"
            return -1
        fi

        driver=$(realpath $1)
        echo "NVIDIA driver: $driver"
        read -p "Press [ENTER] to continue: " _
        sudo systemctl isolate multi-user
        sleep 1

        if [[ $(tty) == "/dev/tty"* ]]; then
            ttyid=$(sudo fgconsole)
            sudo chvt $ttyid 
        fi

	    chmod +x $driver 
        sudo $driver && 
        sudo systemctl isolate graphical || {
            # TODO: handle known errors
            echo "Failed to install NVIDIA driver"
            cat /var/log/nvidia-installer.log
        }
    fi
}

function nvidia-uninstall-again {
    if [[ -f /usr/bin/nvidia-uninstall ]]; then
        sudo /usr/bin/nvidia-uninstall
    fi
    sudo apt remove -y --purge '^nvidia-.*'
    sudo apt autoremove -y
}

function nvidia-deploy-dso-glcore {
    version=$(nvidia-mod-version)
    if [[ $1 == restore ]]; then
        sudo cp -v --remove-destination $HOME/libnvidia-glcore.so.$version.backup /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        sudo rm -v -f $HOME/libnvidia-glcore.so.$version.backup
    else
        if [[ -f $1 ]]; then
            if [[ ! -f $HOME/libnvidia-glcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version $HOME/libnvidia-glcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $1 /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        else
            config=$(nvidia-build-type)
            echo "Copy OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so ($(nvidia-src-version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-glcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version $HOME/libnvidia-glcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        fi
    fi
}

function nvidia-deploy-dso-eglcore {
    version=$(nvidia-mod-version)
    if [[ $1 == restore ]]; then
        sudo cp -v --remove-destination $HOME/libnvidia-eglcore.so.$version.backup /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version
        sudo rm -v -f $HOME/libnvidia-eglcore.so.$version.backup
    else
        if [[ -f $1 ]]; then
            if [[ ! -f $HOME/libnvidia-eglcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version $HOME/libnvidia-eglcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $1 /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version
        else
            config=$(nvidia-build-type)
            echo "Copy OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so ($(nvidia-src-version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-eglcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version $HOME/libnvidia-eglcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version
        fi
    fi
}

function nvidia-deploy-dso-glx {
    version=$(nvidia-mod-version)
    if [[ $1 == restore ]]; then
        sudo cp -v --remove-destination $HOME/libGLX_nvidia.so.$version.backup /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version
        sudo rm -v -f $HOME/libGLX_nvidia.so.$version.backup
    else
        if [[ -f $1 ]]; then
            if [[ ! -f $HOME/libGLX_nvidia.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version $HOME/libGLX_nvidia.so.$version.backup
            fi
            sudo cp -v --remove-destination $1 /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version
        else
            config=$(nvidia-build-type)
            echo "Copy OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so ($(nvidia-src-version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libGLX_nvidia.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version $HOME/libGLX_nvidia.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version
        fi
    fi
}

function nvidia-deploy-dso-xorg {
    if [[ $1 == restore ]]; then
        sudo cp -v --remove-destination $HOME/nvidia_drv.so.backup /lib/xorg/modules/drivers/nvidia_drv.so
        sudo rm -v -f $HOME/nvidia_drv.so.backup
    else
        if [[ -f $1 ]]; then
            if [[ ! -f $HOME/nvidia_drv.so.backup ]]; then
                sudo cp -v /lib/xorg/modules/drivers/nvidia_drv.so $HOME/nvidia_drv.so.backup
            fi
            sudo cp -v --remove-destination $1 /lib/xorg/modules/drivers/nvidia_drv.so
        else
            config=$(nvidia-build-type)
            echo "Copy xfree86/4.0/nvidia/_out/Linux_amd64_$config/nvidia_drv.so ($(nvidia-src-version)) to /lib/xorg/modules/drivers/nvidia_drv.so"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/nvidia_drv.so.backup ]]; then
                sudo cp -v /lib/xorg/modules/drivers/nvidia_drv.so $HOME/nvidia_drv.so.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/xfree86/4.0/nvidia/_out/Linux_amd64_$config/nvidia_drv.so /lib/xorg/modules/drivers/nvidia_drv.so
        fi
    fi
}

function nvidia-shader-help {
    echo "export __GL_c5e9d7a4=0x4574563 -> dump ogl shaders"
    echo "export __GL_c5e9d7a4=0x6839369 -> replace ogl shaders"
}

function nvidia-find-symbol {
    if [[ -z $1 ]]; then
        read -p "Symbol: " sym
    else
        sym=$1
    fi

    for dso in `find /lib/x86_64-linux-gnu/ -name "libnvidia-*.so.$(nvidia-mod-version)"`; do
        if [[ ! -z $(nm -C $dso | grep -i $sym) ]]; then
            echo -e "$(nm -C $dso | grep -i $sym) in $dso"
        fi
    done
}

function prime {
    if [[ $XDG_SESSION_TYPE == wayland ]]; then
        echo "\$XDG_SESSION_TYPE is wayland" 
        export GBM_BACKEND=nvidia-drm
        echo "export GBM_BACKEND=nvidia-drm"
    fi

    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    echo "export __NV_PRIME_RENDER_OFFLOAD=1"
    echo "export __GLX_VENDOR_LIBRARY_NAME=nvidia"

    "$@"
}

function perfhelp {
    echo 'sudo perf record -g --call-graph dwarf --freq=1000 --output=$(date +%H%M%S).perf.data -- "$@"'
}

function cpdir {
    if [[ -z $1 ]]; then
        read -e -i "$(pwd)" -p "Src dir: " src
        src=$(realpath $src)
    else
        src=$(realpath $1)
    fi

    echo "Src dir contains $(du -sh $src | cut -f1)"
    read -p "Dst host: " host
    ismacos=no
    if [[ $host == wanliz-test || $host == wanliz-dev || $host == mac ]]; then
        if [[ $host == mac ]]; then
            if [[ ! -f /tmp/mac.ip ]]; then
                read -p "Add and remember IP address of MacBook: " macip
                echo $macip > /tmp/mac.ip
            fi
            host=$(cat /tmp/mac.ip)
            ismacos=yes
        fi
        user=wanliz 
    else
        read -e -i "$USER" -p "Dst user: " user
    fi

    if ssh -o BatchMode=yes -o ConnectTimeout=1 $user@$host exit 2>/dev/null; then
        echo "" >/dev/null
    else
        read -e -i "yes" -p "Set up SSH key to $host? (yes/no): " ans
        if [[ $ans == yes ]]; then
            if [[ ! -f ~/.ssh/id_rsa ]]; then
                ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N ""
            fi
            ssh-copy-id $user@$host
        fi
    fi

    if [[ $ismacos == yes ]]; then
        ssh $user@$host "[[ ! -d /Users/$user/$HOSTNAME ]] && mkdir -p /Users/$user/$HOSTNAME"
        rsync -avz --delete --force --progress $src/ $user@$host:/Users/$user/$HOSTNAME/$(basename $src) 
    else
        ssh $user@$host "[[ ! -d /home/$user/$HOSTNAME ]] && mkdir -p /home/$user/$HOSTNAME"
        rsync -avz --delete --force --progress $src/ $user@$host:/home/$user/$HOSTNAME/$(basename $src)
    fi
}

function flamegraph {
    if [[ ! -f ~/Flamegraph/flamegraph.pl ]]; then
        git clone --depth 1 https://github.com/brendangregg/FlameGraph.git $HOME/Flamegraph || return -1
        sudo apt install -y python3-pip
        sudo apt install -y graphviz
        pip install gprof2dot 
        pip install --break-system-packages gprof2dot 
    fi
    
    midfile=/tmp/$(basename $1)
    sudo chmod 666 $1
    sudo perf script --no-inline --force --input=$1 -F +pid > $1.perthread && 
    sudo perf script --no-inline --force --input=$1 >$midfile.stage1 && 
    sudo ~/Flamegraph/stackcollapse-perf.pl $midfile.stage1 >$midfile.stage2 && 
    sudo ~/Flamegraph/stackcollapse-recursive.pl $midfile.stage2 >$midfile.stage3 && 
    sudo ~/Flamegraph/flamegraph.pl $midfile.stage3 >$1.svg && 
        echo "Generated $1.svg" ||
        echo "Failed to generate svg flamegraph" 

    sudo perf script --no-inline --force --input=$1 | c++filt | gprof2dot -f perf | dot -Tpng -o $1.png && 
        echo "Generated $1.png" || 
        echo "Failed to generate png diagram"
}

function sshkey {
    read -p "Remote host: " host
    read -p "Remote user: " user
    if [[ ! -f ~/.ssh/id_rsa ]]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N ""
    fi
    ssh-copy-id $user@$host
}

function nopasswd {
    if [[ -z $(sudo cat /etc/sudoers | grep "$USER ALL=(ALL) NOPASSWD:ALL") ]]; then
        echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null
        sudo cat /etc/sudoers | tail -1
    fi
}

function use-gcc12 {
    if [[ -z $(which gcc-12) ]]; then
        sudo apt install -y gcc-12
    fi
    sudo ln -sf /usr/bin/gcc-12 /usr/bin/gcc
    gcc --version
}

function resize-display {
    read -p "New size: " size
    outputname=$(xrandr | grep " connected" | awk '{print $1}')
    if [[ ! -z $(xrandr | grep $size) ]]; then
        xrandr --output $outputname --mode $size
    else
        spec=$(cvt ${size//x/ } | tail -1 | cut -d' ' -f2-)
        mode=$(cvt ${size//x/ } | tail -1 | cut -d' ' -f2- | awk '{print $1}')
        xrandr --newmode $spec 
        xrandr --addmode $outputname $mode 
        xrandr --output  $outputname --mode $mode 
    fi
}

function amdhelp {
    echo "Latest AMD driver: https://repo.radeon.com/amdgpu-install/latest/ubuntu/jammy/"
}

function xdgst {
    echo $XDG_SESSION_TYPE
}

function change-p4client {
    export P4CLIENT=$1
    export P4ROOT=$HOME/$P4CLIENT
}

function check-p4ignore {
    if [[ -f $HOME/.p4ignore ]]; then
        cat $HOME/.p4ignore
    else
        read -e -i "yes" -p "$HOME/.p4ignore doesn't exist, create with default value? (yes/no): " ans
        if [[ $ans == yes ]]; then
            echo -e "_out\n.git\n.vscode\n" > $HOME/.p4ignore
            cat $HOME/.p4ignore
        fi
    fi
}

function dvsbuild {
    P4CLIENT=wanliz-p4sw-common $HOME/wanliz-p4sw-common/automation/dvs/dvsbuild/dvsbuild.pl -c $1 
}

function download-big-file {
    if [[ -z $(which aria2c) ]]; then
        sudo apt install -y aria2
    fi
    time aria2c -c -x 16 -d $HOME/Downloads -o $(basename $1) --check-certificate=false $1 || return -1
}

function unzip-big-file {
    if [[ -z $(which pigz) ]]; then
        sudo apt install -y pigz
    fi

    if [[ -z $(which pv) ]]; then
        sudo apt install -y pv
    fi

    if [[ $1 == *".tar.gz" ]]; then
        pigz -dc $1 | pv | tar xf -
    else
        # TODO: supports more formats 
        return -1
    fi
}

# TODO: Use multithreads
function install-viewperf {
    pushd $HOME/Downloads >/dev/null
    download-big-file http://linuxqa.nvidia.com/people/nvtest/pynv_files/viewperf2020v3/viewperf2020v3.tar.gz || return -1
    unzip-big-file viewperf2020v3.tar.gz
    mv viewperf2020 $HOME
    popd >/dev/null
}

function start-bare-x {
    if [[ $XDG_SESSION_TYPE != tty ]]; then
        echo "Please run through a tty or ssh session"
        return 
    fi
    
    xset -dpms
    xset s off
    if [[ -z $(grep '"DPMS" "false"' /etc/X11/xorg.conf) ]]; then
        sudo sed -i 's/"DPMS"/"DPMS" "false"/g' /etc/X11/xorg.conf
    fi

    if [[ -z $(grep anybody /etc/X11/Xwrapper.config) ]]; then
        sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config
    fi

    #if [[ -z $(grep 'needs_root_rights=no' /etc/X11/Xwrapper.config) ]]; then
    #    echo -e '\nneeds_root_rights=no' | sudo tee -a /etc/X11/Xwrapper.config >/dev/null
    #fi

    if [[ ! -z $(pidof Xorg) ]]; then
        pkill Xorg
    fi
    
    sudo systemctl stop gdm
    sudo X :0 &
}

function stop-bare-x {
    sudo kill -15 `pidof Xorg`
    sleep 1
    sudo systemctl start gdm 
}

function disable-only-console-users-are-allowed-to-run-the-x-server {
    if [[ -z $(grep anybody /etc/X11/Xwrapper.config) ]]; then
        sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config
        echo "Replaced console with anybody in /etc/X11/Xwrapper.config"
    fi
}

function start-simple-desktop {
    if [[ $XDG_SESSION_TYPE != tty ]]; then
        echo "Please run through a tty session"
        return
    fi
    if [[ $(systemctl is-active gdm3) == "active" ]]; then
        read -e -i "yes" -p "Stop running gdm3? (yes/no): " ans
        if [[ $ans != "yes" ]]; then
            return
        fi
        sudo systemctl stop gdm3
    fi
    if [[ -z $(grep anybody /etc/X11/Xwrapper.config) ]]; then
        sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config
        echo "Replaced console with anybody in /etc/X11/Xwrapper.config"
    fi
    if [[ -z $(which openbox) ]]; then
        sudo apt install -y openbox
    fi

    sudo X -retro &
    sleep 2
    export DISPLAY=:0
    openbox --replace &
}

function load-pic-env {
    pushd $HOME/PIC-X_Package/SinglePassCapture/Scripts >/dev/null
    source ./setup-symbollinks.sh 
    source ./setup-env.sh 
    popd >/dev/null 
}

function check-vnc {
    sudo lsof -i :5900-5909
}

function restart-vnc {
    sudo systemctl restart x11vnc.service
}

function uninstall-vnc {
    sudo systemctl stop x11vnc.service
    sudo systemctl disable x11vnc.service
    sudo rm -rf /etc/systemd/system/x11vnc.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}

function load-vksdk {
    version=1.3.296.0
    if [[ ! -d $HOME/VulkanSDK/$version ]]; then
        cd $HOME/Downloads
        wget https://sdk.lunarg.com/sdk/download/$version/linux/vulkansdk-linux-x86_64-$version.tar.xz || return -1
        tar -xvf vulkansdk-linux-x86_64-$version.tar.xz
        mkdir -p $HOME/VulkanSDK
        mv $version $HOME/VulkanSDK
        install-any libxcb-xinerama0 libxcb-xinput0
    fi
    source $HOME/VulkanSDK/$version/setup-env.sh
    echo $VULKAN_SDK
}

function install-nsys {
    if [[ -d ~/nsight_systems ]]; then
        echo "Nsight systems has already installed"
        read -e -i "no" -p "Reinstall? (yes/no): " ans
        if [[ $ans == no ]]; then
            return 
        fi
    fi

    pushd ~/Downloads
    if [[ ! -f nsight_systems-linux-x86_64-2024.6.2.225.tar.gz ]]; then
        read -p "NVIDIA account password: " passwd
        wget https://wanliz:$passwd@urm.nvidia.com/artifactory/swdt-nsys-generic/ctk/12.8/2024.6.2.225/nsight_systems-linux-x86_64-2024.6.2.225.tar.gz || return -1
    fi
    tar -zxvf nsight_systems-linux-x86_64-2024.6.2.225.tar.gz
    rm -rf $HOME/nsight_systems
    mv nsight_systems $HOME 
    popd

    sudo apt install -y libxcb-cursor0
    sudo apt install -y libxcb-cursor-dev

    sudo mkdir -p /root/.nsightsystems/Projects 
    sudo ln -sf /root/.nsightsystems/Projects ~/nsight_systems_projects
    sudo chmod -R 777 /root/.nsightsystems
}

function install-ngfx {
    if [[ -d ~/nvidia-nomad-internal ]]; then
        echo "Nsight graphics has already installed"
        read -e -i "no" -p "Reinstall? (yes/no): " ans
        if [[ $ans == no ]]; then
            return 
        fi
    fi

    if [[ ! -d /mnt/10.126.133.25/share || -z $(ls -A /mnt/10.126.133.25/share 2>&1) ]]; then
        if [[ -z $(dpkg -l | grep cifs-utils) ]]; then
            sudo apt install -y cifs-utils
        fi
        sudo mkdir -p /mnt/10.126.133.25/share
        sudo mount.cifs -o user=wanliz //10.126.133.25/share /mnt/10.126.133.25/share || return -1
        sudo df -h /mnt/10.126.133.25/share
    fi
    
    pushd ~/Downloads 
    cp /mnt/10.126.133.25/share/Devtools/NomadBuilds/latest/Internal/linux/*.tar.gz . || return -1
    tar -zxvf NVIDIA_Nsight_Graphics_*-internal.tar.gz || return -1
    mv nvidia-nomad-internal-Linux.linux nvidia-nomad-internal
    rm -rf $HOME/nvidia-nomad-internal
    mv nvidia-nomad-internal $HOME
    popd

    sudo apt install -y libxcb-cursor0
    sudo apt install -y libxcb-cursor-dev

    sudo mkdir -p /root/Documents
    sudo ln -sf /root/Documents ~/rootDocuments
    sudo chmod -R 777 /root/Documents

    if [[ ! -f /etc/modprobe.d/nvidia-restrict-profiling-to-admin-users.conf ]]; then
        echo 'options nvidia "NVreg_RestrictProfilingToAdminUsers=0"' | sudo tee /etc/modprobe.d/nvidia-restrict-profiling-to-admin-users.conf
        sudo update-initramfs -u -k all
        echo "A reboot is required for Nsight graphics"
    fi
}

function install-apitrace {
    if [[ -z $(which bzip2) ]]; then
        sudo apt install -y bzip2
    fi

    pushd ~/Downloads
    wget https://github.com/apitrace/apitrace/releases/download/12.0/apitrace-12.0-Linux.tar.bz2 || return -1
    bzip2 -fdk apitrace-12.0-Linux.tar.bz2
    tar -xvf apitrace-12.0-Linux.tar
    mv apitrace-12.0-Linux apitrace
    mv apitrace $HOME
    popd
}

function install-display-managers {
    sudo apt install -y lightdm
    sudo apt install -y kde-plasma-desktop
    sudo apt install -y gdm3
    # The "Disable Unredirect Fullscreen Windows" extension allows you to disable compositing for full-screen applications
    sudo apt install -y gnome-shell-extension-manager 

    # Set up automatic login for lightdm

}

function sync-root-docs {
    if [[ ! -d ~/Documents/root_documents_sync ]]; then
        mkdir -p ~/Documents/root_documents_sync
    fi
    sudo rsync -a --delete --force /root/Documents/ ~/Documents/root_documents_sync

    if [[ ! -d ~/Documents/root_nsightsystems_sync ]]; then
        mkdir -p ~/Documents/root_nsightsystems_sync
    fi
    sudo rsync -a --delete --force /root/.nsightsystems/ ~/Documents/root_nsightsystems_sync
    
    sudo chown -R $USER:$USER ~/Documents
}

function show-listen-ports {
    sudo ss -tunlp
}

function sync-workspace {
    echo "[1] Sync from local to remote"
    echo "[2] Sync from remote to local"
    read -e -i "1" -p "Mode: " mode
    read -p "Remote host: " remote

    if [[ $mode == 1 ]]; then
        if [[ $(uname) == Darwin ]]; then
            rsync -avz /Users/$USER/wanliz_workspace/ $USER@$remote:/home/$USER/wanliz_workspace
        else
            rsync -avz /home/$USER/wanliz_workspace/ $USER@$remote:/home/$USER/wanliz_workspace
        fi
    else
        rsync -avz $USER@$remote:/home/$USER/wanliz_workspace/ /home/$USER/wanliz_workspace
    fi 
}

function install-kernel {
    read -p "Linux kernel version: " version
    if [[ ! -z $(apt search linux-image-$version | grep -E "linux-image-$version-.*-generic") ]]; then
        apt search linux-image-$version | grep -E "linux-image-$version-.*-generic"
        read -p "Patch number: " patch
        sudo apt install -y linux-image-$version-$patch-generic 
        sudo apt install -y linux-modules-$version-$patch-generic
        sudo apt install -y linux-headers-$version-$patch-generic
    else
        echo "Kernel $version is not found"
    fi

    echo "List all available GRUB menu entries:"
    sudo grep 'menuentry ' /boot/grub/grub.cfg | cut -d "'" -f2 | nl -v1 | tee /tmp/menuentry

    read -e -i "yes" -p "Configure grub? (yes/no): " config
    if [[ $config == yes ]]; then
        read -p "Kernel index: " index
        kernelname=$(awk "NR==$index" /tmp/menuentry | cut -f2-)
        sudo sed -i "/^GRUB_DEFAULT=/c\GRUB_DEFAULT=\"Advanced options for Ubuntu>$kernelname\"" /etc/default/grub
        sudo update-grub
        sudo cat /etc/default/grub | grep "GRUB_DEFAULT="
        echo "Ready to reboot now"
    fi
}

function pull-dvs-source {
    echo "Installed Nvidia MOD version is $(nvidia-mod-version)"
    read -e -i "$(nvidia-mod-version | cut -d'.' -f1)" -p "Pull dvs source at version: " version

    if [[ -d /dvs ]]; then
        read -e -i "no" -p "Delete existing /dvs folder? (yes/no): " ans 
        if [[ $ans == yes ]]; then
            sudo rm -rf /dvs
        fi
    fi
    
    echo "[1] drivers/OpenGL"
    echo "[2] drivers/OpenGL/glcore"
    read -e -i "1" -p "Select folders to pull: " folders

    if [[ -z $folders ]]; then
        return -1
    fi

    if [[ ! -d /dvs/p4/build/sw ]]; then
        sudo mkdir -p /dvs/p4/build/sw
        sudo chown -R $USER /dvs 
        sudo chmod -R 777 /dvs 
    fi

    echo "Client: wanliz_temp_client" > /tmp/wanliz_temp_client.txt
    echo "Owner: wanliz" >> /tmp/wanliz_temp_client.txt
    echo "Host: $HOSTNAME" >> /tmp/wanliz_temp_client.txt
    echo "Root: /dvs/p4/build/sw" >> /tmp/wanliz_temp_client.txt
    echo "Options: noallwrite noclobber nocompress unlocked nomodtime rmdir" >> /tmp/wanliz_temp_client.txt
    echo "View:" >> /tmp/wanliz_temp_client.txt

    for folder in $folders; do 
        if [[ ! -d /dvs/p4/build/sw/rel/gpu_drv/r$version/r${version}_00/$folder ]]; then
            case $folder in
                1) folder="drivers/OpenGL" ;;
                2) folder="drivers/OpenGL/glcore" ;;
                *) continue ;;
            esac
            echo "    //sw/rel/gpu_drv/r$version/r${version}_00/$folder/... //wanliz_temp_client/rel/gpu_drv/r$version/r${version}_00/$folder/..." >> /tmp/wanliz_temp_client.txt
        fi
    done 

    if [[ $(p4 login -s) == *"(P4PASSWD) invalid or unset"* ]]; then
        p4 login -a
    fi

    p4 client -i < /tmp/wanliz_temp_client.txt || return -1
    p4 client -o wanliz_temp_client
    P4CLIENT=wanliz_temp_client P4ROOT=/dvs/p4/build/sw p4 -I sync -q -f //sw/... 
    p4 client -d wanliz_temp_client
    du -sh /dvs/p4/build/sw
}

function gdb-attach-xorg {
    sudo gdb -ex "handle SIGPIPE nostop noprint pass" -ex "cont" $(nvidia-smi | grep Xorg | awk '{print $7}') $(pgrep Xorg)
}

function gdb-attach-gdm-x-session {
    sudo gdb -ex "handle SIGPIPE nostop noprint pass" -ex "cont" /usr/libexec/gdm-x-session $(pgrep gdm-x-session)
}

function install-dcgm {
    if [[ -z $(dpkg -l | grep datacenter-gpu-manager) ]]; then
        pushd ~/Downloads 
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb || return -1
        sudo dpkg -i cuda-keyring_1.0-1_all.deb
        sudo apt update
        sudo apt install -y datacenter-gpu-manager
        sudo systemctl --now enable nvidia-dcgm
        dcgmi discovery -l
        popd 
    fi
}

function nvidia-smi-watch {
    watch -n 1 nvidia-smi
}

function enable-nvidia-debug {
    if [[ ! -f /etc/modprobe.d/nvidia-debug.conf ]]; then
        echo 'options nvidia NVreg_RegistryDwords="RMLogLevel=0x1"' | sudo tee /etc/modprobe.d/nvidia-debug.conf
        sudo update-initramfs -u
        echo "Ready to reboot"
    fi
}

function change-hostname {
    if [[ -z $1 ]]; then
        read -p "New hostname: " name
    else
        name=$1
    fi

    if [[ ! -z $name ]]; then 
        oldname=$(hostname)
        sudo hostnamectl set-hostname $name 
        sudo sed -i "s/$oldname/$name/g" /etc/hosts
        echo "Hostname changed from $oldname to $name"
    fi
}

function encrypt {
    if [[ -z $1 ]]; then
        read -p "Text: " txt
    else
        txt="$1"
    fi

    read -s -p "Encryption Password: " password
    echo 
    echo "$txt" | openssl enc -aes-256-cbc -a -salt -pass pass:"$password" -pbkdf2
}

function decrypt {
    if [[ -z $1 ]]; then
        read -p "Encrypted: " txt
    else
        txt="$1"
    fi
    
    read -s -p "Password: " password
    echo "$txt" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$password" -pbkdf2
}

function send-email {
    if [[ -z $(which mutt) ]]; then
        sudo apt install -y mutt 
    fi

    if [[ ! -f $HOME/.muttrc ]]; then
        echo "Decode Gmail address:"
        gmail=$(decrypt 'U2FsdGVkX1/ftnBAbmGmt6BVRc7gdD2aU8UN0EaEVb4yoVjPGvKQGMvon40nkMXf')
        echo "Decode Gmail passkey:"
        gmailpass=$(decrypt 'U2FsdGVkX1+wVKiN/NT+/lxhikkDYmaFok9maq5e4sfuL8NQsxgkqRkGComyd5+L')
        echo "set from = \"$gmail\"" > $HOME/.muttrc
        echo "set realname = \"Wanli Zhu from Linux Terminal\"" >> $HOME/.muttrc
        echo "" >> $HOME/.muttrc
        echo "# IMAP (for receiving emails)" >> $HOME/.muttrc
        echo "set imap_user = \"$gmail\"" >> $HOME/.muttrc
        echo "set imap_pass = \"$gmailpass\"" >> $HOME/.muttrc
        echo "set folder = \"imaps://imap.gmail.com:993\"" >> $HOME/.muttrc
        echo "set spoolfile = \"+INBOX\"" >> $HOME/.muttrc
        echo "set postponed = \"+[Gmail]/Drafts\"" >> $HOME/.muttrc
        echo "" >> $HOME/.muttrc
        echo "# SMTP (for sending emails)" >> $HOME/.muttrc
        echo "set smtp_url = \"smtps://$gmail@smtp.gmail.com:465/\"" >> $HOME/.muttrc
        echo "set smtp_pass = \"$gmailpass\"" >> $HOME/.muttrc
    fi

    if [[ $1 == config ]]; then
        return 
    fi

    if [[ -z $recipient ]]; then
        read -p "Recipient: " recipient
    fi

    if [[ -z $subject ]]; then
        read -p "Subject: " subject
    fi

    if [[ ! -z $attachment ]]; then
        if [[ ! -e $attachment ]]; then
            echo "Attachment: $attachment, doesn't exist, ignore it"
            attachment=''
        fi
    fi

    if [[ -z $body ]]; then
        read -p "Body: " body 
    fi

    if [[ -z $attachment ]]; then
        echo "$body" | mutt -s "$subject" -- $recipient
    else
        echo "$body" | mutt -s "$subject" -a "$attachment" -- $recipient
    fi
}

function code-dev-drivers {
    code --folder-uri "vscode-remote://ssh-remote+wanliz-dev/home/wanliz/wanliz_p4sw_dev/dev/gpu_drv/bugfix_main/drivers"
}

function code-dev-drivers-opengl {
    code --folder-uri "vscode-remote://ssh-remote+wanliz-dev/home/wanliz/wanliz_p4sw_dev/dev/gpu_drv/bugfix_main/drivers/OpenGL"
}

function dmesg-nvidia {
    sudo dmesg | grep -i -E 'nvidia|nvrm|drm'
}

function show-gpu {
    if [[ ! -z $(which nvidia-smi) ]]; then
        nvidia-smi -q | grep -i "Product Name"
        nvidia-smi -L 
    fi
    lspci | grep -i nvidia | grep -v "Audio device"
    sudo lshw -C display | grep -i product
}

function screenshot {
    if [[ -z $(which sshpass) ]]; then
        sudo apt install -y sshpass
    fi

    if [[ -z $(which scrot) ]]; then
        sudo apt install -y scrot
    fi

    if [[ ! -d $HOME/Pictures ]]; then
        mkdir -p $HOME/Pictures
    fi

    img=$(date +%Y%m%d_%H%M%S).png
    scrot $HOME/Pictures/$img || return -1

    if [[ ! -z $1 ]]; then
        if [[ ! -f /tmp/$1.macos ]]; then
            read -e -i "no" -p "Is $1 hosted on macOS? (yes/no): " ans
            if [[ $ans == yes ]]; then
                touch /tmp/$1.macos
            fi
        fi

        read -e -i "$USER" -p "Username on $1: " user
        read -p "Password of $user on $1: " passwd
        export SSHPASS=$passwd

        if [[ -f /tmp/$1.macos ]]; then
            hometop=/Users
        else
            hometop=/home
        fi

        if [[ -z $SSHPASS ]]; then
            scp $HOME/Pictures/$img $user@$1:$hometop/$user/Pictures
        else
            sshpass -e scp $HOME/Pictures/$img $user@$1:$hometop/$user/Pictures
        fi
    fi
}

function record-screen {
    if [[ -z $(which ffmpeg) ]]; then
        sudo apt install -y ffmpeg
    fi

    read -e -i "$HOME/Videos/$(date +%Y%m%d_%H%M%S).mp4" -p "Save to file: " filename
    mkdir -p $(dirname $filename)

    ffmpeg -video_size $(xdpyinfo | grep dimensions | awk '{print $2}') -framerate 30 -f x11grab -i :0.0 -c:v libx264rgb -preset ultrafast -qp 0 -pix_fmt rgb24 $filename 
}

###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################
###########################################################

if [[ $1 == config ]]; then
    if [[ $2 == remote ]]; then
        read -e -i "local" -p "Remote host: " machine 
        read -e -i "$USER" -p "Run as user: " user
        scp $HOME/wanliz_workspace/test-env.sh $user@$machine:/tmp/test-env.sh
        ssh -t $user@$machine 'bash /tmp/test-env.sh config'
        echo "Configuration finished on $machine"
        return
    fi

    rm -rf /tmp/config.log 

    if [[ -z $DISPLAY ]]; then
        export DISPLAY=:0
    fi

    read -e -i "yes" -p "Update apt sources? (yes/no): " apt_update
    if [[ $apt_update == yes ]]; then
        sudo apt update
    fi

    install-if-not-yet vim htop vkcube:vulkan-tools ifconfig:net-tools unzip libglfw3:libglfw3-dev 
    install-any pkg-config gcc gcc-12 g++ libglvnd-dev 
    install-any build-essential gcc g++ cmake pkg-config libglvnd-dev 
    sudo apt install -y vulkan-tools

    if [[ -z $(dpkg -l | grep linux-tools-`uname -r`) ]]; then
        sudo apt install -y linux-tools-`uname -r` 
        sudo apt install -y linux-cloud-tools-`uname -r`
        sudo apt install -y linux-tools-generic linux-cloud-tools-generic
    fi

    if [[ -z $(sudo cat /etc/sudoers | grep "$USER ALL=(ALL) NOPASSWD:ALL") ]]; then
        echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null
        sudo cat /etc/sudoers | tail -1
        echo "- sudo with nopasswd  [OK]" >> /tmp/config.log
    fi

    if [[ ! -f ~/.gdbinit ]]; then
        echo "set debuginfod enabled on" > ~/.gdbinit
        echo "If env XDG_CACHE_HOME is empty, then ~/.cache/debuginfod_client is used instead."
        echo "- create ~/.gdbinit  [OK]" >> /tmp/config.log
    fi

    if [[ -z $(grep wanliz-test /etc/hosts) ]]; then
        echo "172.16.179.38 wanliz-test" | sudo tee -a /etc/hosts
        echo "- config wanliz-test in /etc/hosts  [OK]" >> /tmp/config.log
    fi

    if [[ -z $(grep wanliz-dev /etc/hosts) ]]; then
        echo "172.16.178.29 wanliz-dev" | sudo tee -a /etc/hosts
        echo "- config wanliz-dev in /etc/hosts  [OK]" >> /tmp/config.log
    fi

    if [[ ! -f /etc/apt/sources.list.d/ddebs.list ]]; then
        sudo mkdir -p /etc/apt/sources.list.d
        sudo tee /etc/apt/sources.list.d/ddebs.list << EOF
deb http://ddebs.ubuntu.com/ $(lsb_release -cs) main restricted universe multiverse
deb http://ddebs.ubuntu.com/ $(lsb_release -cs)-updates main restricted universe multiverse
deb http://ddebs.ubuntu.com/ $(lsb_release -cs)-security main restricted universe multiverse
EOF
        echo "- create /etc/apt/sources.list.d/ddebs.list  [OK]" >> /tmp/config.log
    fi

    if [[ -z $(dpkg -l | grep xserver-xorg-core-dbgsym) ]]; then
        read -e -i "yes" -p "Install debug symbol packages? (yes/no): " ans
        if [[ $ans == yes ]]; then
            sudo apt install ubuntu-dbgsym-keyring
            sudo apt update
            sudo apt install -y xserver-xorg-core-dbgsym
            sudo apt install -y libxcb1-dbgsym
            sudo apt install -y libxext6-dbgsym libxi6-dbgsym
            sudo apt install -y libxrender1-dbgsym
            sudo apt install -y x11-utils-dbgsym
        fi 
    fi 

    if [[ ! -d ~/.config/autostart ]]; then
        mkdir -p ~/.config/autostart
    fi

    if [[ -z $(which vkcube) ]]; then
        sudo apt install -y vulkan-tools
    fi

    if [[ -z $(which perf) ]]; then
        sudo apt install -y linux-tools-common linux-tools-generic
    fi

    if [[ -z $(which git) ]]; then
        sudo apt install -y git
        git config --global user.name "Wanli Zhu"
        git config --global user.email zhu.wanli@icloud.com
        git config --global pull.rebase false
        echo "- git config ...  [OK]" >> /tmp/config.log
    fi

    if ! ping -c2 linuxqa; then
        if [[ -f /usr/local/bin/vpn-with-sso.sh ]]; then
            read -e -i "yes" -p "Update /usr/local/bin/vpn-with-sso.sh? (yes/no): " ans
            if [[ $ans == yes ]]; then
                sudo rm -rf /usr/local/bin/vpn-with-sso.sh
            fi
        fi
        if [[ ! -f /usr/local/bin/vpn-with-sso.sh ]]; then
            rm -rf /tmp/vpn-with-sso.sh
            sudo tee /tmp/vpn-with-sso.sh << EOF 
#!/bin/bash
if [[ -z \$(which openconnect) ]]; then
    sudo apt install -y openconnect
fi

if [[ -z \$(openconnect --version | head -1 | grep "v9") ]]; then
    pushd ~/Downloads
    if [[ -z \$(lsb_release -r | grep "22") ]]; then
        wget --no-check-certificate https://download.opensuse.org/repositories/home:/bluca:/openconnect/Ubuntu_22.04/amd64/openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb || exit -1
        sudo dpkg -i openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb
    elif [[ -z \$(lsb_release -r | grep "24") ]]; then
        wget --no-check-certificate https://download.opensuse.org/repositories/home:/bluca:/openconnect/Ubuntu_24.04/amd64/openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb || exit -1
        sudo dpkg -i openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb
    else
        echo "Download openconnect manually: https://software.opensuse.org//download.html?project=home%3Abluca%3Aopenconnect&package=openconnect"
        exit -1
    fi
    popd 
fi

eval \$(openconnect --useragent="AnyConnect-compatible OpenConnect VPN Agent" --external-browser firefox --authenticate ngvpn02.vpn.nvidia.com/SAML-EXT)
[ -n ["\$COOKIE"] ] && echo -n "\$COOKIE" | sudo openconnect --cookie-on-stdin \$CONNECT_URL --servercert \$FINGERPRINT --resolve \$RESOLVE 
EOF
            sudo mv /tmp/vpn-with-sso.sh /usr/local/bin/vpn-with-sso.sh
            sudo chown $USER /usr/local/bin/vpn-with-sso.sh
            chmod +x /usr/local/bin/vpn-with-sso.sh
        fi
    fi

    if [[ -z $(grep wanliz_workspace ~/.bashrc) ]]; then
        if [[ -d $HOME/wanliz_workspace ]]; then
            echo "" >> ~/.bashrc
            echo "[[ -f $HOME/wanliz_workspace/test-env.sh ]] && source $HOME/wanliz_workspace/test-env.sh" >> ~/.bashrc
            echo "- Source test-env.sh in ~/.bashrc  [OK]" >> /tmp/config.log
        fi
    fi

    read -e -i "yes" -p "Install nvidia SSL certificate? (yes/no): " ans
    if [[ $ans == yes ]]; then
        nvidia-install-ssl-certificate
    fi

    if [[ -z $(sudo systemctl status ssh | grep 'active (running)') ]]; then
        sudo apt install -y openssh-server
        sudo systemctl enable ssh
        sudo systemctl start ssh
        echo "- Install openssh-server  [OK]" >> /tmp/config.log
    fi

    read -e -i "yes" -p "Add vnc server as system service? (yes/no): " ans   
    if [[ $ans == yes ]]; then
        if [[ $XDG_SESSION_TYPE == tty ]]; then
            read -e -i "x11" -p "XDG session type: " XDG_SESSION_TYPE
        fi

        if [[ $XDG_SESSION_TYPE == x11 ]]; then
            if [[ -z $(sudo lsof -i :5900-5909) ]]; then
                if [[ $(systemctl is-active x11vnc) == active ]]; then
                    echo "x11vnc.service is already running"
                else 
                    if [[ -z $(command -v x11vnc) ]]; then
                        sudo apt install -y x11vnc
                    fi

                    if [[ ! -f $HOME/.vnc/passwd ]]; then
                        x11vnc -storepasswd
                    fi

                    if [[ ! -f /etc/systemd/system/x11vnc.service ]]; then
                        echo "[Unit]
Description=x11vnc server
After=display-manager.service

[Service]
Type=simple
User=$USER
ExecStart=$(command -v x11vnc) -display :0 -rfbport 5900 -auth guess -forever -loop -noxdamage -repeat -usepw
Restart=on-failure

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/x11vnc.service
                    fi

                    sudo systemctl daemon-reload 
                    sudo systemctl enable x11vnc.service
                    sudo systemctl start  x11vnc.service
                    echo "- Register x11vnc as service  [OK]" >> /tmp/config.log
                fi
            fi
        elif [[ $XDG_SESSION_TYPE == wayland ]]; then
            if [[ -z $(sudo lsof -i :3389) ]]; then
                install-any gnome-remote-desktop xdg-desktop-portal xdg-desktop-portal-gnome
                gsettings set org.gnome.desktop.remote-desktop.rdp enable true
                gsettings set org.gnome.desktop.remote-desktop.rdp.authentication-method 'password'
                echo -n "zhujie" | base64 | gsettings set org.gnome.desktop.remote-desktop.rdp.password-hash
                gsettings set org.gnome.desktop.remote-desktop.rdp.enable-remote-control true
                sudo ufw disable
                systemctl --user enable gnome-remote-desktop
                systemctl --user start gnome-remote-desktop
                sleep 1

                if [[ ! -z $(ip -br a | grep 3389) ]]; then
                    echo "- Share wayland display  [OK]" >> /tmp/config.log
                else
                    echo "- Share wayland display  [FAILED]" >> /tmp/config.log
                fi
            fi
        else
            echo "- Share $XDG_SESSION_TYPE display  [SKIPPED]" >> /tmp/config.log 
        fi
    fi # End of "add vnc server as system service"

    if [[ -z $(which p4) ]]; then
        read -e -i "yes" -p "Install p4 command? (yes/no): " ans
        if [[ $ans == yes ]]; then
            sudo apt install -y helix-p4d || {
                if [[ $(lsb_release -i | cut -f2) == Ubuntu ]]; then
                    pushd ~/Downloads 
                    codename=$(lsb_release -c | cut -f2)
                    wget https://package.perforce.com/perforce.pubkey
                    gpg -n --import --import-options import-show perforce.pubkey
                    wget -qO - https://package.perforce.com/perforce.pubkey | sudo apt-key add -
                    #echo "deb http://package.perforce.com/apt/ubuntu $codename release" | sudo tee /etc/apt/sources.list.d/perforce.list
                    echo "deb http://package.perforce.com/apt/ubuntu noble release" | sudo tee /etc/apt/sources.list.d/perforce.list
                    sudo apt update 
                    sudo apt install -y helix-p4d
                    popd 
                fi
            }
            if [[ ! -z $(which p4) ]]; then
                echo "- Install p4 command  [OK]" >> /tmp/config.log
            else
                echo "- Install p4 command  [FAILED]" >> /tmp/config.log
            fi
        fi
    fi

    if [[ -z $(which p4v) ]]; then
        read -e -i "yes" -p "Install p4v command? (yes/no): " ans
        if [[ $ans == yes ]]; then
            pushd ~/Downloads
            wget https://www.perforce.com/downloads/perforce/r24.4/bin.linux26x86_64/p4v.tgz
            tar -zxvf p4v.tgz 
            sudo cp -R p4v-2024.4.*/bin/* /usr/local/bin
            sudo cp -R p4v-2024.4.*/lib/* /usr/local/lib 
            popd

            sudo apt install -y libxcb-cursor0

            [[ ! -z $(which p4v) ]] && 
            echo "- Install p4v command  [OK]" >> /tmp/config.log ||
            echo "- Install p4v command  [FAILED]" >> /tmp/config.log 
        fi 
    fi

    if [[ -f $HOME/.p4ignore ]]; then
        cat $HOME/.p4ignore
    else
        echo -e "_out\n.git\n.vscode\n" > $HOME/.p4ignore
        cat $HOME/.p4ignore
    fi

    if [[ -z $(which gtlfs) ]]; then
        sudo wget --no-check-certificate -O /usr/local/bin/gtlfs https://gtlfs.nvidia.com/client/linux && {
            sudo chmod +x /usr/local/bin/gtlfs
            echo "- Install gtlfs  [OK]" >> /tmp/config.log
        } || echo "- Install gtlfs  [FAILED]" >> /tmp/config.log
    fi

    ubuntu=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    if dpkg --compare-versions "$ubuntu" ge "24.0"; then
        if [[ ! -f /etc/sysctl.d/99-userns.conf ]]; then
            echo "kernel.apparmor_restrict_unprivileged_userns = 0" | sudo tee /etc/sysctl.d/99-userns.conf
            sudo sysctl --system
            echo "- Set kernel.apparmor_restrict_unprivileged_userns=0 for unix-build  [OK]" >> /tmp/config.log
        fi
    fi

    if [[ -z $(which code) ]]; then
        read -e -i "yes" -p "Install Visual Studio Code? (yes/no): " ans
        if [[ $ans == yes ]]; then
            pushd ~/Downloads 
            sudo apt install -y software-properties-common apt-transport-https wget
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
            sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
            sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
            sudo apt update
            sudo apt install -y code 
            popd 
        fi 
    fi

    if [[ -z $(which slack) ]]; then
        read -e -i "yes" -p "Install Slack? (yes/no): " ans
        if [[ $ans == yes ]]; then
            sudo snap install slack --classic
        fi 
    fi

    if [[ ! -f ~/.local/share/fonts/VerilySerifMono.otf ]]; then
        read -e -i "yes" -p "Install new font: VerilySerifMono.otf? (yes/no): " ans
        if [[ $ans == yes ]]; then
            mkdir -p ~/.local/share/fonts
            if [[ -f ~/wanliz_workspace/resources/VerilySerifMono.otf ]]; then
                cp ~/wanliz_workspace/resources/VerilySerifMono.otf ~/.local/share/fonts
            else
                pushd ~/Downloads 
                wget -O verily_serif_mono.zip https://dl.dafont.com/dl/?f=verily_serif_mono &&
                unzip verily_serif_mono.zip && 
                cp verily_serif_mono/VerilySerifMono.otf ~/.local/share/fonts
                popd 
            fi
            fc-cache -f -v &&
            echo "- Install font VerilySerifMono  [OK]" >> /tmp/config.log ||
            echo "- Install font VerilySerifMono  [FAILED]" >> /tmp/config.log
        fi 
    fi

    read -e -i "yes" -p "Configure default profile in Terminal? (yes/no): " ans
    if [[ $ans == yes ]]; then
        PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
        FONT_NAME=$(gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ font)
        if [[ $FONT_NAME != 'VerilySerifMono 14' && -f ~/.local/share/fonts/VerilySerifMono.otf ]]; then
            PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
            gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ use-system-font false
            gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ font 'VerilySerifMono 14'
            gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ background-color '#ffffff'
            gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ foreground-color '#171421'
            gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ default-size-columns 100
            gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ default-size-rows 30
        fi
    fi 

    if [[ ! -f ~/.muttrc ]]; then
        read -e -i "yes" -p "Configure Email sending profile? (yes/no): " ans
        if [[ $ans == yes ]]; then
            send-email config 
        fi
    fi

    read -e -i "yes" -p "Register autostart scripts? (yes/no): " ans
    if [[ $ans == yes ]]; then
        if [[ -f /usr/local/bin/autostart-xhost.sh ]]; then
            read -e -i "yes" -p "Update existing autostart-xhost.sh? (yes/no): " ans
            if [[ $ans == yes ]]; then
                sudo rm -rf /usr/local/bin/autostart-xhost.sh
            fi
        fi
        if [[ ! -f /usr/local/bin/autostart-xhost.sh ]]; then
            echo 'sleep 30' > /tmp/autostart-xhost.sh 
            echo 'export DISPLAY=:0' >> /tmp/autostart-xhost.sh
            echo "export XAUTHORITY=$HOME/.Xauthority" >> /tmp/autostart-xhost.sh
            echo 'xhost + >/tmp/xhost.log 2>&1' >> /tmp/autostart-xhost.sh
            sudo mv /tmp/autostart-xhost.sh /usr/local/bin/autostart-xhost.sh
            sudo chown $USER /usr/local/bin/autostart-xhost.sh
            sudo chmod +x /usr/local/bin/autostart-xhost.sh
            echo "- Create /usr/local/bin/autostart-xhost.sh  [OK]" >> /tmp/config.log
        fi

        if [[ -f /usr/local/bin/autostart-reportIP.sh ]]; then
            read -e -i "yes" -p "Update existing autostart-reportIP.sh? (yes/no): " ans
            if [[ $ans == yes ]]; then
                sudo rm -rf /usr/local/bin/autostart-reportIP.sh
            fi
        fi
        if [[ ! -f /usr/local/bin/autostart-reportIP.sh ]]; then
            echo "Decode automation email recipient:"
            recipient=$(decrypt 'U2FsdGVkX197SenegVS26FX0eZ0iUzMLnb0yqa7IIZCDHwK8flnDoWxzj+wzkG20')
            echo "sleep 30" > /tmp/autostart-reportIP.sh
            echo "rm -rf /tmp/reportIP.log" >> /tmp/autostart-reportIP.sh 
            echo "ip addr | grep inet > /tmp/reportIP.info" >> /tmp/autostart-reportIP.sh
            echo "if cmp -s ~/.reportIP.info /tmp/reportIP.info; then" >> /tmp/autostart-reportIP.sh
            echo "    exit" >> /tmp/autostart-reportIP.sh
            echo "fi" >> /tmp/autostart-reportIP.sh
            echo "echo \"\$(ip addr)\" | mutt -s \"IP Address of $(hostname)\" -- $recipient >> /tmp/reportIP.log 2>&1" >> /tmp/autostart-reportIP.sh
            echo "if [ \$? -eq 0 ]; then" >> /tmp/autostart-reportIP.sh
            echo "    cp -f /tmp/reportIP.info ~/.reportIP.info" >> /tmp/autostart-reportIP.sh
            echo "fi" >> /tmp/autostart-reportIP.sh
            echo "" >> /tmp/autostart-reportIP.sh
            sudo mv /tmp/autostart-reportIP.sh /usr/local/bin/autostart-reportIP.sh
            sudo chown $USER /usr/local/bin/autostart-reportIP.sh
            sudo chmod +x /usr/local/bin/autostart-reportIP.sh
            echo "- Create /usr/local/bin/autostart-reportIP.sh  [OK]" >> /tmp/config.log
        fi

        for command in /usr/local/bin/autostart-xhost.sh /usr/local/bin/autostart-reportIP.sh; do
            newjob="@reboot $command"
            if crontab -l 2>/dev/null | grep -Fq "$newjob"; then
                echo "$newjob - already exists" >/dev/null
            else
                (crontab -l 2>/dev/null; echo "$newjob") | crontab -
                echo "- Add $command to crontab  [OK]" | tee -a /tmp/config.log
            fi
        done
    fi # End of "add autostart tasks"

    # TODO - show grub menu

    ip -br a
    mokutil --sb-state 
    cat /tmp/config.log && {
        echo "Things to do post config: "
        echo "    - Install nvidia driver"
        echo "    - install viewperf (if needed)"
        echo "    - Install Nsight graphics/systems"
        echo "    - Install PIC-X"
    } || echo "Nothing to configure!"

    source ~/.bashrc
fi # End of config 
