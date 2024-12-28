if   [[ $HOSTNAME == scc-03-3062-dev  ]]; then
    export P4CLIENT=wanliz_p4sw_dev
elif [[ $HOSTNAME == scc-03-3062-test ]]; then
    export P4CLIENT=wanliz_p4sw_test
elif [[ $HOSTNAME == scc-03-3062-wfh  ]]; then
    export P4CLIENT=wanliz_p4sw_wfh
fi
if [[ -z $DISPLAY ]]; then
    export DISPLAY=:0
fi  
export P4ROOT=/home/wanliz/$P4CLIENT
export P4IGNORE=$HOME/.p4ignore
export P4PORT=p4proxy-sc.nvidia.com:2006
export P4USER=wanliz
export PATH=~/wanliz_workspace:$PATH
export PATH=~/wanliz_workspace/test_vp:$PATH
export PATH=~/wanliz_workspace/test_wayland:$PATH
export PATH=~/.local/bin:$PATH
export PATH=~/nsight_systems/bin:$PATH
export PATH=~/nvidia-nomad-internal/host/linux-desktop-nomad-x64:$PATH
export PATH=~/PIC-X_Package/SinglePassCapture:$PATH
export PATH=~/apitrace/bin:$PATH
export PATH=$HOME:$PATH
alias  ss="source ~/.bashrc"
alias  pp="pushd ~/wanliz_workspace >/dev/null && git pull && popd >/dev/null && source ~/.bashrc"
alias  uu="pushd ~/wanliz_workspace >/dev/null && git add . && git commit -m uu && git push && popd >/dev/null"

function check_and_install {
    if [[ -z $(which $1) ]]; then
        sudo apt install -y $2
    fi
}

function apt_install_any {
    rm -rf /tmp/apt_failed /tmp/aptitude_failed
    for pkg in "$@"; do 
        sudo apt install -y $pkg || echo "$pkg" >> /tmp/apt_failed
    done
    if [[ -f /tmp/apt_failed ]]; then
        echo "Failed to install $(wc -l /tmp/apt_failed) packages using apt: "
        cat /tmp/apt_failed
        
        read -e -i "yes" -p "Retry with aptitude? (yes/no): " ans
        if [[ $ans == yes ]]; then
            while IFS= read -r pkg; do 
                sudo aptitude install $pkg || echo "$pkg" >> /tmp/aptitude_failed
            done < /tmp/apt_failed 
            
            if [[ -f /tmp/aptitude_failed ]]; then
                echo "Failed to install $(wc -l /tmp/aptitude_failed) packages using aptitude: "
                cat /tmp/aptitude_failed
                return -1
            fi
        fi
    fi
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
    fi
}

function get_src_version {
    grep '^#define NV_VERSION_STRING' $P4ROOT/dev/gpu_drv/bugfix_main/drivers/common/inc/nvUnixVersion.h  | awk '{print $3}' | sed 's/"//g'
}

function get_mod_version {
    modinfo nvidia | grep ^version | awk '{print $2}'
}

function get_build_type {
    if [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "debug build") ]]; then
        echo debug
    elif [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "develop build") ]]; then
        echo develop
    else
        echo release
    fi
}

function check_version {
    echo "Installed dso ($(get_build_type) build) version: $(get_mod_version)" 
    echo "Source code ($P4CLIENT) version: $(get_src_version)"
}

function nvmake_unix {
    if [[ -z $1 ]]; then
        if [[ $(basename $(pwd)) == bugfix_main ]]; then
            default_args="drivers dist linux amd64 $(get_build_type) -j$(nproc)"
        else
            default_args="linux amd64 $(get_build_type) -j$(nproc)"
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

function nvmake_ppp {
    config=${1:-release}
    nvmake_unix drivers dist linux amd64 $config -j$(nproc) &&
    nvmake_unix drivers dist linux x86   $config -j$(nproc) &&
    nvmake_unix drivers dist linux amd64 $config post-process-packages &&
    stat $P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_$config/NVIDIA-Linux-x86_64-$(get_src_version).run
}

function install_driver {
    if [[ -z $1 ]]; then
        echo "Download by changelist : http://linuxqa.nvidia.com/dvsbuilds/gpu_drv_bugfix_main_Release_Linux_AMD64_unix-build_Test_Driver/?C=M;O=D"
        echo "                         http://linuxqa.nvidia.com/dvsbuilds/gpu_drv_bugfix_main_Debug_Linux_AMD64_unix-build_Driver/?C=M;O=D"
        echo "Download by version    : http://linuxqa/builds/release/display/x86_64/?C=M;O=D"
        echo "                         http://linuxqa/builds/release/display/x86_64/debug/?C=M;O=D"
        echo "                         http://linuxqa/builds/release/display/x86_64/develop/?C=M;O=D"
        echo "Download by date       : http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/?C=M;O=D"
        echo "                         http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/debug/?C=M;O=D"
        echo "                         http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/develop/?C=M;O=D"
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
        if [[ -f  $outdir/NVIDIA-Linux-x86_64-$(get_src_version).run ]]; then
            echo "32-bits compatible packages are available"
            read -e -i "yes" -p "Install PPP (amd64 + x86) driver? (yes/no): " ans
            if [[ $ans == yes ]]; then
                install_driver $outdir/NVIDIA-Linux-x86_64-$(get_src_version).run
            else
                install_driver $outdir/NVIDIA-Linux-x86_64-$(get_src_version)-internal.run
            fi
        else
            install_driver $outdir/NVIDIA-Linux-x86_64-$(get_src_version)-internal.run
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
            install_driver $(cat /tmp/$idx)
        fi
    else 
        if [[ $XDG_SESSION_TYPE != tty ]]; then
            echo "Please run through a tty or ssh session"
            return
        fi

        apt_install_any pkg-config gcc g++ libglvnd-dev

        driver=$(realpath $1)
        echo "NVIDIA driver: $driver"
        read -p "Press [ENTER] to continue: " _
        sudo systemctl isolate multi-user
        
        read -e -i "yes" -p "Uninstall existing NVIDIA driver? (yes/no): " ans
        if [[ $ans == yes ]]; then
            sudo nvidia-uninstall 
            sudo apt remove -y --purge '^nvidia-.*'
            sudo apt autoremove -y
        fi

	    chmod +x $driver 
        sudo $driver && 
        sudo systemctl isolate graphical ||
        echo "Failed to install NVIDIA driver"
    fi
}

function deploy_dso_glcore {
    version=$(get_mod_version)
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
            config=$(get_build_type)
            echo "Copy OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so ($(get_src_version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-glcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version $HOME/libnvidia-glcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        fi
    fi
}

function deploy_dso_eglcore {
    version=$(get_mod_version)
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
            config=$(get_build_type)
            echo "Copy OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so ($(get_src_version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-eglcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version $HOME/libnvidia-eglcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version
        fi
    fi
}

function deploy_dso_glx {
    version=$(get_mod_version)
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
            config=$(get_build_type)
            echo "Copy OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so ($(get_src_version)) to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libGLX_nvidia.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version $HOME/libGLX_nvidia.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version
        fi
    fi
}

function deploy_dso_xorg {
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
            config=$(get_build_type)
            echo "Copy xfree86/4.0/nvidia/_out/Linux_amd64_$config/nvidia_drv.so ($(get_src_version)) to /lib/xorg/modules/drivers/nvidia_drv.so"
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

function resize_display {
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

function change_p4client {
    export P4CLIENT=$1
    export P4ROOT=/home/wanliz/$P4CLIENT
}

function check_p4ignore {
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

function install_viewperf {
    pushd $HOME/Downloads >/dev/null
    wget http://linuxqa.nvidia.com/people/nvtest/pynv_files/viewperf2020v3/viewperf2020v3.tar.gz || exit -1
    tar -zxvf viewperf2020v3.tar.gz
    mv viewperf2020 $HOME
    popd >/dev/null
}

function start_plain_x {
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

function load_pic_env {
    pushd $HOME/PIC-X_Package/SinglePassCapture/Scripts >/dev/null
    source ./setup-symbollinks.sh 
    source ./setup-env.sh 
    popd >/dev/null 
}

function check_vnc {
    sudo lsof -i :5900-5909
}

function restart_vnc {
    sudo systemctl restart x11vnc.service
}

function uninstall_vnc {
    sudo systemctl stop x11vnc.service
    sudo systemctl disable x11vnc.service
    sudo rm -rf /etc/systemd/system/x11vnc.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}

function load_vksdk {
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

function install_nsys {
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

function install_ngfx {
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

function install_apitrace {
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

function sync_root_docs {
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

function listen_ports {
    sudo ss -tunlp
}

function sync_workspace {
    echo "[1] Sync from local to remote"
    echo "[2] Sync from remote to local"
    read -e -i "1" -p "Mode: " mode
    read -p "Remote host: " remote

    if [[ $mode == 1 ]]; then
        if [[ $(uname) == Darwin ]]; then
            rsync -avz /Users/wanliz/wanliz_workspace/ wanliz@$remote:/home/wanliz/wanliz_workspace
        else
            rsync -avz /home/wanliz/wanliz_workspace/ wanliz@$remote:/home/wanliz/wanliz_workspace
        fi
    else
        rsync -avz wanliz@$remote:/home/wanliz/wanliz_workspace/ /home/wanliz/wanliz_workspace
    fi 
}

function install_kernel {
    read -p "Linux kernel version: " version
    if [[ ! -z $(apt search linux-image-$version | grep -E "linux-image-$version-.*-generic") ]]; then
        apt search linux-image-$version | grep -E "linux-image-$version-.*-generic"
        read -p "Patch number: " patch
        sudo apt install -y linux-image-$version-$patch-generic 
        sudo apt install -y linux-modules-$version-$patch-generic
        sudo apt install -y linux-headers-$version-$patch-generic
    fi

    echo "List all available GRUB menu entries:"
    sudo grep 'menuentry ' /boot/grub/grub.cfg | cut -d "'" -f2 | nl -v0

    read -e -i "yes" -p "Configure grub? (yes/no): " config
    if [[ $config == yes ]]; then
        read -p "Kernel index: " index
        sudo sed -i "/^GRUB_DEFAULT=/c\GRUB_DEFAULT=\"1>$index\"" /etc/default/grub
        sudo update-grub
        echo "Ready to reboot now"
    fi
}