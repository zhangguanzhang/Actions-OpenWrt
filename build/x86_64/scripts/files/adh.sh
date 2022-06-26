# adh 提前下载
if grep -Eq '^CONFIG_PACKAGE_luci-app-adguardhome=y' .config;then

    # adgh_config=$(find feeds -type f -name AdGuardHome -path '*/luci-app-adguardhome/root/etc/config/AdGuardHome')
    # if [ -n "${adgh_config}" ];then
    #     sed -i '/configpath/s#/etc/AdGuardHome.yaml#/etc/config/AdGuardHome.yaml#' ${adgh_config}
    # fi
    adh_initd_file=$(find feeds -type f -name AdGuardHome -path '*/luci-app-adguardhome/root/etc/init.d/AdGuardHome')
    if [ -n "$adh_initd_file" ];then
        # https://github.com/rufengsuixing/luci-app-adguardhome/issues/130
        SED_NUM=$(awk '/^start_service/,/configpath/{a=NR}END{print a}' feeds/others/luci-app-adguardhome/root/etc/init.d/AdGuardHome)
        sed -i "$SED_NUM"'a [ ! -f "${configpath}" ] && cp /usr/share/AdGuardHome/AdGuardHome_template.yaml ${configpath}' \
            $adh_initd_file
    fi

    # 替换有问题
    # adg_makefile=$( find feeds -type f -name Makefile -path '*/luci-app-adguardhome/Makefile' )
    # sed -i 's#/etc/AdGuardHome.yaml#/etc/config/AdGuardHome.yaml#'  $adg_makefile
fi