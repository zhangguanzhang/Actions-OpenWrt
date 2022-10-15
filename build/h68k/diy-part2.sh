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

[ -f "$GITHUB_ENV" ] && source $GITHUB_ENV

kernel_ver=$(grep -Po '^KERNEL_PATCHVER=\K\S+' target/linux/rockchip/Makefile)

if [ "$build_target" = r2s ];then
    # dmc 调频，开了让跑满千兆
    if ls -l ./target/linux/rockchip/patches-${kernel_ver}/*nanopi-r2s*-dmc-*.patch 2>/dev/null;then
        sed -ri '/auto-freq-en/s#0#1#' ./target/linux/rockchip/patches-${kernel_ver}/*nanopi-r2s*-dmc-*.patch
    fi
fi


function merge_package(){
    local pn=$1
    # 删掉/和它左边，只保留名字
    pn=${pn##*/}
    find package/ -follow -name $pn -not -path "package/custom/*" | xargs -rt rm -rf
    if [ ! -z "$2" ]; then
        find package/ -follow -name $2 -not -path "package/custom/*" | xargs -rt rm -rf
    fi

    if [[ $1 == *'/trunk/'* || $1 == *'/branches/'* ]]; then
        svn export $1
    else
        git clone --depth=1 --single-branch $3 $1
        rm -rf $pn/.git
    fi
    mv $pn package/custom/
}



rm -rf package/custom; mkdir package/custom

# 2022/10/18 lede 的固件貌似不区分 h68k-a -c啥的
if grep -Pq 'hinlink_opc-h68k-a' target/linux/rockchip/image/armv8.mk;then
    sed -i "2r "<(
cat  <<'EOF' | sed -r 's#^\s+#\t#'
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_opc-h68k-a=y
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_opc-h68k-c=y
EOF
  ) .config
else
    sed -i "2r "<(
cat  <<'EOF' | sed -r 's#^\s+#\t#'
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_hinlink_opc-h68k=y
EOF
  ) .config
  if [  -n "$GITHUB_ENV" ];then
    echo 'firmware_wildcard=h68k' >> $GITHUB_ENV
  fi
fi

if [ "$repo_name" = 'DHDAXCW' ];then
    # 暂时屏蔽 5.19内核
    sed -ri '/^KERNEL_PATCHVER=/s#'"${kernel_ver}"'#5.4#' target/linux/rockchip/Makefile
fi

if echo "$repo_name" | grep -Pq 'DHDAXCW|lede' ;then
    mkdir -p target/linux/rockchip/files-5.4/arch/arm64/boot/dts/rockchip/
    \cp target/linux/rockchip/files-5.19/arch/arm64/boot/dts/rockchip/*h68k* target/linux/rockchip/files-5.4/arch/arm64/boot/dts/rockchip/
    \cp target/linux/rockchip/files-5.19/arch/arm64/boot/dts/rockchip/*h68k* target/linux/rockchip/files-5.10/arch/arm64/boot/dts/rockchip/
    \cp target/linux/rockchip/files-5.19/arch/arm64/boot/dts/rockchip/*h68k* target/linux/rockchip/files-5.15/arch/arm64/boot/dts/rockchip/
    kernel_ver=$(grep -Po '^KERNEL_PATCHVER=\K\S+' target/linux/rockchip/Makefile)
    if echo "$kernel_ver" | grep -Pq '5.1[589]';then
        sed -ri '/kmod-(ath6k|carl9170|libertas-usb|rsi91x|rt2.00-)/d' .config
    fi
    sed -ri '/ath11k\/ath11k.ko/s#ath11k.ko$#ath11k.ko@ge5.19#' package/kernel/mac80211/ath.mk

fi

# enable fan control
# git apply 报错
# wget https://github.com/friendlyarm/friendlywrt/commit/cebdc1f94dcd6363da3a5d7e1e69fd741b8b718e.patch
# git apply cebdc1f94dcd6363da3a5d7e1e69fd741b8b718e.patch
# rm cebdc1f94dcd6363da3a5d7e1e69fd741b8b718e.patch
# sed -i 's/pwmchip1/pwmchip0/' target/linux/rockchip/armv8/base-files/usr/bin/fa-fancontrol.sh target/linux/rockchip/armv8/base-files/usr/bin/fa-fancontrol-direct.sh



# unblockneteasemusic 的 状态判断是 exec 调用 ps 命令，它没适配 proc-ng-ps 命令会影响 
# lua_file=`find -type f -name unblockneteasemusic.lua`
# [ -n "$lua_file" ] && sed -ri '/sys.call.+"ps /s#ps -w#ps aux#' $lua_file

# ----------- 提前打包一些文件，防止初次使用去下载
# files下会合并到最终的 rootfs 里
mkdir -p files/
# 初次开机设置脚本
mkdir -p files/etc/uci-defaults/
cp ${GITHUB_WORKSPACE}/scripts/uci-defaults/* files/etc/uci-defaults/
chmod a+x files/etc/uci-defaults/*


# 预处理下载相关文件，保证打包固件不用单独下载
# source ${GITHUB_WORKSPACE}/scripts/files/adh.sh
# source ${GITHUB_WORKSPACE}/scripts/files/openclash.sh
# source ${GITHUB_WORKSPACE}/scripts/files/pwmfan.sh

for sh_file in `ls ${GITHUB_WORKSPACE}/scripts/files/*.sh`;do
    source $sh_file
done


chmod a+x ${GITHUB_WORKSPACE}/build/scripts/*.sh
# 放入升级脚本
\cp -a ${GITHUB_WORKSPACE}/build/scripts/update.sh files/



# ---------- end -----------
