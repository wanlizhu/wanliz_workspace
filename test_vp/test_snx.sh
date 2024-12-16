if [[ ! -f ./viewperf/bin/viewperf ]]; then
    cd ~/viewperf2020 
fi

read -e -i "1920x1080" -p "Resolution: " size

mkdir -p results/snx-04/ &&
./viewperf/bin/viewperf viewsets/snx/config/snx.xml -resolution $size && 
cat results/snx-04/results.xml