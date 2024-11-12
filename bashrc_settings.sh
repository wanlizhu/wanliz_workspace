export P4CLIENT=wanliz_linux_gpudrv
export P4ROOT=/home/wanliz/$P4CLIENT
export P4IGNORE=$P4ROOT/.p4ignore
export P4PORT=p4proxy-sc.nvidia.com:2006
export P4USER=wanliz
export PATH=~/wanliz_linux_workbench:$PATH
export PATH=~/p4v/bin:$PATH
export PATH=~/nsight_systems/bin:$PATH
export PATH=~/nvidia-nomad-internal/host/linux-desktop-nomad-x64:$PATH
export PATH=~/PIC-X_Package/SinglePassCapture:$PATH
alias  nvcd="cd $P4ROOT/dev/gpu_drv/bugfix_main"
alias  ss="source ~/.bashrc"

function nvver {
    grep '^#define NV_VERSION_STRING' $P4ROOT/dev/gpu_drv/bugfix_main/drivers/common/inc/nvUnixVersion.h  | awk '{print $3}' | sed 's/"//g'
}

function nvmk {
    $P4ROOT/misc/linux/unix-build \
        --tools $P4ROOT/tools \
        --devrel $P4ROOT/devrel/SDK/inc/GL \
        --unshare-namespaces \
        nvmake \
        NV_COLOR_OUTPUT=1 \
        NV_COMPRESS_THREADS=$(nproc) \
        NV_FAST_PACKAGE_COMPRESSION=1 \
        NV_KEEP_UNSTRIPPED_BINARIES=0 \
        NV_GUARDWORD=0 $@
}

function nvpkg {
    config=${config:=release}
    nvmk drivers dist linux amd64 $config -j$(nproc) &&
    nvmk drivers dist linux x86   $config -j$(nproc) &&
    nvmk drivers dist linux amd64 $config post-process-packages &&
    stat $P4ROOT/dev/gpu_drv/bugfix_main/_out/Linux_amd64_release/NVIDIA-Linux-x86_64-$(nvver).run
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
        if [[ -f  $outdir/NVIDIA-Linux-x86_64-$(nvver).run ]]; then
            nvins $outdir/NVIDIA-Linux-x86_64-$(nvver).run
        else
            nvins $outdir/NVIDIA-Linux-x86_64-$(nvver)-internal.run
        fi 
    else
        echo "Install NVIDIA driver: $1"
        read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _

        sudo systemctl stop gdm
        sudo $(realpath $1) -sb && 
        sudo systemctl start gdm ||
        echo "Failed to install NVIDIA driver"
    fi
}

function nvcp {
    version=$(modinfo nvidia | grep ^version | awk '{print $2}')
    case $(cat /proc/driver/nvidia/version | awk '{print tolower($0)}') in
        debug)   config=debug ;;
        develop) config=develop ;;
        *)       config=release ;;
    esac 

    if [[ $1 == restore ]]; then
        sudo cp -v --remove-destination $HOME/libnvidia-glcore.so.$version.backup /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        sudo rm -v -f $HOME/libnvidia-glcore.so.$version.backup
    else
        if [[ ! -f $HOME/libnvidia-glcore.so.$version.backup ]]; then
            sudo cp -v /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version $HOME/libnvidia-glcore.so.$version.backup
        fi
        sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
    fi
}

function nvshaderhelp {
    echo "export __GL_c5e9d7a4=0x4574563 -> dump ogl shaders"
    echo "export __GL_c5e9d7a4=0x6839369 -> replace ogl shaders"
}

function prime {
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    "$@"
}

function perfhelp {
    echo 'sudo perf record -g --call-graph dwarf --freq=1000 --output=$(date +%H%M%S).perf.data -- "$@"'
}

function flamegraph {
    name=$(basename $1)
    sudo chmod 666 $1
    sudo perf script --no-inline --force --input=$1 -F +pid > $1.perthread && 
    sudo perf script --no-inline --force --input=$1 >/tmp/$name.stage1 && 
    sudo ~/Flamegraph/stackcollapse-perf.pl /tmp/$name.stage1 >/tmp/$name.stage2 && 
    sudo ~/Flamegraph/stackcollapse-recursive.pl /tmp/$name.stage2 >/tmp/$name.stage3 && 
    sudo ~/Flamegraph/flamegraph.pl /tmp/$name.stage3 >$1.perf.svg && 
    echo "Generated $1.perf.svg" ||
    echo "Failed to generate flamegraph svg" 
}

function syncdir {
    read -p "From: " from
    for dir in $@; do 
        dir=$(realpath $dir)
        rsync -avz wanliz@$from:$dir/ $dir || echo "Failed to sync $dir from $from" 
    done
}