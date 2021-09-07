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
sed -ri 's/luci-theme-\S+/luci-theme-argon_new/g' feeds/luci/collections/luci/Makefile


# luci-theme-atmaterial_new
# https://github.com/kenzok8/openwrt-packages 已经添加了，所以这里备用拉取
if [ ! -d feeds/others/luci-theme-atmaterial_new ];then
    git clone -b main --depth 1 https://github.com/Chandler-Lu/openwrt-package /tmp/openwrt-package
    if [ -d '/tmp/openwrt-package/luci-theme-atmaterial_new' ];then
        mv /tmp/openwrt-package/luci-theme-atmaterial_new feeds/others/
    fi
fi

# Fix https://github.com/coolsnowwolf/lede/issues/7770

if grep -Eq '^PKG_VERSION:=4.14.6' package/feeds/packages/samba4/Makefile; then
    sed -ri -e '/^PKG_VERSION:=/s#4.14.6#4.13.9#' \
        -e '/^PKG_HASH:=/s#:=.+#:=b97a773ed3b4dae6d5ebd3e09337c897ae898b65f38abad550f852b594d4e07f#' package/feeds/packages/samba4/Makefile 
fi

# N1 的安装到 emcc的脚本
git clone --depth 1 https://github.com/tuanqing/install-program package/install-program
echo 'CONFIG_PACKAGE_install-program=y' >> .config


# ----------- 提前打包一些文件，防止初次使用去下载
# files下会合并到最终的 rootfs 里
mkdir -p files

# 初次开机设置脚本
mkdir -p files/etc/uci-defaults/
cp ${GITHUB_WORKSPACE}/scripts/uci-defaults/* files/etc/uci-defaults/
chmod a+x files/etc/uci-defaults/*

# 预处理下载相关文件，保证打包固件不用单独下载
source ${GITHUB_WORKSPACE}/scripts/files/adh.sh
source ${GITHUB_WORKSPACE}/scripts/files/openclash.sh
source ${GITHUB_WORKSPACE}/scripts/files/kodexplorer.sh
source ${GITHUB_WORKSPACE}/scripts/files/ipk.sh

# /tmp/resolv.conf.d/resolv.conf.auto
#echo nameserver 223.5.5.5 >> files/tmp/resolv.conf.d/resolv.conf.auto


# ---------- end -----------
