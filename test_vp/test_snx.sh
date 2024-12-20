if [[ ! -f ./viewperf/bin/viewperf ]]; then
    cd ~/viewperf2020 
fi

mkdir -p results/snx-04/ 
read -e -i "1920x1080" -p "Resolution: " size

viewperf/bin/viewperf viewsets/snx/config/snx.xml -resolution $size 

while [[ ! -z $(pidof viewperf) ]]; do
    sleep 1
done

grep '<Test Index=' results/snx-04/results.xml | awk -F '"' '{print $10}' 