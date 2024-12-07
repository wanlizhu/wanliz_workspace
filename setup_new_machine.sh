read -e -i "localhost" -p "Target machine: " machine 
if [[ $machine != localhost ]]; then
    read -e -i "$USER"     -p "Run as user: " user
    ssh -t $user@$machine 'bash -s' < $HOME/wanliz_linux_workbench/setup_new_machine.sh 
    exit
fi

if [[ -z $(sudo cat /etc/sudoers | grep "$USER ALL=(ALL) NOPASSWD:ALL") ]]; then
    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers >/dev/null
    sudo cat /etc/sudoers | tail -1
fi

if [[ -z $(which git) ]]; then
    sudo apt install -y git
    git config --global user.name "Wanli Zhu"
    git config --global user.email zhu.wanli@icloud.com
    git config --global pull.rebase false
fi

if [[ ! -d $HOME/wanliz_linux_workbench ]]; then
    git clone https://wanliz:glpat-HDR4kyQBbsRxwBEBZtz7@gitlab-master.nvidia.com/wanliz/wanliz_linux_workbench $HOME/wanliz_linux_workbench
    sudo apt install -y build-essential gcc g++ cmake pkg-config libglvnd-dev 
fi

if [[ -z $(grep wanliz_linux_workbench ~/.bashrc) ]]; then
    echo "" >> ~/.bashrc
    echo "source $HOME/wanliz_linux_workbench/bashrc_inc.sh" >> ~/.bashrc
    source ~/.bashrc
fi

if [[ -z $(sudo systemctl status ssh | grep 'active (running)') ]]; then
    sudo apt install -y openssh-server
fi

if [[ -z $(sudo lsof -i :5900-5909) ]]; then
    x11vnc_service_register.sh 
fi

if [[ -z $(which p4) ]]; then
    p4ins 
fi

if [[ ! -f $HOME/.p4ignore ]]; then
    p4ignore
fi

if [[ ! -z $P4CLIENT && ! -d $P4ROOT ]]; then
    read -e -i "yes" -p "Checkout perforce client $P4CLIENT? : " checkout
    if [[ $checkout == yes ]]; then
        mkdir -p $P4ROOT
        cd $P4ROOT
        p4 sync -f //sw/...
    fi
fi

synchosts


