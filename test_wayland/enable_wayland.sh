if [[ -z $(which nvidia-smi) ]]; then
    echo "Install nvidia driver first"
    exit -1
fi

if [[ $(sudo cat /sys/module/nvidia_drm/parameters/modeset) != 'Y' ]]; then
    echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-modeset.conf
    echo "A reboot is required"
fi

if [[ -z $(sudo grep '^WaylandEnable=true' /etc/gdm3/custom.conf) ]]; then
    echo "- Todo: edit /etc/gdm3/custom.conf to add WaylandEnable=true"
fi