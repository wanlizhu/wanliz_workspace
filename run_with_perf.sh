if [[ $1 == setup ]]; then
    echo "TODO"
    exit    
fi

if [[ $1 == *.sh ]]; then
    read -p "Executable file name: " exe
else
    exe=$1
    read -e -i "$(dirname $1)" -p "Working directory: " workdir
fi

if [[ ! -z $workdir ]]; then
    cd $workdir
fi

read -e -i "yes" -p "Record the complete life cycle of target app? (yes/no): " ans
read -e -i "max" -p "The sampling frequency: " freq
outdir=$HOME/Documents/$(basename $exe)_$(date +%H%M%S)
read -e -i "$outdir/perf.data" -p "The output file: " outfile
mkdir -p $(dirname $outfile)

if [[ $ans == yes ]]; then 
    echo "Do NOT run script file in this mode!"
    read -p "Press [ENTER] to continue or [CTRL-C] to cancel: " _
    sudo perf record -g --call-graph dwarf --freq=$freq --output=$outfile -- "$@" || exit -1
else
    read -e -i "3"   -p "The number of seconds to wait: " wait_sec
    read -e -i "1"   -p "The number of seconds to record: " record_sec
    
    "$@" &
    
    echo "[$exe] Wait $wait_sec seconds before recording $record_sec seconds"
    sleep $wait_sec
    exepid=$(pgrep -n $exe)

    if [[ -d /proc/$exepid ]]; then
        sudo perf record -g --call-graph dwarf --freq=$freq --output=$outfile --pid=$exepid -- sleep $record_sec || exit -1
    else
        echo "PID $exepid is invalid"
        exit -1
    fi
fi

read -e -i "yes" -p "Generate a svg flamegraph? (yes/no): " ans
if [[ $ans == yes ]]; then
    source ~/wanliz_linux_workbench/bashrc_inc.sh
    flamegraph $outfile
fi