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


if [ "$repo_name" = 'lede' ];then
    # https://github.com/coolsnowwolf/lede/issues/9483
    # https://github.com/coolsnowwolf/lede/pull/9457/files#diff-38a2e413df332b2dd0c3651ef57bd9544c2224faa0bf9fb7712daf769e12fa67L449-L470
    # https://github.com/coolsnowwolf/lede/commit/ee7d9cff629778e16d1a34abc04ea3d6524d56bb#diff-38a2e413df332b2dd0c3651ef57bd9544c2224faa0bf9fb7712daf769e12fa67R470
    if [ "$kernel_ver" = '5.10' ] || [ "$kernel_ver" = '5.4' ];then
        sed -ri '/=CONFIG_CRYPTO_LIB_BLAKE2S/{n;s/HIDDEN:=1/DEPENDS:=@(LINUX_5_4||LINUX_5_10)/;}' package/kernel/linux/modules/crypto.mk
        for SED_NUM in $( grep -En 'blake2s(|-generic|-arm).ko' package/kernel/linux/modules/crypto.mk |  awk -F: '$0~":"{print $1}');do
            sed -ri "${SED_NUM}s#@lt5.9##" package/kernel/linux/modules/crypto.mk
        done
    fi

    # https://github.com/coolsnowwolf/lede/issues/9803
    # lede 暂时删掉 ath6kl ，原因是 https://github.com/coolsnowwolf/lede/commit/66d19a4e3673b30594b5de3b8d226160a0032af5 升级了 mac80211导致
    # 2022/08/05 可能要暂时屏蔽掉 5.15 5.19 内核
    # sed -ri '/^KERNEL_PATCHVER=/s#'"${kernel_ver}"'#5.4#' target/linux/rockchip/Makefile

    # #use latest driver of rtl8821CU
    # if [ -f package/kernel/rtl8821cu/Makefile ];then
    # sed -i 's/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=master/' package/kernel/rtl8821cu/Makefile
    # sed -i 's/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=skip/' package/kernel/rtl8821cu/Makefile
    # fi
fi

if echo "$repo_name" | grep -Pq 'DHDAXCW|lede' ;then
    kernel_ver=$(grep -Po '^KERNEL_PATCHVER=\K\S+' target/linux/rockchip/Makefile)
    if echo "$kernel_ver" | grep -Pq '5.1[589]';then
        sed -ri '/kmod-(ath6k|carl9170|libertas-usb|rsi91x|rt2.00-)/d' .config
    fi
fi


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
