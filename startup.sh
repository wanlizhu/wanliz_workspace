source $HOME/.bashrc
if [[ ! -d $HOME/wanliz_linux_workbench ]]; then
    exit -1
fi

if [[ ! -z $(which ifconfig) ]]; then
    ip=$(ifconfig | grep "172.16" | awk '{print $2}')
    if [[ -z $(grep "$ip $HOSTNAME" $HOME/wanliz_linux_workbench/hosts) ]]; then
        if [[ ! -z $(grep " $HOSTNAME" $HOME/wanliz_linux_workbench/hosts) ]]; then
            sed -i "/ $HOSTNAME$/d" $HOME/wanliz_linux_workbench/hosts
        fi
        echo "$ip $HOSTNAME" >> $HOME/wanliz_linux_workbench/hosts
        cd $HOME/wanliz_linux_workbench
        git add .
        git commit -m "update hosts"
        git pull && git push || git push -f
    fi
fi
