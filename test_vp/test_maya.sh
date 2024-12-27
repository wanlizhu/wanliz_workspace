if [[ ! -f ./viewperf/bin/viewperf ]]; then
    cd ~/viewperf2020 
fi

echo "- 1920x1080"
echo "- 3840x2160"
read -e -i "1920x1080" -p "Resolution: " size

mkdir -p results/maya-06/ &&
./viewperf/bin/viewperf viewsets/maya/config/maya.xml -resolution $size && 
cat results/maya-06/results.xml
