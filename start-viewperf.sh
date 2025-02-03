#!/bin/bash

if [[ -z $(which xdotool) ]]; then
    sudo apt install -y xdotool
fi

if [[ -d /opt/SPEC/SPECviewperf2020 ]]; then
    cd /opt/SPEC/SPECviewperf2020
elif [[ -d $HOME/viewperf2020 ]]; then
    cd $HOME/viewperf2020
else
    echo "Could not find viewperf directory"
    read -e -i "yes" -p "Install from official website? (yes/no) " ans
    if [[ $ans == "yes" ]]; then
        cd $HOME/Downloads
        wget https://www.spec.org/downloads/gpc/opc/viewperf/viewperf2020_3.0_amd64.deb || exit -1
        sudo dpkg -i ./viewperf2020_3.0_amd64.deb || exit -1
        echo "To download viewsets in viewperf GUI manually"
    fi
    exit -1
fi

./RunViewperf &
sleep 3

window_id=$(xdotool search --name "SPECviewperf 2020 v3.0")
if [[ -z $window_id ]]; then
    echo "Could not find window with title 'SPECviewperf 2020 v3.0'"
    exit -1
fi

xdotool windowactivate $window_id
xdotool mousemove --window $window_id 450 550 click 1

echo "Viewperf is running..."
sleep 3
while [[ ! -z $(pidof viewperf) ]]; do
    sleep 1
done 
echo "Viewperf has finished"
