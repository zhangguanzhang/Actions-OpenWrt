#!/bin/sh

# Change default shell to bash
if [ -f /bin/bash ];then
  sed -i '/^root:/s#/bin/ash#/bin/bash#' /etc/passwd
fi
# 同时开 bash 和 zsh 的话有上面优先
if [ -f /bin/zsh ];then
  sed -i '/^root:/s#/bin/ash#/bin/zsh#' /etc/passwd
fi

# ipk
opkg install /root/ipks/*_*_*.ipk
rm -f /root/ipks/*_*_*.ipk

uci set  aliyundrive-webdav.@server[0].enable=0
uci commit aliyundrive-webdav

uci set luci.main.mediaurlbase='/luci-static/argon_blue'
uci commit luci
# 此文件名注意ls 排序，下面也行
# sed -ri "/option mediaurlbase/s#(/luci-static/)[^']+#\1argon_blue#" /etc/config/luci
# uci commit luci

if [ -f /etc/config/qbittorrent ];then
    uci set qbittorrent.main.AnnounceToAllTrackers='true'
    uci commit qbittorrent
fi

# dnsmasq
uci set dhcp.@dnsmasq[0].rebind_protection='0'
uci set dhcp.@dnsmasq[0].localservice='0'
uci set dhcp.@dnsmasq[0].nonwildcard='0'
uci add_list dhcp.@dnsmasq[0].server='223.5.5.5#53'
uci commit dhcp


uci add_list system.ntp.server=120.25.115.20
uci commit system
