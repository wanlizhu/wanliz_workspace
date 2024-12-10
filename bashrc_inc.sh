if   [[ $HOSTNAME == scc-03-3062-dev  ]]; then
    export P4CLIENT=wanliz_p4sw_dev
elif [[ $HOSTNAME == scc-03-3062-test ]]; then
    export P4CLIENT=wanliz_p4sw_test
elif [[ $HOSTNAME == scc-03-3062-wfh  ]]; then
    export P4CLIENT=wanliz_p4sw_wfh
fi
export P4ROOT=/home/wanliz/$P4CLIENT
export P4IGNORE=$HOME/.p4ignore
export P4PORT=p4proxy-sc.nvidia.com:2006
export P4USER=wanliz
export PATH=~/wanliz_linux_workbench:$PATH
export PATH=~/wanliz_linux_workbench/test_vp:$PATH
export PATH=~/.local/bin:$PATH
export PATH=~/p4v/bin:$PATH
export PATH=~/nsight_systems/bin:$PATH
export PATH=~/nvidia-nomad-internal/host/linux-desktop-nomad-x64:$PATH
export PATH=~/PIC-X_Package/SinglePassCapture:$PATH
alias  ss="source ~/.bashrc"
alias  pp="pushd ~/wanliz_linux_workbench >/dev/null && git pull && popd >/dev/null && source ~/.bashrc"
alias  uu="pushd ~/wanliz_linux_workbench >/dev/null && git add . && git commit -m uu && git push && popd >/dev/null"


function nvcd {
    case $1 in
        gl|opengl|glcore) cd $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL ;;
        glx) cd $P4ROOT/dev/gpu_drv/bugfix_main/OpenGL/win/glx ;;
        egl) cd $P4ROOT/dev/gpu_drv/bugfix_main/OpenGL/win/egl/build ;;
        *) cd $P4ROOT/dev/gpu_drv/bugfix_main ;;
    esac
}

function nvsrcver {
    grep '^#define NV_VERSION_STRING' $P4ROOT/dev/gpu_drv/bugfix_main/drivers/common/inc/nvUnixVersion.h  | awk '{print $3}' | sed 's/"//g'
}

function nvsysver {
    modinfo nvidia | grep ^version | awk '{print $2}'
}

function nvbuildtype {
    if [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "debug build") ]]; then
        echo debug
    elif [[ ! -z $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}' | grep "develop build") ]]; then
        echo develop
    else
        echo release
    fi
}

function nvmk {
    if [[ -z $1 ]]; then
        if [[ $(basename $(pwd)) == bugfix_main ]]; then
            default_args="drivers dist linux amd64 $(nvbuildtype) -j$(nproc)"
        else
            default_args="linux amd64 $(nvbuildtype) -j$(nproc)"
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

function nvpkg {
    config=${1:-release}
    nvmk drivers dist linux amd64 $config -j$(nproc) &&
    nvmk drivers dist linux x86   $config -j$(nproc) &&
    nvmk drivers dist linux amd64 $config post-process-packages &&
    stat $P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_$config/NVIDIA-Linux-x86_64-$(nvsrcver).run
}

function nvins {
    if [[ -z $1 ]]; then
        echo "Download by date       : http://linuxqa/builds/daily/display/x86_64/dev/gpu_drv/bugfix_main/"
        echo "Download by version    : http://linuxqa/builds/release/display/x86_64/"
        echo "Download by changelist : http://linuxqa.nvidia.com/dvsbuilds/gpu_drv_bugfix_main_Release_Linux_AMD64_unix-build_Test_Driver/"
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
        if [[ -f  $outdir/NVIDIA-Linux-x86_64-$(nvsrcver).run ]]; then
            echo "32-bits compatible packages are available"
            read -e -i "yes" -p "Install PPP (amd64 + x86) driver? (yes/no): " ans
            if [[ $ans == yes ]]; then
                nvins $outdir/NVIDIA-Linux-x86_64-$(nvsrcver).run
            else
                nvins $outdir/NVIDIA-Linux-x86_64-$(nvsrcver)-internal.run
            fi
        else
            nvins $outdir/NVIDIA-Linux-x86_64-$(nvsrcver)-internal.run
        fi 
    else
        if [[ $XDG_SESSION_TYPE != tty ]]; then
            echo "Please run through a tty or ssh session"
            return
        fi

        sudo apt install -y  pkg-config gcc g++ libglvnd-dev

        driver=$(realpath $1)
        echo "NVIDIA driver: $driver"
        read -p "Press [ENTER] to continue: " _
        sudo systemctl isolate multi-user
        
        read -e -i "yes" -p "Uninstall existing NVIDIA driver? (yes/no): " ans
        if [[ $ans == yes ]]; then
            sudo nvidia-uninstall 
        fi

	    chmod +x $driver 
        sudo $driver && 
        sudo systemctl isolate graphical ||
        echo "Failed to install NVIDIA driver"
    fi
}

function nvcpglcore {
    version=$(nvsysver)
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
            config=$(nvbuildtype)
            echo "Copy OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-glcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version $HOME/libnvidia-glcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        fi
    fi
}

function nvcpglx {
    version=$(nvsysver)
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
            config=$(nvbuildtype)
            echo "Copy OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libGLX_nvidia.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version $HOME/libGLX_nvidia.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/glx/lib/_out/Linux_amd64_$config/libGLX_nvidia.so /lib/x86_64-linux-gnu/libGLX_nvidia.so.$version
        fi
    fi
}

function nvcpeglcore {
    version=$(nvsysver)
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
            config=$(nvbuildtype)
            echo "Copy OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so to /lib/x86_64-linux-gnu as *.so.$version"
            read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
            if [[ ! -f $HOME/libnvidia-eglcore.so.$version.backup ]]; then
                sudo cp -v /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version $HOME/libnvidia-eglcore.so.$version.backup
            fi
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/win/egl/build/_out/Linux_amd64_$config/libnvidia-eglcore.so /lib/x86_64-linux-gnu/libnvidia-eglcore.so.$version
        fi
    fi
}

function nvscp {
    read -p "Remote host: " host
    read -e -i $USER -p "Remote user: " user
    
    if [[ $1 == restore ]]; then
        ssh $user@$host "source ~/wanliz_linux_workbench/bashrc_inc.sh; nvcp restore"
    else
        config=$(nvbuildtype)
        scp $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so $user@$host:/tmp/libnvidia-glcore.so
        ssh $user@$host "source ~/wanliz_linux_workbench/bashrc_inc.sh; nvcp /tmp/libnvidia-glcore.so"
    fi
}

function nvshaderhelp {
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
        if [[ -z $(which pip) ]]; then
            sudo apt install -y python3-pip
            sudo apt install -y graphviz
        fi
        pip install gprof2dot 
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

function syncdir {
    if [[ $(pwd) != $HOME ]]; then
        echo "The current directory is not \$HOME"
        read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
    fi
    read -p "From: " from
    for dir in $@; do 
        dir=$(realpath $dir)
        rsync -avz wanliz@$from:$dir/ $dir || echo "Failed to sync $dir from $from" 
    done
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

function dumpmounts {
    mounted=$(cat /proc/mounts | grep '/mnt')
    while IFS= read -r mount; do
        source=$(echo "$mount" | awk '{print $1}')
        target=$(echo "$mount" | awk '{print $2}')
        fstype=$(echo "$mount" | awk '{print $3}')
        option=$(echo "$mount" | awk '{print $4}')
        echo "sudo mkdir -p $target &&"
        echo "sudo mount -t $fstype -o $option $source $target &&"
    done <<< "$mounted"
    echo "echo DONE"
}

function nvmount {
    sudo mkdir -p /mnt/data &&
    sudo mount -t nfs -o rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,soft,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.31.184.130,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.31.184.130 linuxqa:/qa/data /mnt/data &&
    sudo mkdir -p /mnt/nvtest &&
    sudo mount -t nfs -o rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,soft,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.31.184.102,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.31.184.102 nvtest:/nvtest/shared /mnt/nvtest &&
    sudo mkdir -p /mnt/builds &&
    sudo mount -t nfs -o rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,soft,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.31.184.130,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.31.184.130 linuxqa:/qa/builds /mnt/builds &&
    sudo mkdir -p /mnt/linuxqa &&
    sudo mount -t nfs -o rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,soft,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=10.31.184.130,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.31.184.130 linuxqa:/qa/people /mnt/linuxqa &&
    echo DONE
}

function resizedp {
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

function p4ins {
    sudo apt install -y helix-p4d || {
        if [[ $(lsb_release -i | cut -f2) == Ubuntu ]]; then
            wget -qO - https://package.perforce.com/perforce.pubkey | gpg --dearmor | sudo tee /usr/share/keyrings/perforce.gpg >/dev/null
            echo "deb [signed-by=/usr/share/keyrings/perforce.gpg] https://package.perforce.com/apt/ubuntu $(lsb_release -c | cut -f2) release" | sudo tee -a /etc/apt/sources.list
            sudo apt update
            sudo apt install -y helix-p4d
        fi
    }
}

function xdgst {
    echo $XDG_SESSION_TYPE
}

function p4switch {
    export P4CLIENT=$1
    export P4ROOT=/home/wanliz/$P4CLIENT
}

function p4ignore {
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

function vpins {
    pushd $HOME >/dev/null
    wget http://linuxqa.nvidia.com/people/nvtest/pynv_files/viewperf2020v3/viewperf2020v3.tar.gz || exit -1
    tar -zxvf viewperf2020v3.tar.gz
    popd >/dev/null
}

function plainx {
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
    
    sudo systemctl stop gdm
    X :0 &
    XPID=$!
    export DISPLAY=:0

    sleep 1
    if [[ -d /proc/$XPID ]]; then
        echo "X $XPID is running in the background"
        echo "DISPLAY $DISPLAY is active"
    fi
}

function picxenv {
    pushd $HOME/PIC-X_Package/SinglePassCapture/Scripts >/dev/null
    source ./setup-symbollinks.sh 
    source ./setup-env.sh 
    popd >/dev/null 
}

function synchosts {
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/[[:space:]]*$//')
        if ! grep -Fxq "$line" /etc/hosts; then
            host=$(echo "$line" | awk '{print $2}')
            sudo sed -i "/ $host$/d" /etc/hosts
            echo "$line" | sudo tee -a /etc/hosts 
        fi
    done < $HOME/wanliz_linux_workbench/hosts
}

function checkvnc {
    sudo lsof -i :5900-5909
}

function restartvnc {
    sudo systemctl restart x11vnc.service
}