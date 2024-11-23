if [[ -z $(which google-chrome) ]]; then
    echo "Google Chrome is required but missing"
    exit -1
fi

if [[ -z $(which openconnect) ]]; then
    sudo apt install -y openconnect
fi

eval $(openconnect --useragent="AnyConnect-compatible OpenConnect VPN Agent" --external-browser $(which google-chrome) --authenticate ngvpn02.vpn.nvidia.com/SAML-EXT)
[ -n ["$COOKIE"] ] && echo -n "$COOKIE" | sudo openconnect --cookie-on-stdin $CONNECT_URL --servercert $FINGERPRINT --resolve $RESOLVE

