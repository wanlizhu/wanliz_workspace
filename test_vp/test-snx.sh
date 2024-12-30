if [[ ! -f ./viewperf/bin/viewperf ]]; then
    pushd ~/viewperf2020 || exit 1
fi

echo "- 1920x1080"
echo "- 3840x2160"
read -e -i "1920x1080" -p "Resolution: " size

mkdir -p results/snx-04/ &&
./viewperf/bin/viewperf viewsets/snx/config/snx.xml -resolution $size &&
grep '<Test Index=' results/snx-04/results.xml | awk -F '"' '{print $10}' 
