# adh 提前下载
if grep -Eq '^CONFIG_PACKAGE_luci-app-adguardhome=y' .config;then
    mkdir -p files/usr/bin/
    wget https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz -O - | \
        tar -zxvf -  --strip-components 2 \
         -C files/usr/bin/ ./AdGuardHome/AdGuardHome
    chmod a+x files/usr/bin/AdGuardHome
fi