# /usr/share/openclash/clash_version.sh

CLASH_CORE_PATH=files/etc/openclash/core/

if grep -Eq '^CONFIG_PACKAGE_luci-app-openclash=y' .config; then
    mkdir -p ${CLASH_CORE_PATH}
    # core
    wget https://github.com/vernesong/OpenClash/releases/download/Clash/clash-linux-armv8.tar.gz -O /tmp/clash-linux-armv8.tar.gz
    tar zxvf /tmp/clash-linux-armv8.tar.gz -C ${CLASH_CORE_PATH}
    rm -f /tmp/clash-linux-armv8.tar.gz
    # tun
    TUN_VERSION=$(curl -sL --connect-timeout 10 --retry 2 \
        https://raw.githubusercontent.com/vernesong/OpenClash/master/core_version -o - | sed -n '2p')
    wget https://github.com/vernesong/OpenClash/releases/download/TUN-Premium/clash-linux-armv8-${TUN_VERSION}.gz -O /tmp/clash-linux-armv8-${TUN_VERSION}.gz
    gzip -d /tmp/clash-linux-armv8-${TUN_VERSION}.gz --stdout > ${CLASH_CORE_PATH}/clash_tun
    # game
    wget https://github.com/vernesong/OpenClash/releases/download/TUN/clash-linux-armv8.tar.gz -O /tmp/clash-linux-armv8.tar.gz
    tar zxvf /tmp/clash-linux-armv8.tar.gz -O > ${CLASH_CORE_PATH}/clash_game
    rm -f /tmp/clash*

    chmod a+x ${CLASH_CORE_PATH}/clash*
fi
