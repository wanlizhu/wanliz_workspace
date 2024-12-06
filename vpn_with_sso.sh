if [[ -z $(which google-chrome) ]]; then
    echo "Google Chrome is required but missing"
    exit -1
fi

if [[ -z $(which openconnect) ]]; then
    sudo apt install -y openconnect
fi

read -e -i "firefox" -p "Complete authentication in browser: " browser
eval $(openconnect --useragent="AnyConnect-compatible OpenConnect VPN Agent" --external-browser $(which $browser) --authenticate ngvpn02.vpn.nvidia.com/SAML-EXT)
[ -n ["$COOKIE"] ] && echo -n "$COOKIE" | sudo openconnect --cookie-on-stdin $CONNECT_URL --servercert $FINGERPRINT --resolve $RESOLVE

