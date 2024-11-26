if [[ ! -f ./viewperf/bin/viewperf ]]; then
    pushd ~/viewperf2020 || exit 1
fi

mkdir -p results/snx-04/ &&
./viewperf/bin/viewperf viewsets/snx/config/snx.xml -resolution 1920x1080 &&
cat results/snx-04/results.xml  