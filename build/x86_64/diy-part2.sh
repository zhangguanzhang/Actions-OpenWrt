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

# Modify default theme
# https://github.com/jerrykuku/luci-theme-argon/tree/18.06
# https://github.com/kenzok8/openwrt-packages
sed -ri 's/luci-theme-\S+/luci-theme-argonne/g' feeds/luci/collections/luci/Makefile  # feeds/luci/modules/luci-base/root/etc/config/luci


# luci-theme-atmaterial_new
# https://github.com/kenzok8/openwrt-packages 已经添加了，所以这里备用拉取
if [ ! -d feeds/others/luci-theme-atmaterial_new ];then
    git clone -b main --depth 1 https://github.com/Chandler-Lu/openwrt-package /tmp/openwrt-package
    if [ -d '/tmp/openwrt-package/luci-theme-atmaterial_new' ];then
        mv /tmp/openwrt-package/luci-theme-atmaterial_new feeds/others/
    fi
fi

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

# 修改banner
echo -e " built on "$(TZ=Asia/Shanghai date '+%Y.%m.%d %H:%M') - ${GITHUB_RUN_NUMBER}"\n -----------------------------------------------------" >> package/base-files/files/etc/banner

# /tmp/resolv.conf.d/resolv.conf.auto
# mkdir -p files/tmp/resolv.conf.d/
# echo nameserver 223.5.5.5 >> files/tmp/resolv.conf.d/resolv.conf.auto


# ---------- end -----------

# https://github.com/coolsnowwolf/lede/issues/8423
# https://github.com/coolsnowwolf/packages/pull/315 回退后删掉这三行
sed -i 's/^\s*$[(]call\sEnsureVendoredVersion/#&/' feeds/packages/utils/dockerd/Makefile
