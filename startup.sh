source $HOME/.bashrc

if [[ $1 == register ]]; then
    sudo cp -fv ~/wanliz_linux_workbench/startup.service /etc/systemd/system/startup.service
    sudo systemctl daemon-reload
    sudo systemctl enable startup.service
    exit 
fi

if [[ ! -z $(which ifconfig) ]]; then
    while [[ -z $ip ]]; do
        ip=$(ifconfig | grep "172.16" | awk '{print $2}')
        sleep 3
    done
    if [[ ! -z $ip ]]; then
        case $HOSTNAME in
            "scc-03-3062-dev")  host=dev ;;
            "scc-03-3062-test") host=test ;;
            "scc-03-3062-wfh")  host=wfh ;;
            *) host=$HOSTNAME ;;
        esac
        if [[ -z $(grep "$ip $host" $HOME/wanliz_linux_workbench/hosts) ]]; then
            if [[ ! -z $(grep " $host" $HOME/wanliz_linux_workbench/hosts) ]]; then
                sed -i "/ $host$/d" $HOME/wanliz_linux_workbench/hosts
            fi
            echo "$ip $host" >> $HOME/wanliz_linux_workbench/hosts
            cd $HOME/wanliz_linux_workbench
            git add .
            git commit -m "update hosts"
            git pull && git push || git push -f
        fi
    else
        echo "Not inside NVIDIA domain" | tee -a $HOME/startup.log
        ifconfig | tee -a $HOME/startup.log
    fi
fi
