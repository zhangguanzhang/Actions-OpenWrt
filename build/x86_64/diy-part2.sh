#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

kernel_ver=$(grep -Po '^KERNEL_PATCHVER=\K\S+' target/linux/x86/Makefile)
# 519 问题很多，回退到 515
if [ "$build_target" = x86_64 ] && echo "$kernel_ver" | grep -Pq '5.1[89]';then
    sed -ri '/^KERNEL_PATCHVER=/s#'"${kernel_ver}"'#5.15#' target/linux/x86/Makefile
fi

# rtl8812bu 貌似无法工作
# rm -rf package/kernel/rtl88x2bu
# git clone --depth=1 -b openwrt-21.02 https://github.com/erintera/openwrt-rtl8812bu-package.git package/kernel/rtl88x2bu
# echo 'CONFIG_PACKAGE_kmod-rtl88x2bu=y' >> .config



# ----------- 提前打包一些文件，防止初次使用去下载
# files下会合并到最终的 rootfs 里
mkdir -p files
# 初次开机设置脚本
mkdir -p files/etc/uci-defaults/
cp ${GITHUB_WORKSPACE}/scripts/uci-defaults/* files/etc/uci-defaults/
chmod a+x files/etc/uci-defaults/*

# 预处理下载相关文件，保证打包固件不用单独下载
for sh_file in `ls ${GITHUB_WORKSPACE}/scripts/files/*.sh`;do
    source $sh_file
done

chmod a+x ${GITHUB_WORKSPACE}/build/scripts/*.sh
# 放入升级脚本
\cp -a ${GITHUB_WORKSPACE}/build/scripts/update.sh files/


# ---------- end -----------

# https://github.com/coolsnowwolf/lede/issues/8423
# https://github.com/coolsnowwolf/packages/pull/315 回退后删掉这三行
sed -i 's/^\s*$[(]call\sEnsureVendoredVersion/#&/' feeds/packages/utils/dockerd/Makefile
