
# ipk
opkg install /root/ipks/*_*_*.ipk
rm -f /root/ipks/*_*_*.ipk

uci set  aliyundrive-webdav.@server[0].enable=0
uci commit aliyundrive-webdav

# uci set luci.main.mediaurlbase='/luci-static/argon_blue'
# uci commit luci
# 上面不生效
sed -ri "/option mediaurlbase/s#(/luci-static/)[^']+#\1argon_blue#" /etc/config/luci
uci commit luci

if [ -f /etc/config/qbittorrent ];then
    uci set qbittorrent.main.AnnounceToAllTrackers='true'
    uci commit qbittorrent
fi

# dnsmasq
uci set dhcp.@dnsmasq[0].rebind_protection='0'
uci set dhcp.@dnsmasq[0].localservice='0'
uci set dhcp.@dnsmasq[0].nonwildcard='0'
uci set dhcp.@dnsmasq[0].server='223.5.5.5'
uci commit dhcp
