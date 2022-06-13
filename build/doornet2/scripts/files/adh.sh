# adh 提前下载
if grep -Eq '^CONFIG_PACKAGE_luci-app-adguardhome=y' .config;then
    mkdir -p files/usr/bin/
    wget -q https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz -O - | \
        tar -zxvf -  --strip-components 2 \
         -C files/usr/bin/ ./AdGuardHome/AdGuardHome
    chmod a+x files/usr/bin/AdGuardHome
    if [ -d feeds/others/luci-app-adguardhome ];then
        sed -i '/configpath/s#/etc/AdGuardHome.yaml#/etc/config/AdGuardHome.yaml#' feeds/others/luci-app-adguardhome/root/etc/config/AdGuardHome
    fi
    # https://github.com/rufengsuixing/luci-app-adguardhome/issues/130
    SED_NUM=$(awk '/^start_service/,/configpath/{a=NR}END{print a}' feeds/others/luci-app-adguardhome/root/etc/init.d/AdGuardHome)
    sed -i "$SED_NUM"'a [ ! -f "${configpath}" ] && cp /usr/share/AdGuardHome/AdGuardHome_template.yaml ${configpath}' feeds/others/luci-app-adguardhome/root/etc/init.d/AdGuardHome
fi