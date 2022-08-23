# https://github.com/coolsnowwolf/lede/issues/7844#issuecomment-966829782

# change the voltage value for over-clock stablization
config_file_cpufreq=`find package/ -follow -type f -path '*/luci-app-cpufreq/root/etc/config/cpufreq'`
if [ -n "$config_file_cpufreq" ];then
    truncate -s-1 $config_file_cpufreq
    sed -ri '/option (governor|minfreq|maxfreq)/d' $config_file_cpufreq
    echo -e "\toption governor 'schedutil'" >> $config_file_cpufreq
    echo -e "\toption minfreq '816000'" >> $config_file_cpufreq
    echo -e "\toption maxfreq '1512000'\n" >> $config_file_cpufreq
fi


# # luci-app-freq
# svn export https://github.com/immortalwrt/luci/trunk/applications/luci-app-cpufreq feeds/luci/applications/luci-app-cpufreq
# sed -i 's,600000 1608000,600000 1800000,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
# sed -i 's,600000 2016000,600000 2208000,g' feeds/luci/applications/luci-app-cpufreq/root/etc/uci-defaults/10-cpufreq
# ln -sf ../../../feeds/luci/applications/luci-app-cpufreq package/feeds/luci/luci-app-cpufreq
# pushd feeds/luci
#     git add applications/luci-app-cpufreq
#     git commit -am "add luci-app-cpufreq"
# popd
