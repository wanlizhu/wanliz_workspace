if [[ ! -f ./viewperf/bin/viewperf ]]; then
    pushd ~/viewperf2020 || exit 1
fi

read -e -i "1920x1080" -p "Resolution: " size

mkdir -p results/catia-06/ &&
./viewperf/bin/viewperf viewsets/catia/config/catia.xml -resolution $size &&
cat results/catia-06/results.xml  