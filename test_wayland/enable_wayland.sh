if [[ -z $(which nvidia-smi) ]]; then
    echo "Install nvidia driver first"
    exit -1
fi

if [[ -z $(sudo grep '^WaylandEnable=true' /etc/gdm3/custom.conf) ]]; then
    if [[ ! -z $(sudo grep 'WaylandEnable=' /etc/gdm3/custom.conf) ]]; then
        sudo sed -i "s/.*WaylandEnable=.*/WaylandEnable=true/" /etc/gdm3/custom.conf
        echo "Replace *** with WaylandEnable=true in /etc/gdm3/custom.conf"
    else
        echo "WaylandEnable=true" | sudo tee -a /etc/gdm3/custom.conf >/dev/null
        echo "Append WaylandEnable=true to /etc/gdm3/custom.conf"
    fi
    #sudo systemctl daemon-reload 
fi

if [[ $(sudo cat /sys/module/nvidia_drm/parameters/modeset) != 'Y' ]]; then
    echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-modeset.conf
    echo "A reboot is required"
elif [[ $XDG_SESSION_TYPE == tty ]]; then
    read -e -i yes -p "Restart gdm to enable wayland? (yes/no): " ans
    if [[ $ans == yes ]]; then
        sudo systemctl restart gdm
    fi
fi