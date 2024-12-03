source $HOME/.bashrc
if [[ ! -d $HOME/wanliz_linux_workbench ]]; then
    exit -1
fi

if [[ ! -z $(which ifconfig) ]]; then
    ip=$(ifconfig | grep "172.16" | awk '{print $2}')
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
fi

exit 111