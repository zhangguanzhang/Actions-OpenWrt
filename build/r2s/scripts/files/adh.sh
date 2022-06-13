# adh 提前下载
if grep -Eq '^CONFIG_PACKAGE_luci-app-adguardhome=y' .config;then
    # 没匹配，则下载二进制文件，始终打包
    if ! grep -Eq '^CONFIG_PACKAGE_luci-app-adguardhome_INCLUDE_binary=y' .config;then
        mkdir -p files/usr/bin/
        wget -q https://static.adguard.com/adguardhome/release/AdGuardHome_linux_arm64.tar.gz -O - | \
            tar -zxvf -  --strip-components 2 \
            -C files/usr/bin/ ./AdGuardHome/AdGuardHome
        chmod a+x files/usr/bin/AdGuardHome
    fi

    adgh_config=$(find feeds -type f -name AdGuardHome -path '*/luci-app-adguardhome/root/etc/config*')
    if [ -n "${adgh_config}" ];then
        sed -i '/configpath/s#/etc/AdGuardHome.yaml#/etc/config/AdGuardHome.yaml#' ${adgh_config}
    fi
    # https://github.com/rufengsuixing/luci-app-adguardhome/issues/130
    SED_NUM=$(awk '/^start_service/,/configpath/{a=NR}END{print a}' ${adgh_config})
    sed -i "$SED_NUM"'a [ ! -f "${configpath}" ] && cp /usr/share/AdGuardHome/AdGuardHome_template.yaml ${configpath}' ${adgh_config}

    adg_makefile=$( find feeds -type f -name Makefile -path '*/luci-app-adguardhome/Makefile' )
    sed -i 's#/etc/AdGuardHome.yaml#/etc/config/AdGuardHome.yaml#'  $adg_makefile
fi