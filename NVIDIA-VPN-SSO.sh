#!/bin/bash

if [[ -z $(which openconnect) ]]; then
    sudo apt install -y openconnect
fi

if [[ -z $(openconnect --version | head -1 | grep "v9") ]]; then
    pushd ~/Downloads
    if [[ -z $(lsb_release -r | grep "22") ]]; then
        wget --no-check-certificate https://download.opensuse.org/repositories/home:/bluca:/openconnect/Ubuntu_22.04/amd64/openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb || exit -1
        sudo dpkg -i openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb
    elif [[ -z $(lsb_release -r | grep "24") ]]; then
        wget --no-check-certificate https://download.opensuse.org/repositories/home:/bluca:/openconnect/Ubuntu_24.04/amd64/openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb || exit -1
        sudo dpkg -i openconnect_9.12+201+gf17fe20-0+283.1_amd64.deb
    else
        echo "Download openconnect manually: https://software.opensuse.org//download.html?project=home%3Abluca%3Aopenconnect&package=openconnect"
        exit -1
    fi
    popd 
fi

vpnid=$([[ -z $1 ]] && echo 02 || echo $1)
eval $(openconnect --useragent="AnyConnect-compatible OpenConnect VPN Agent" --external-browser $(which google-chrome) --authenticate ngvpn$vpnid.vpn.nvidia.com/SAML-EXT) 
[ -n ["$COOKIE"] ] && echo -n "$COOKIE" | sudo openconnect --cookie-on-stdin $CONNECT_URL --servercert $FINGERPRINT --resolve $RESOLVE 