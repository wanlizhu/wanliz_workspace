if [[ ! -f ./viewperf/bin/viewperf ]]; then
    pushd ~/viewperf2020 || exit 1
fi

cat <<EOF > viewsets/snx/config/snx_10.xml
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE SPECGWPG>
<SPECGWPG Name="SPECviewperf" Version="v2.0" AppName="Siemens PLM NX 8.0" Results="results.xml" Log="log.txt">
    <Viewset Name="snx-04" Library="snx" Directory="snx" Threads="-1" Options="" Version="2.0">
        <Window Resolution="3840x2160" Height="2120" Width="3800" X="10" Y="20"/>
        <Window Resolution="1920x1080" Height="1060" Width="1900" X="10" Y="20"/>
        <Test Name="NX8_suvWireframe" Index="10" Weight="7.5" Seconds="15" Options="" Description="SUV in wireframe mode">
            <Grab Name="NX8_suvWireframe.png" Frames="1" X="0" Y="0"   />
        </Test>
    </Viewset>
</SPECGWPG>
EOF

echo "- 1920x1080"
echo "- 3840x2160"
read -e -i "1920x1080" -p "Resolution: " size
read -e -i "$(date +%H%M%S)" -p "Output folder suffix: " suffix

export workdir=`pwd`
export lifecycle=no
export freq=2000
export outfile=$HOME/Documents/viewperf_snx10_$suffix/perf.data
export wait_sec=2
export record_sec=5

mkdir -p results/snx-04/ 
run_with_perf.sh viewperf/bin/viewperf viewsets/snx/config/snx_10.xml -resolution $size 

while [[ ! -z $(pidof viewperf) ]]; do
    sleep 1
done

grep '<Test Index=' results/snx-04/results.xml | awk -F '"' '{print $10}'