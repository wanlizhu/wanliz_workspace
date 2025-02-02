#!/bin/bash

if [[ -z $(which xdotool) ]]; then
    sudo apt install -y xdotool
fi

if [[ -d /opt/SPEC/SPECviewperf2020 ]]; then
    cd /opt/SPEC/SPECviewperf2020
else
    echo "Could not find viewperf directory"
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