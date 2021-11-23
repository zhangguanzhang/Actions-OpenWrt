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

# 取消默认的 autosamba 依赖的 luci-app-samba 到 slim 里
find  ./target/linux/ -maxdepth 2 -type f  -name Makefile -exec sed -i 's#autosamba##' {} \;

# ---- 前的行写入文件
sed -n '/---/{q};p' common.buildinfo >> .config

# https://github.com/coolsnowwolf/packages/issues/352
rm -f feeds/packages/utils/dockerd/files{/etc/config/dockerd,/etc/docker/daemon.json,/etc/init.d/dockerd}
SED_NUM=$( grep -n '^\s*/etc/config/dockerd' feeds/packages/utils/dockerd/Makefile | awk -F: '$0~":"{print $1}')
if [ -n "$SED_NUM" ];then
    sed -ri "$[SED_NUM-1],$[SED_NUM+1]d" feeds/packages/utils/dockerd/Makefile
fi
sed -ri '\%/files/(daemon.json|dockerd.init|etc/config/dockerd)%d' feeds/packages/utils/dockerd/Makefile
sed -ri '\%\$\(INSTALL_DIR\) \$\(1\)/etc/(docker|init\.d|config)%d' feeds/packages/utils/dockerd/Makefile

# https://github.com/vernesong/OpenClash/issues/1930
# if [ -d feeds/others/luci-app-openclash ];then
#     sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' feeds/others/luci-app-openclash/root/etc/init.d/openclash
# fi

# Modify default theme
# https://github.com/jerrykuku/luci-theme-argon/tree/18.06
# https://github.com/kenzok8/openwrt-packages
sed -ri 's/luci-theme-\S+/luci-theme-argon/g' feeds/luci/collections/luci/Makefile  # feeds/luci/modules/luci-base/root/etc/config/luci
rm -rf ./package/lean/luci-theme-argon
mkdir -p package/community
pushd package/community
git clone --depth=1 -b 18.06 https://github.com/jerrykuku/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config
popd
#svn co https://github.com/immortalwrt/luci/trunk/themes/luci-theme-argon ./package/lean/luci-theme-argon

# https://github.com/openwrt/luci/issues/5638
[ -d package/lean/luci-app-filetransfer ] && sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' package/lean/luci-app-filetransfer/root/etc/uci-defaults/luci-filetransfer

#[ -f ./feeds/others/luci-theme-argonne/Makefile ] && sed -i '/LUCI_DEPENDS/s#=#&+libc#' ./feeds/others/luci-theme-argonne/Makefile
if [ -f ./feeds/others/luci-theme-argonne/Makefile ];then
    SED_NUM=$( grep -Pn '^\s*define\s+Package/\S+/postinst' ./feeds/others/luci-theme-argonne/Makefile |  awk -F: '$0~":"{print $1}')
    if [ -n "SED_NUM" ];then
        sed -i "$[SED_NUM+2]i [ ! -f /etc/openwrt_release ] && exit 0" ./feeds/others/luci-theme-argonne/Makefile
    fi
fi

# luci-theme-atmaterial_new
# https://github.com/kenzok8/openwrt-packages 已经添加了，所以这里备用拉取
if [ ! -d feeds/others/luci-theme-atmaterial_new ];then
    git clone -b main --depth 1 https://github.com/Chandler-Lu/openwrt-package /tmp/openwrt-package
    if [ -d '/tmp/openwrt-package/luci-theme-atmaterial_new' ];then
        mv /tmp/openwrt-package/luci-theme-atmaterial_new feeds/others/
    fi
fi

# unblockneteasemusic 的 状态判断是 exec 调用 ps 命令，它没适配 proc-ng-ps 命令会影响 
lua_file=`find -type f -name unblockneteasemusic.lua`
[ -n "$lua_file" ] && sed -ri '/sys.call.+ps /s#ps -w#ps aux#' $lua_file

# ----------- 提前打包一些文件，防止初次使用去下载
# files下会合并到最终的 rootfs 里
mkdir -p files/
# 初次开机设置脚本
mkdir -p files/etc/uci-defaults/
cp ${GITHUB_WORKSPACE}/scripts/uci-defaults/* files/etc/uci-defaults/
chmod a+x files/etc/uci-defaults/*

mkdir -p files/root/
echo 'set paste' >> files/root/.vimrc

# 预处理下载相关文件，保证打包固件不用单独下载
# source ${GITHUB_WORKSPACE}/scripts/files/adh.sh
# source ${GITHUB_WORKSPACE}/scripts/files/openclash.sh
# source ${GITHUB_WORKSPACE}/scripts/files/pwmfan.sh

for sh_file in `ls ${GITHUB_WORKSPACE}/scripts/files/*.sh`;do
    source $sh_file
done


chmod a+x ${GITHUB_WORKSPACE}/build/scripts/*.sh
\cp -a ${GITHUB_WORKSPACE}/build/scripts/update.sh files/

# 修改banner
echo -e " built on "$(TZ=Asia/Shanghai date '+%Y.%m.%d %H:%M') - ${GITHUB_RUN_NUMBER}"\n -----------------------------------------------------" >> package/base-files/files/etc/banner

# /tmp/resolv.conf.d/resolv.conf.auto
# mkdir -p files/tmp/resolv.conf.d/
# echo nameserver 223.5.5.5 >> files/tmp/resolv.conf.d/resolv.conf.auto


# ---------- end -----------


# https://github.com/coolsnowwolf/lede/issues/8423
# https://github.com/coolsnowwolf/packages/pull/315 回退后删掉这三行
sed -i 's/^\s*$[(]call\sEnsureVendoredVersion/#&/' feeds/packages/utils/dockerd/Makefile
