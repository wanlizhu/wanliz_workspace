if [[ -z $(which nvidia-smi) ]]; then
    echo "Install nvidia driver first"
    exit -1
fi

if [[ -z $(sudo grep '^WaylandEnable=false' /etc/gdm3/custom.conf) ]]; then
    if [[ ! -z $(sudo grep 'WaylandEnable=' /etc/gdm3/custom.conf) ]]; then
        sudo sed -i "s/.*WaylandEnable=.*/WaylandEnable=false/" /etc/gdm3/custom.conf
        echo "Replace *** with WaylandEnable=false in /etc/gdm3/custom.conf"
    else
        echo "WaylandEnable=false" | sudo tee -a /etc/gdm3/custom.conf >/dev/null
        echo "Append WaylandEnable=false to /etc/gdm3/custom.conf"
    fi
    #sudo systemctl daemon-reload 
fi

if [[ $XDG_SESSION_TYPE == tty ]]; then
    read -e -i yes -p "Restart gdm to disable wayland? (yes/no): " ans
    if [[ $ans == yes ]]; then
        sudo systemctl restart gdm
    fi
fi