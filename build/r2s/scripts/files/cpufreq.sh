# https://github.com/coolsnowwolf/lede/issues/7844#issuecomment-966829782

if grep -Eq '^CONFIG_PACKAGE_luci-app-cpufreq=y' .config; then
    rm -rf package/lean/luci-app-cpufreq
    svn co https://github.com/immortalwrt/luci/trunk/applications/luci-app-cpufreq feeds/luci/applications/luci-app-cpufreq
    #svn co https://github.com/immortalwrt/luci/trunk/applications/luci-app-cpufreq package/lean/luci-app-cpufreq
    #ln -sf ./feeds/luci/applications/luci-app-cpufreq ./package/feeds/luci/luci-app-cpufreq
    sed -i  -e 's,1608,1800,g' \
            -e 's,2016,2208,g' \
            -e 's,1512,1608,g' \
        feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
        #package/lean/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
        #feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/cpufreq
fi
