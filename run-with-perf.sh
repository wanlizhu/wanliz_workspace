if [[ $1 == setup ]]; then
    echo "TODO"
    exit    
fi

if [[ $1 == *.sh ]]; then
    read -p "Executable file name: " exe
else
    exe=$1

    if [[ -z $workdir ]]; then
        read -e -i "$(dirname $1)" -p "Working directory: " workdir
    fi
fi

if [[ ! -z $workdir ]]; then
    cd $workdir
fi

if [[ -z $lifecycle ]]; then
    read -e -i "yes" -p "Record the complete life cycle of target app? (yes/no): " lifecycle
fi

if [[ -z $freq ]]; then
    read -e -i "max" -p "The sampling frequency: " freq
fi

if [[ -z $outfile ]]; then
    outdir=$HOME/Documents/$(basename $exe)_$(date +%H%M%S)
    read -e -i "$outdir/perf.data" -p "The output file: " outfile
fi
mkdir -p $(dirname $outfile)

if [[ -f $outfile ]]; then
    read -e -i "yes" -p "$outfile already exists, overwrite it? (yes/no): " ans
    if [[ $ans == yes ]]; then
        rm -rf $outfile
        read -e -i "yes" -p "Clean up directory $(dirname $outfile)? (yes/no): " ans
        if [[ $ans == yes ]]; then
            rm -rf $(dirname $outfile)
            mkdir -p $(dirname $outfile)
        fi
    fi
fi

if [[ ! -z $(cat /proc/driver/nvidia/version | grep -i 'Release Build') ]]; then
    echo "The installed nvidia driver is a release build"
    read -e -i "yes" -p "Continue without nvidia debug symbols? (yes/no): " ans
    if [[ $ans != yes ]]; then
        exit -1
    fi
fi

if [[ $lifecycle == yes ]]; then 
    if [[ $exe == *.sh ]]; then
        echo "Do NOT run script file in this mode!"
        exit -1
    fi
    SECONDS=0
    echo "Recording the whole life cycle"
    sudo perf record -g --call-graph dwarf --freq=$freq --output=$outfile -- "$@" || exit -1
    echo "Finished recording after $SECONDS seconds"
else
    if [[ -z $wait_sec ]]; then
        read -e -i "3"   -p "The number of seconds to wait: " wait_sec
    fi

    if [[ -z $record_sec ]]; then
        read -e -i "1"   -p "The number of seconds to record: " record_sec
    fi

    "$@" &
    
    echo "[$exe] Wait $wait_sec seconds before recording $record_sec seconds"
    sleep $wait_sec
    exepid=$(pgrep -n $(basename $exe))

    if [[ -d /proc/$exepid ]]; then
        SECONDS=0
        echo "Recording process $exepid ($(basename $exe))"
        sudo perf record -g --call-graph dwarf --freq=$freq --output=$outfile --pid=$exepid -- sleep $record_sec || exit -1
        echo "Finished recording after $SECONDS seconds"
    else
        echo "PID $exepid is invalid"
        exit -1
    fi
fi

if [[ -f $outfile ]]; then
    source ~/wanliz_workspace/test-env.sh
    flamegraph $outfile
fi