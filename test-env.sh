if   [[ $HOSTNAME == wanliz-dev  ]]; then
    export P4CLIENT=wanliz-p4sw-dev
fi
if [[ -z $DISPLAY ]]; then
    export DISPLAY=:0
fi  
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

function chd {
    case $1 in
        gl|opengl|glcore) cd $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL ;;
        glx) cd $P4ROOT/dev/gpu_drv/bugfix_main/OpenGL/win/glx ;;
        egl) cd $P4ROOT/dev/gpu_drv/bugfix_main/OpenGL/win/egl/build ;;
        *) cd $P4ROOT/dev/gpu_drv/bugfix_main ;;
    esac
}

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

function nvsrc-version {
    grep '^#define NV_VERSION_STRING' $P4ROOT/dev/gpu_drv/bugfix_main/drivers/common/inc/nvUnixVersion.h  | awk '{print $3}' | sed 's/"//g'
}

function nvmod-version {
    modinfo nvidia | grep ^version | awk '{print $2}'
}

function nvmod-build-type {
    if [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "debug build") ]]; then
        echo debug
    elif [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "develop build") ]]; then
        echo develop
    else
        echo release
    fi
}

function nvidia-version {
    echo "Nvidia MOD ($(nvmod-build-type) build) version: $(nvmod-version)" 
    echo "Nvidia SRC ($P4CLIENT) version: $(nvsrc-version)"
}

function nvmake-unix {
    if [[ -z $1 ]]; then
        if [[ $(basename $(pwd)) == bugfix_main ]]; then
            default_args="drivers dist linux amd64 $(nvmod-build-type) -j$(nproc)"
        else
            default_args="linux amd64 $(nvmod-build-type) -j$(nproc)"
        fi
        echo "Auto-generated nvmake arguments: $default_args"
        read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
    else
        default_args=""
    fi

    $P4ROOT/misc/linux/unix-build \
        --tools $P4ROOT/tools \
        --devrel $P4ROOT/devrel/SDK/inc/GL \
        --unshare-namespaces \
        nvmake \
        NV_COLOR_OUTPUT=1 \
        NV_COMPRESS_THREADS=$(nproc) \
        NV_FAST_PACKAGE_COMPRESSION=1 \
        NV_KEEP_UNSTRIPPED_BINARIES=0 \
        NV_GUARDWORD=0 $default_args $@ 
}

function nvmake-ppp {
    config=${1:-release}
    nvmake-unix drivers dist linux amd64 $config -j$(nproc) &&
    nvmake-unix drivers dist linux x86   $config -j$(nproc) &&
    nvmake-unix drivers dist linux amd64 $config post-process-packages &&
    stat $P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_$config/NVIDIA-Linux-x86_64-$(nvsrc-version).run
}

function install-driver {
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
    elif [[ $1 =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Available build types for $1: release, debug and develop"
        read -e -i "release" -p "Build type: " buildtype
        pushd ~/Downloads 
        if [[ $buildtype == release ]]; then
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1.run http://linuxqa/builds/release/display/x86_64/$1/NVIDIA-Linux-x86_64-$1.run || return -1
            install-driver $HOME/Downloads/NVIDIA-Linux-x86_64-$1.run
        elif [[ $buildtype == debug ]]; then
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1-debug.run http://linuxqa/builds/release/display/x86_64/debug/$1/NVIDIA-Linux-x86_64-$1.run || return -1 
            install-driver $HOME/Downloads/NVIDIA-Linux-x86_64-$1-debug.run
        elif [[ $buildtype == develop ]]; then
            wget --no-check-certificate -O NVIDIA-Linux-x86_64-$1-develop.run http://linuxqa/builds/release/display/x86_64/develop/$1/NVIDIA-Linux-x86_64-$1.run || return -1 
            install-driver $HOME/Downloads/NVIDIA-Linux-x86_64-$1-develop.run
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
        if [[ -f  $outdir/NVIDIA-Linux-x86_64-$(nvsrc-version).run ]]; then
            echo "32-bits compatible packages are available"
            read -e -i "yes" -p "Install PPP (amd64 + x86) driver? (yes/no): " ans
            if [[ $ans == yes ]]; then
                install-driver $outdir/NVIDIA-Linux-x86_64-$(nvsrc-version).run
            else
                install-driver $outdir/NVIDIA-Linux-x86_64-$(nvsrc-version)-internal.run
            fi
        else
            install-driver $outdir/NVIDIA-Linux-x86_64-$(nvsrc-version)-internal.run
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
            install-driver $(cat /tmp/$idx)
        fi
    else 
        if [[ $XDG_SESSION_TYPE != tty ]]; then
            echo "Please run through a tty or ssh session"
            return -1
        fi

        read -e -i "no" -p "Install dependencies? (yes/no): " ans
        if [[ $ans == yes ]]; then
            apt_install_any pkg-config gcc gcc-12 g++ libglvnd-dev  
        fi

        # TODO - gcc-12
        # Disable nouveau
        if [[ ! -z $(lsmod | grep nouveau) ]]; then
            if [[ -z $(grep -r "nouveau" /etc/modprobe.d/) ]]; then
                read -e -i "ignore" -p "Nouveau has loaded, disable or ignore it? (disable/ignore): " ans
                if [[ $ans == disable ]]; then
                    echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
                    echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
                    sudo update-initramfs -u
                    echo "Nouveau is disabled since next boot"
                    echo "Reboot and try again"
                    return -1
                fi
            fi
        fi

        driver=$(realpath $1)
        echo "NVIDIA driver: $driver"
        read -p "Press [ENTER] to continue: " _
        sudo systemctl isolate multi-user
        
        read -e -i "no" -p "Uninstall existing NVIDIA driver? (yes/no): " ans
        if [[ $ans == yes ]]; then
            sudo nvidia-uninstall 
            sudo apt remove -y --purge '^nvidia-.*'
            sudo apt autoremove -y
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

function deploy-dso-glcore {
    version=$(nvmod-version)
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
            config=$(nvmod-build-type)
            echo "Copy OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so ($(nvsrc-version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-glcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version $HOME/libnvidia-glcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        fi
    fi
}

function deploy-dso-eglcore {
    version=$(nvmod-version)
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
            config=$(nvmod-build-type)
            echo "Copy OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so ($(nvsrc-version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-eglcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version $HOME/libnvidia-eglcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version
        fi
    fi
}

function deploy-dso-glx {
    version=$(nvmod-version)
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
            config=$(nvmod-build-type)
            echo "Copy OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so ($(nvsrc-version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libGLX_nvidia.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version $HOME/libGLX_nvidia.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version
        fi
    fi
}

function deploy-dso-xorg {
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
            config=$(nvmod-build-type)
            echo "Copy xfree86/4.0/nvidia/_out/Linux_amd64_$config/nvidia_drv.so ($(nvsrc-version)) to /lib/xorg/modules/drivers/nvidia_drv.so"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/nvidia_drv.so.backup ]]; then
                sudo cp -v /lib/xorg/modules/drivers/nvidia_drv.so $HOME/nvidia_drv.so.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/xfree86/4.0/nvidia/_out/Linux_amd64_$config/nvidia_drv.so /lib/xorg/modules/drivers/nvidia_drv.so
        fi
    fi
}

function shaderhelp {
    echo "export __GL_c5e9d7a4=0x4574563 -> dump ogl shaders"
    echo "export __GL_c5e9d7a4=0x6839369 -> replace ogl shaders"
}

function prime {
    if [[ $XDG_SESSION_TYPE == wayland ]]; then
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

function flamegraph {
    if [[ ! -f ~/Flamegraph/flamegraph.pl ]]; then
        git clone --depth 1 https://github.com/brendangregg/FlameGraph.git $HOME/Flamegraph || return -1
        sudo apt install -y python3-pip
        sudo apt install -y graphviz
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
    $P4ROOT/automation/dvs/dvsbuild/dvsbuild.pl -c $1 
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

function start-plain-x {
    if [[ $XDG_SESSION_TYPE != tty ]]; then
        echo "Please run through a tty or ssh session"
        return 
    fi
    
    read -e -i "yes" -p "Disable DPMS? (yes/no): " ans
    if [[ $ans == yes ]]; then
        xset -dpms
        xset s off
        if [[ -z $(grep '"DPMS" "false"' /etc/X11/xorg.conf) ]]; then
            sudo sed -i 's/"DPMS"/"DPMS" "false"/g' /etc/X11/xorg.conf
        fi
    fi

    if [[ -z $(grep anybody /etc/X11/Xwrapper.config) ]]; then
        sudo sed -i 's/console/anybody/g' /etc/X11/Xwrapper.config
    fi

    if [[ -z $(grep 'needs_root_rights=no' /etc/X11/Xwrapper.config) ]]; then
        echo -e '\nneeds_root_rights=yes' | sudo tee -a /etc/X11/Xwrapper.config >/dev/null
    fi

    if [[ ! -z $(pidof Xorg) ]]; then
        pkill Xorg
    fi
    
    sudo systemctl stop gdm
    X :0 
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
        apt_install_any libxcb-xinerama0 libxcb-xinput0
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
    tar -zxvf NVIDIA_Nsight_Graphics_*-internal.tar.gz
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
    echo "Installed Nvidia MOD version is $(nvmod-version)"
    read -e -i "$(nvmod-version | cut -d'.' -f1)" -p "Pull dvs source at version: " version

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

    echo "Encrypting a string of ${#txt} bytes"
    read -s -p "Password: " password
    echo 
    echo "$txt" | openssl enc -aes-256-cbc -a -salt -pass pass:"$password" -pbkdf2
}

function decrypt {
    if [[ -z $1 ]]; then
        read -p "Encrypted: " txt
    else
        txt="$1"
    fi

    echo "Decrypting a string of ${#txt} bytes"
    read -s -p "Password: " password
    echo "$txt" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"$password" -pbkdf2
}

function send-email {
    if [[ -z $(which mutt) ]]; then
        sudo apt install -y mutt 
    fi

    if [[ ! -f $HOME/.muttrc ]]; then
        gmail=$(decrypt 'U2FsdGVkX1/ftnBAbmGmt6BVRc7gdD2aU8UN0EaEVb4yoVjPGvKQGMvon40nkMXf')
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
        echo "export DISPLAY=:0"
    fi

    if [[ -z $(sudo cat /etc/sudoers | grep "$USER ALL=(ALL) NOPASSWD:ALL") ]]; then
        echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null
        sudo cat /etc/sudoers | tail -1
        echo "- sudo with nopasswd  [OK]" >> /tmp/config.log
    fi

    read -e -i "yes" -p "Update apt sources? (yes/no): " apt_update
    if [[ $apt_update == yes ]]; then
        sudo apt update
    fi

    if [[ -z $(which vkcube) ]]; then
        sudo apt install -y vulkan-tools
    fi

    if ! vkcube --c 10; then
        read -p 'Run command `xhost +x` on test machine, then press [ENTER] to continue: ' _
    fi

    install-if-not-yet vim htop vkcube:vulkan-tools ifconfig:net-tools unzip libglfw3:libglfw3-dev 

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

    if [[ ! -d $HOME/wanliz_workspace ]]; then
        if ! ping -c2 linuxqa; then
            if [[ ! -f /usr/local/bin/vpn-with-sso.sh ]]; then
                echo 'read -e -i "yes" -p "Connect to NVIDIA VPN with SSO? (yes/no): " ans
if [[ $ans == yes ]]; then
    if [[ -z $(which openconnect) ]]; then
        sudo apt install -y openconnect
    fi
    read -e -i "firefox" -p "Complete authentication in browser: " browser
    read -e -i "no" -p "Run in background? (yes/no): " runinbg
    eval $(openconnect --useragent="AnyConnect-compatible OpenConnect VPN Agent" --external-browser $(which $browser) --authenticate ngvpn02.vpn.nvidia.com/SAML-EXT)
    [ -n ["$COOKIE"] ] && echo -n "$COOKIE" | sudo openconnect --cookie-on-stdin $CONNECT_URL --servercert $FINGERPRINT --resolve $RESOLVE 
fi' > /tmp/vpn-with-sso.sh
                sudo mv /tmp/vpn-with-sso.sh /usr/local/bin/vpn-with-sso.sh
                sudo chown $USER /usr/local/bin/vpn-with-sso.sh
                chmod +x /usr/local/bin/vpn-with-sso.sh
            fi
            read -p "Run command /usr/local/bin/vpn-with-sso.sh, then press [ENTER] to continue: " _
        fi
        
        git clone https://wanliz:glpat-HDR4kyQBbsRxwBEBZtz7@gitlab-master.nvidia.com/wanliz/wanliz_workspace $HOME/wanliz_workspace
        apt_install_any build-essential gcc g++ cmake pkg-config libglvnd-dev 
        
        if [[ -d $HOME/wanliz_workspace ]]; then
            echo "- Clone wanliz_workspace  [OK]" >> /tmp/config.log
        else
            echo "- Clone wanliz_workspace  [FAILED]" >> /tmp/config.log
        fi
    fi

    if [[ ! -f /usr/local/bin/report-ip.sh ]]; then
        echo 'ip addr > /tmp/ip-addr
if [[ -f ~/.last-reported-ip-addr ]]; then
    if cmp -s /tmp/ip-addr ~/.last-reported-ip-addr; then
        echo "[$(date)] IP has not changed since last report" 
        exit
    fi 
fi

source ~/wanliz_workspace/test-env.sh || {
    echo "~/wanliz_workspace/test-env.sh does not exist" 
    exit -1
}

' > /tmp/report-ip.sh
        echo "recipient=$(decrypt 'U2FsdGVkX197SenegVS26FX0eZ0iUzMLnb0yqa7IIZCDHwK8flnDoWxzj+wzkG20') subject=\"IP Address of $(hostname)\" body=\"$(ip addr)\" send-email && cp -f /tmp/ip-addr ~/.last-reported-ip-addr || echo 'Failed to send email'" >> /tmp/report-ip.sh
        sudo mv /tmp/report-ip.sh /usr/local/bin/report-ip.sh
        sudo chown $USER /usr/local/bin/report-ip.sh
        sudo chmod +x /usr/local/bin/report-ip.sh
    fi

    if [[ -z $(grep wanliz_workspace ~/.bashrc) ]]; then
        if [[ -d $HOME/wanliz_workspace ]]; then
            echo "" >> ~/.bashrc
            echo "source $HOME/wanliz_workspace/test-env.sh" >> ~/.bashrc
            echo "- Source test-env.sh in ~/.bashrc  [OK]" >> /tmp/config.log
        fi
    fi

    if [[ -z $(sudo systemctl status ssh | grep 'active (running)') ]]; then
        sudo apt install -y openssh-server
        sudo systemctl enable ssh
        sudo systemctl start ssh
        echo "- Install openssh-server  [OK]" >> /tmp/config.log
    fi

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
            apt_install_any gnome-remote-desktop xdg-desktop-portal xdg-desktop-portal-gnome
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
        echo "- Share $XDG_SESSION_TYPE display  [FAILED]" >> /tmp/config.log 
    fi

    if [[ -z $(which p4) ]]; then
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

    if [[ -z $(which p4v) ]]; then
        pushd ~/Downloads
        wget https://www.perforce.com/downloads/perforce/r24.4/bin.linux26x86_64/p4v.tgz
        tar -zxvf p4v.tgz 
        sudo cp -R p4v-2024.4.2690487/bin/* /usr/local/bin
        sudo cp -R p4v-2024.4.2690487/lib/* /usr/local/lib 
        popd

        [[ ! -z $(which p4v) ]] && 
        echo "- Install p4v command  [OK]" >> /tmp/config.log ||
        echo "- Install p4v command  [FAILED]" >> /tmp/config.log 
    fi

    if [[ ! -f $HOME/.p4ignore ]]; then
        if [[ -f $HOME/.p4ignore ]]; then
            cat $HOME/.p4ignore
        else
            read -e -i "yes" -p "$HOME/.p4ignore doesn't exist, create with default value? (yes/no): " ans
            if [[ $ans == yes ]]; then
                echo -e "_out\n.git\n.vscode\n" > $HOME/.p4ignore
                cat $HOME/.p4ignore
            fi
        fi
        echo "- Create file ~/.p4ignore  [OK]" >> /tmp/config.log
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
        pushd ~/Downloads 
        sudo apt install -y software-properties-common apt-transport-https wget
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
        sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
        sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
        sudo apt update
        sudo apt install -y code && 
            echo "- Install VS Code  [OK]" >> /tmp/config.log ||
            echo "- Install VS Code  [FAILED]" >> /tmp/config.log 
        popd 
    fi

    if [[ -z $(which slack) ]]; then
        sudo snap install slack --classic
    fi

    if [[ ! -f ~/.local/share/fonts/VerilySerifMono.otf ]]; then
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

    PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
    FONT_NAME=$(gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ font)
    if [[ $FONT_NAME != 'VerilySerifMono 14' ]]; then
        PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
        gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ use-system-font false
        gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ font 'VerilySerifMono 14'
        gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ background-color '#ffffff'
        gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ foreground-color '#171421'
        gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ default-size-columns 100
        gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ default-size-rows 30
    fi

    read -e -i "yes" -p "Configure Email sending profile? (yes/no): " ans
    if [[ $ans == yes ]]; then
        send-email config 
    fi

    if [[ ! -f ~/.config/autostart/xhost.desktop ]]; then
        echo '[Desktop Entry]
Type=Application
Exec=bash -c "xhost + > /tmp/xhost.log"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=XHost Command
Comment=Disable access control' > /tmp/xhost.desktop
        sudo mv /tmp/xhost.desktop ~/.config/autostart/xhost.desktop
        echo "- Disable access control after GNOME startup  [OK]" >> /tmp/config.log
    fi

    if [[ ! -f ~/.config/autostart/report-ip.desktop ]]; then
        if [[ -f ~/.muttrc ]]; then
            echo '[Desktop Entry]
Type=Application
Exec=bash -c "/usr/local/bin/report-ip.sh > /tmp/report-ip.log"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Report IP through Email
Comment=Report IP through Email' > /tmp/report-ip.desktop
            sudo mv /tmp/report-ip.desktop ~/.config/autostart/report-ip.desktop
            echo "- Report IP through Email after GNOME startup  [OK]" >> /tmp/config.log
        fi
    fi

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
