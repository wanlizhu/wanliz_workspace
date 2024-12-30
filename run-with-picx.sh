if [[ $1 == setup ]]; then
    if [[ ! -f $HOME/PIC-X_Package/SinglePassCapture/pic-x ]]; then
        echo "PIC-X is not installed on $HOSTNAME"
        exit -1
    fi
    if [[ ! -x $HOME/PIC-X_Package/SinglePassCapture/pic-x ]]; then
        chmod +x $HOME/PIC-X_Package/SinglePassCapture/pic-x
    fi
    sudo apt remove -y python3-keyring python3-urllib3
    sudo apt install -y python3 python3-pip
    python3 -m pip install --break-system-packages -r $HOME/PIC-X_Package/SinglePassCapture/PerfInspector/processing/requirements.txt
    sudo python3 -m pip install --break-system-packages -r $HOME/PIC-X_Package/SinglePassCapture/PerfInspector/processing/requirements.txt
    exit 
fi

if [[ $1 == host ]]; then
    cd $HOME/PIC-X_Package/SinglePassCapture || exit -1
    read -e -i "vk"  -p "The graphics API to hook (vk or ogl): " api
    read -e -i "3"   -p "The number of frames to capture: " frames
    read -e -i "1" -p "Trigger (0=hotkey, 1=text): " trigger 
    sudo ./pic-x --clean=1 --exit=0 --api=$api --frames=$frames --trigger=$trigger 
    exit 
fi

read -e -i "$(dirname $1)" -p "Working directory (empty=current): " workdir
if [[ ! -z $workdir ]]; then
    cd $workdir
fi

exe=$1
shift 
arg="$@"

outdir=$(basename $exe)_$(date +%H%M%S)
read -e -i "$outdir" -p "The output directory: " outdir
read -e -i "vk" -p "The graphics API to hook (vk or ogl): " api
read -e -i "3" -p "The number of seconds to wait: " wait_sec
read -e -i "3" -p "The number of frames to capture: " frames

sudo `which pic-x` --clean=1 --exit=0 --api=$api --exe=$1 --arg="$arg" --workdir=$workdir --sleep=$wait_sec --frames=$frames --name=$outdir  
