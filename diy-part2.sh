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
sed -i 's/luci-theme-bootstrap/luci-theme-ifit/g' feeds/luci/collections/luci/Makefile

# luci-theme-atmaterial_new
git clone -b main --depth 1 https://github.com/Chandler-Lu/openwrt-package /tmp/openwrt-package
if [ -d '/tmp/openwrt-package/luci-theme-atmaterial_new' ];then
    mv /tmp/openwrt-package/luci-theme-atmaterial_new package/new/
    echo 'CONFIG_PACKAGE_luci-theme-atmaterial_new=y' >> ${CUSTOME_CONFIG}
fi
