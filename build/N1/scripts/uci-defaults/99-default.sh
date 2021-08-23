# ipk
opkg install /*_*_*.ipk
rm -f /*_*_*.ipk

ADH_BIN=$(uci -q get AdGuardHome.AdGuardHome.binpath)
if [ -n ${ADH_BIN} ] && [ -f /AdGuardHome ];then
    if [ -L ${ADH_BIN} ];then
        ADH_BIN_PATH=$(readlink -f ${ADH_BIN})
        mkdir -p ${ADH_BIN_PATH}
        uci -q set AdGuardHome.AdGuardHome.binpath="${ADH_BIN_PATH}/AdGuardHome"
    fi
    mv /AdGuardHome ${ADH_BIN}
fi


if [ -s /tmp/resolv.conf.d/resolv.conf.auto ];then
    echo nameserver 223.5.5.5 >> /tmp/resolv.conf.d/resolv.conf.auto
fi
