if [[ ! -f ./viewperf/bin/viewperf ]]; then
    pushd ~/viewperf2020 || exit 1
fi

echo "- 1920x1080"
echo "- 3840x2160"
read -e -i "1920x1080" -p "Resolution: " size

mkdir -p results/energy-03/ &&
gdb --args ./viewperf/bin/viewperf viewsets/energy/config/energy.xml -resolution $size && 
cat results/energy-03/results.xml
