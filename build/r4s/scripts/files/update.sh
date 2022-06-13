# /usr/share/openclash/clash_version.sh

wget -NP /tmp https://ghproxy.com/https://raw.githubusercontent.com/klever1988/nanopi-openwrt/zstd-bin/ddnz
chmod a+x /tmp/ddnz
mv /tmp/ddnz files/usr/bin/
