if [[ ! -f ./viewperf/bin/viewperf ]]; then
    cd ~/viewperf2020 
fi

mkdir -p results/snx-04/ &&
./viewperf/bin/viewperf viewsets/snx/config/snx.xml -resolution 3840x2160 && 
cat results/snx-04/results.xml