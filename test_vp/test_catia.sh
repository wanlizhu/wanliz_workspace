if [[ ! -f ./viewperf/bin/viewperf ]]; then
    pushd ~/viewperf2020 || exit 1
fi

mkdir -p results/catia-06/ &&
./viewperf/bin/viewperf viewsets/catia/config/catia.xml -resolution 1920x1080 &&
cat results/catia-06/results.xml  