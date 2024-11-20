if [[ $(systemctl is-active x11vnc) == active ]]; then
    echo "x11vnc.service is already running"
    exit 
fi

if [[ -z $(command -v x11vnc) ]]; then
    sudo apt install -y x11vnc
fi

if [[ ! -f $HOME/.vnc/passwd ]]; then
    x11vnc -storepasswd
fi

if [[ ! -f /etc/systemd/system/x11vnc.service ]]; then
    echo "[Unit]
Description=x11vnc server
After=display-manager.service

[Service]
Type=simple
User=$USER
ExecStart=$(command -v x11vnc) -display :0 -auth guess -forever -loop -noxdamage -repeat -usepw
Restart=on-failure

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/x11vnc.service
fi

sudo systemctl daemon-reload 
sudo systemctl enable x11vnc.service
sudo systemctl start  x11vnc.service
