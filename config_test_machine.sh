if [[ $1 != local ]]; then
    read -p "Target machine: " machine 
    if [[ $machine != local ]]; then
        read -e -i "$USER" -p "Run as user: " user
        scp $HOME/wanliz_linux_workbench/config_test_machine.sh $user@$machine:/tmp/config_test_machine.sh
        ssh -t $user@$machine 'bash /tmp/config_test_machine.sh local'
        exit
    fi
fi

rm -rf /tmp/config.log 

export DISPLAY=:0
if [[ -z $(which vkcube) ]]; then
    sudo apt install -y vulkan-tools
fi
if ! vkcube --c 10; then
    read -p 'Run command `xhost +x` on test machine, then press [ENTER] to continue: ' _
fi

function check_and_install {
    if [[ -z $(which $1) ]]; then
        sudo apt install -y $2
    fi
}

check_and_install vim vim
check_and_install vkcube vulkan-tools
check_and_install ifconfig net-tools
check_and_install unzip unzip

function apt_install_any {
    if [[ -z $(which aptitude) ]]; then
        sudo apt install -y aptitude
    fi

    rm -rf /tmp/apt_failed /tmp/aptitude_failed
    
    for pkg in "$@"; do 
        sudo apt install -y $pkg || echo "$pkg" >> /tmp/apt_failed
    done
    
    if [[ -f /tmp/apt_failed ]]; then
        echo "Failed to install $(wc -l /tmp/apt_failed) packages using apt: "
        cat /tmp/apt_failed
        
        read -e -i "yes" -p "Retry with aptitude? (yes/no): " ans
        if [[ $ans == yes ]]; then
            while IFS= read -r pkg; do 
                sudo aptitude install $pkg || echo "$pkg" >> /tmp/aptitude_failed
            done < /tmp/apt_failed 
            
            if [[ -f /tmp/aptitude_failed ]]; then
                echo "Failed to install $(wc -l /tmp/aptitude_failed) packages using aptitude: "
                cat /tmp/aptitude_failed
                return -1
            fi
        fi
    fi
}

if [[ -z $(sudo cat /etc/sudoers | grep "$USER ALL=(ALL) NOPASSWD:ALL") ]]; then
    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null
    sudo cat /etc/sudoers | tail -1
    echo "- sudo with nopasswd  [OK]" >> /tmp/config.log
fi

sudo apt update

if [[ -z $(which perf) ]]; then
    sudo apt install -y linux-tools-common linux-tools-generic
fi

if [[ -z $(which git) ]]; then
    sudo apt install -y git
    git config --global user.name "Wanli Zhu"
    git config --global user.email zhu.wanli@icloud.com
    git config --global pull.rebase false
    echo "- git config ...  [OK]" >> /tmp/config.log
fi

if [[ ! -d $HOME/wanliz_linux_workbench ]]; then
    if ! ping -c2 linuxqa; then
        if [[ ! -f ~/vpn_with_sso.sh ]]; then
            cat >> ~/vpn_with_sso.sh << 'EOF'
read -e -i "yes" -p "Connect to NVIDIA VPN with SSO? (yes/no): " ans
if [[ $ans == yes ]]; then
    if [[ -z $(which openconnect) ]]; then
        sudo apt install -y openconnect
    fi
    read -e -i "firefox" -p "Complete authentication in browser: " browser
    read -e -i "no" -p "Run in background? (yes/no): " runinbg
    eval $(openconnect --useragent="AnyConnect-compatible OpenConnect VPN Agent" --external-browser $(which $browser) --authenticate ngvpn02.vpn.nvidia.com/SAML-EXT)
    [ -n ["$COOKIE"] ] && echo -n "$COOKIE" | sudo openconnect --cookie-on-stdin $CONNECT_URL --servercert $FINGERPRINT --resolve $RESOLVE 
fi
EOF
            chmod +x ~/vpn_with_sso.sh
        fi
        read -p "Run command ~/vpn_with_sso.sh, then press [ENTER] to continue: " _
    fi
    
    git clone https://wanliz:glpat-HDR4kyQBbsRxwBEBZtz7@gitlab-master.nvidia.com/wanliz/wanliz_linux_workbench $HOME/wanliz_linux_workbench
    apt_install_any build-essential gcc g++ cmake pkg-config libglvnd-dev 
    
    if [[ -d $HOME/wanliz_linux_workbench ]]; then
        echo "- Clone wanliz_linux_workbench  [OK]" >> /tmp/config.log
    else
        echo "- Clone wanliz_linux_workbench  [FAILED]" >> /tmp/config.log
    fi
fi

if [[ -z $(grep wanliz_linux_workbench ~/.bashrc) ]]; then
    if [[ -d $HOME/wanliz_linux_workbench ]]; then
        echo "" >> ~/.bashrc
        echo "source $HOME/wanliz_linux_workbench/bashrc_inc.sh" >> ~/.bashrc
        echo "- Source bashrc_inc.sh in ~/.bashrc  [OK]" >> /tmp/config.log
    fi
fi

if [[ -z $(sudo systemctl status ssh | grep 'active (running)') ]]; then
    sudo apt install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
    echo "- Install openssh-server  [OK]" >> /tmp/config.log
fi

if [[ $XDG_SESSION_TYPE == tty ]]; then
    read -e -i "x11" -p "XDG session type: " XDG_SESSION_TYPE
fi

if [[ $XDG_SESSION_TYPE == x11 ]]; then
    if [[ -z $(sudo lsof -i :5900-5909) ]]; then
        if [[ $(systemctl is-active x11vnc) == active ]]; then
            echo "x11vnc.service is already running"
        else 
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
    ExecStart=$(command -v x11vnc) -display :0 -rfbport 5900 -auth guess -forever -loop -noxdamage -repeat -usepw
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target" | sudo tee /etc/systemd/system/x11vnc.service
            fi

            sudo systemctl daemon-reload 
            sudo systemctl enable x11vnc.service
            sudo systemctl start  x11vnc.service
            echo "- Register x11vnc as service  [OK]" >> /tmp/config.log
        fi
    fi
elif [[ $XDG_SESSION_TYPE == wayland ]]; then
    if [[ -z $(sudo lsof -i :3389) ]]; then
        apt_install_any gnome-remote-desktop xdg-desktop-portal xdg-desktop-portal-gnome
        gsettings set org.gnome.desktop.remote-desktop.rdp enable true
        gsettings set org.gnome.desktop.remote-desktop.rdp.authentication-method 'password'
        echo -n "zhujie" | base64 | gsettings set org.gnome.desktop.remote-desktop.rdp.password-hash
        gsettings set org.gnome.desktop.remote-desktop.rdp.enable-remote-control true
        sudo ufw disable
        systemctl --user enable gnome-remote-desktop
        systemctl --user start gnome-remote-desktop
        sleep 1

        if [[ ! -z $(ip -br a | grep 3389) ]]; then
            echo "- Share wayland display  [OK]" >> /tmp/config.log
        else
            echo "- Share wayland display  [FAILED]" >> /tmp/config.log
        fi
    fi
else
    echo "- Share $XDG_SESSION_TYPE display  [FAILED]" >> /tmp/config.log 
fi

if [[ -z $(which p4) ]]; then
    sudo apt install -y helix-p4d || {
        if [[ $(lsb_release -i | cut -f2) == Ubuntu ]]; then
            pushd ~/Downloads 
            codename=$(lsb_release -c | cut -f2)
            wget https://package.perforce.com/perforce.pubkey
            gpg -n --import --import-options import-show perforce.pubkey
            wget -qO - https://package.perforce.com/perforce.pubkey | sudo apt-key add -
            #echo "deb http://package.perforce.com/apt/ubuntu $codename release" | sudo tee /etc/apt/sources.list.d/perforce.list
            echo "deb http://package.perforce.com/apt/ubuntu noble release" | sudo tee /etc/apt/sources.list.d/perforce.list
            sudo apt update 
            sudo apt install -y helix-p4d
            popd 
        fi
    }
    if [[ ! -z $(which p4) ]]; then
        echo "- Install p4 command  [OK]" >> /tmp/config.log
    else
        echo "- Install p4 command  [FAILED]" >> /tmp/config.log
    fi
fi

if [[ -z $(which p4v) ]]; then
    pushd ~/Downloads
    wget https://www.perforce.com/downloads/perforce/r24.4/bin.linux26x86_64/p4v.tgz
    tar -zxvf p4v.tgz 
    sudo cp -R p4v-2024.4.2690487/bin/* /usr/local/bin
    sudo cp -R p4v-2024.4.2690487/lib/* /usr/local/lib 
    popd

    [[ ! -z $(which p4v) ]] && 
    echo "- Install p4v command  [OK]" >> /tmp/config.log ||
    echo "- Install p4v command  [FAILED]" >> /tmp/config.log 
fi

if [[ ! -f $HOME/.p4ignore ]]; then
    if [[ -f $HOME/.p4ignore ]]; then
        cat $HOME/.p4ignore
    else
        read -e -i "yes" -p "$HOME/.p4ignore doesn't exist, create with default value? (yes/no): " ans
        if [[ $ans == yes ]]; then
            echo -e "_out\n.git\n.vscode\n" > $HOME/.p4ignore
            cat $HOME/.p4ignore
        fi
    fi
    echo "- Create file ~/.p4ignore  [OK]" >> /tmp/config.log
fi

if [[ -z $(which gtlfs) ]]; then
    sudo wget --no-check-certificate -O /usr/local/bin/gtlfs https://gtlfs.nvidia.com/client/linux && {
        sudo chmod +x /usr/local/bin/gtlfs
        echo "- Install gtlfs  [OK]" >> /tmp/config.log
    } || echo "- Install gtlfs  [FAILED]" >> /tmp/config.log
fi

ubuntu=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
if dpkg --compare-versions "$ubuntu" ge "24.0"; then
    if [[ ! -f /etc/sysctl.d/99-userns.conf ]]; then
        echo "kernel.apparmor_restrict_unprivileged_userns = 0" | sudo tee /etc/sysctl.d/99-userns.conf
        sudo sysctl --system
        echo "- Set kernel.apparmor_restrict_unprivileged_userns=0 for unix-build  [OK]" >> /tmp/config.log
    fi
fi

if [[ -z $(which code) ]]; then
    pushd ~/Downloads 
    sudo apt install -y software-properties-common apt-transport-https wget
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
    sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install -y code && 
        echo "- Install VS Code  [OK]" >> /tmp/config.log ||
        echo "- Install VS Code  [FAILED]" >> /tmp/config.log 
    popd 
fi

if [[ -z $(which slack) ]]; then
    sudo snap install slack --classic
fi

if [[ ! -f ~/.local/share/fonts/VerilySerifMono.otf ]]; then
    mkdir -p ~/.local/share/fonts
    if [[ -f ~/wanliz_linux_workbench/resources/VerilySerifMono.otf ]]; then
        cp ~/wanliz_linux_workbench/resources/VerilySerifMono.otf ~/.local/share/fonts
    else
        pushd ~/Downloads 
        wget -O verily_serif_mono.zip https://dl.dafont.com/dl/?f=verily_serif_mono &&
        unzip verily_serif_mono.zip && 
        cp verily_serif_mono/VerilySerifMono.otf ~/.local/share/fonts
        popd 
    fi
    fc-cache -f -v &&
    echo "- Install font VerilySerifMono  [OK]" >> /tmp/config.log ||
    echo "- Install font VerilySerifMono  [FAILED]" >> /tmp/config.log
fi

PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
FONT_NAME=$(gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ font)
if [[ $FONT_NAME != 'VerilySerifMono 14' ]]; then
    PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ use-system-font false
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ font 'VerilySerifMono 14'
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ background-color '#ffffff'
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ foreground-color '#171421'
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ default-size-columns 100
    gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/ default-size-rows 30
fi

#if [[ ! -f ~/.config/autostart/wanliz_post_startup.desktop ]]; then
#    if [[ ! -f ~/wanliz_post_startup.sh ]]; then
#        cat <<EOF > ~/wanliz_post_startup.sh
##!/bin/bash
#echo "This works, $USER" | tee ~/log
#ifconfig | grep "inet " | tee -a ~/log
#bash
#EOF
#        chmod +x ~/wanliz_post_startup.sh
#    fi
#
#    mkdir -p ~/.config/autostart
#    cat <<EOF > ~/.config/autostart/wanliz_post_startup.desktop
#[Desktop Entry]
#Type=Application
#Exec=~/wanliz_post_startup.sh
#Hidden=false
#NoDisplay=false
#X-GNOME-AutoStart-enabled=true
#Name=wanliz_post_startup
#Comment="This is wanli's custom startup application"
#EOF
#    echo "- Register autostart application: ~/wanliz_post_startup.sh"
#fi

echo -e '\n\n'
ip -br a
echo -e '\n\n'
cat /tmp/config.log || echo "Nothing to configure!"
echo "DONE"