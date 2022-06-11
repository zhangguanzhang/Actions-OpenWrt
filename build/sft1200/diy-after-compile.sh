# sft1200 不考虑做 slim 和 full，默认会生成 imagebuilder，这里干掉
if [ -n "${GITHUB_RUN_NUMBER}" ];then
    rm -f $(dirname $(find openwrt/bin/targets/ -type f -name sha256sums ))/openwrt-*-root.squashfs
    #rm -f $(dirname $(find openwrt/bin/targets/ -type f -name sha256sums ))/*-imagebuilder-*
fi
true
