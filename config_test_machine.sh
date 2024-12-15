if [[ $1 != local ]]; then
    read -p "Target machine: " machine 
    read -e -i "$USER" -p "Run as user: " user
    scp $HOME/wanliz_linux_workbench/config_test_machine.sh $user@$machine:/tmp/config_test_machine.sh
    ssh -t $user@$machine 'bash /tmp/config_test_machine.sh local'
    exit
fi

rm -rf /tmp/config.log 

function check_and_install {
    if [[ -z $(which $1) ]]; then
        sudo apt install -y $2
    fi
}

function apt_install_any {
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
    echo "- sudo with nopasswd  [OK]" | tee -a /tmp/config.log
fi

if [[ -z $(which git) ]]; then
    sudo apt install -y git
    git config --global user.name "Wanli Zhu"
    git config --global user.email zhu.wanli@icloud.com
    git config --global pull.rebase false
    echo "- git config ...  [OK]" | tee -a /tmp/config.log 
fi

if [[ ! -d $HOME/wanliz_linux_workbench ]]; then
    git clone https://wanliz:glpat-HDR4kyQBbsRxwBEBZtz7@gitlab-master.nvidia.com/wanliz/wanliz_linux_workbench $HOME/wanliz_linux_workbench
    apt_install_any build-essential gcc g++ cmake pkg-config libglvnd-dev 
    echo "- Clone wanliz_linux_workbench  [OK]" | tee -a /tmp/config.log
fi

if [[ -z $(grep wanliz_linux_workbench ~/.bashrc) ]]; then
    echo "" >> ~/.bashrc
    echo "source $HOME/wanliz_linux_workbench/bashrc_inc.sh" >> ~/.bashrc
    echo "- Source bashrc_inc.sh in ~/.bashrc  [OK]" | tee -a /tmp/config.log
fi

check_and_install vim vim
check_and_install vkcube vulkan-tools
check_and_install ifconfig net-tools

if [[ -z $(sudo systemctl status ssh | grep 'active (running)') ]]; then
    sudo apt install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
    echo "- Install openssh-server  [OK]" | tee -a /tmp/config.log
fi

if [[ -z $(sudo lsof -i :5900-5909) ]]; then
    register_x11vnc_service.sh 
    echo "- Register x11vnc as service  [OK]" | tee -a /tmp/config.log
fi

if [[ -z $(which p4) ]]; then
    p4install 
    echo "- Install p4 command  [OK]" | tee -a /tmp/config.log
fi

if [[ ! -f $HOME/.p4ignore ]]; then
    p4ignore
    echo "- Create file ~/.p4ignore  [OK]" | tee -a /tmp/config.log
fi

if [[ ! -z $P4CLIENT && ! -d $P4ROOT ]]; then
    read -e -i "yes" -p "Checkout perforce client $P4CLIENT? : " checkout
    if [[ $checkout == yes ]]; then
        mkdir -p $P4ROOT
        cd $P4ROOT
        p4 sync -f //sw/...
        echo "- Sync $P4CLIENT (forced)  [OK]" | tee -a /tmp/config.log
    fi
fi

ubuntu=$(grep '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
if dpkg --compare-versions "$ubuntu" ge "24.0"; then
    if [[ ! -f /etc/sysctl.d/99-userns.conf ]]; then
        echo "kernel.apparmor_restrict_unprivileged_userns = 0" | sudo tee /etc/sysctl.d/99-userns.conf
        sudo sysctl --system
        echo "- Set kernel.apparmor_restrict_unprivileged_userns=0 for unix-build  [OK]" | tee -a /tmp/config.log
    fi
fi

echo 
cat /tmp/config.log
echo "DONE"