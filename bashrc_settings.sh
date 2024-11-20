export P4CLIENT=wanliz_linux_gpudrv
export P4ROOT=/home/wanliz/$P4CLIENT
export P4IGNORE=$P4ROOT/.p4ignore
export P4PORT=p4proxy-sc.nvidia.com:2006
export P4USER=wanliz
export PATH=~/wanliz_linux_workbench:$PATH
export PATH=~/wanliz_linux_workbench/test_vp:$PATH
export PATH=~/p4v/bin:$PATH
export PATH=~/nsight_systems/bin:$PATH
export PATH=~/nvidia-nomad-internal/host/linux-desktop-nomad-x64:$PATH
export PATH=~/PIC-X_Package/SinglePassCapture:$PATH
alias  nvcd="cd $P4ROOT/dev/gpu_drv/bugfix_main"
alias  ss="source ~/.bashrc"
alias  pp="pushd ~/wanliz_linux_workbench >/dev/null && git pull && popd >/dev/null"

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
            nvins $outdir/NVIDIA-Linux-x86_64-$(nvsrcver).run
        else
            nvins $outdir/NVIDIA-Linux-x86_64-$(nvsrcver)-internal.run
        fi 
    else
        echo "NVIDIA driver: $1"
        read -p "Press [ENTER] to continue: " _
        sudo systemctl isolate multi-user
        sudo $(realpath $1) && 
        sudo systemctl isolate graphical ||
        echo "Failed to install NVIDIA driver"
    fi
}

function nvcp {
    version=$(nvsysver)
    if [[ $1 == restore ]]; then
        sudo cp -v --remove-destination $HOME/libnvidia-glcore.so.$version.backup /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        sudo rm -v -f $HOME/libnvidia-glcore.so.$version.backup
    else
        if [[ ! -f $HOME/libnvidia-glcore.so.$version.backup ]]; then
            sudo cp -v /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version $HOME/libnvidia-glcore.so.$version.backup
        fi
        if [[ -f $1 ]]; then
            sudo cp -v --remove-destination $1 /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        else
            config=$(nvbuildtype)
            sudo cp -v --remove-destination $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so /lib/x86_64-linux-gnu/libnvidia-glcore.so.$version
        fi
    fi
}

function nvscp {
    read -p "Remote host: " host
    read -e -i $USER -p "Remote user: " user
    
    if [[ $1 == restore ]]; then
        ssh $user@$host "source ~/wanliz_linux_workbench/bashrc_settings.sh; nvcp restore"
    else
        config=$(nvbuildtype)
        scp $P4ROOT/dev/gpu_drv/bugfix_main/drivers/OpenGL/_out/Linux_amd64_$config/libnvidia-glcore.so $user@$host:/tmp/libnvidia-glcore.so
        ssh $user@$host "source ~/wanliz_linux_workbench/bashrc_settings.sh; nvcp /tmp/libnvidia-glcore.so"
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

