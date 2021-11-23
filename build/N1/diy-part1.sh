#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

#sed -i 's/192.168.1.1/192.168.100.254/g' package/base-files/files/bin/config_generate
sed -i "s/timezone='UTC'/timezone='CST-8'/" package/base-files/files/bin/config_generate
sed -i "/timezone='CST-8'/a \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default


echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
echo "src-git others https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default


# Change default shell to bash
sed -i 's/\/bin\/ash/\/bin\/bash/g' package/base-files/files/etc/passwd


# package/base-files/files/etc/init.d/boot
# N1 安装到 emcc 打包的启动不执行初始化
# install-to-emmc.sh install.sh

SED_NUM=$(grep -nw 'for file in $files; do' package/base-files/files/etc/init.d/boot  | cut -d: -f1)

echo '\t\t[ "$file" == 99-default.sh ] && [[ -f install*sh ]] && continue ' > /tmp/sed.file
sed -i "${SED_NUM}r /tmp/sed.file" package/base-files/files/etc/init.d/boot
# 99-default.sh 在有写入 emcc 脚本的时候不执行