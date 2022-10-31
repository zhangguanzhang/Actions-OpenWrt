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

if [ -z "$kernel_ver" ];then
    pwd
    cat target/linux/rockchip/Makefile
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

    # https://github.com/coolsnowwolf/lede/issues/10359
    if [ -f package/kernel/rtl88x2bu/Makefile ];then
        rm -rf package/kernel/rtl88x2bu
    fi

    # use latest driver of rtl8821CU
    if [ -f package/kernel/rtl8821cu/Makefile ];then
        sed -i 's/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=master/' package/kernel/rtl8821cu/Makefile
        sed -i 's/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=skip/' package/kernel/rtl8821cu/Makefile
    fi

    # https://github.com/coolsnowwolf/lede/issues/9822
    if echo "$kernel_ver" | grep -Pq '5.1[89]'  && grep -Pq '^CONFIG_PACKAGE_kmod-gpu-lima=y' .config;then
        sed -ri '/^KERNEL_PATCHVER=/s#=5.[0-9]+$#=5.15#' target/linux/rockchip/Makefile
    fi
    # https://github.com/coolsnowwolf/lede/issues/9922
    sed -ri '/^\s*TARGET_DEVICES\s.+?(fastrhino_r66s|firefly_station-p2|friendlyelec_nanopi-r5s)/d' target/linux/rockchip/image/armv8.mk
fi

kernel_ver=$(grep -Po '^KERNEL_PATCHVER=\K\S+' target/linux/rockchip/Makefile)

if echo "$repo_name" | grep -Pq 'DHDAXCW|lede' ;then
    echo "firmware_wildcard=r4s,r4se" >> $GITHUB_ENV
    sed -ri '/friendlyarm_nanopi-r4s=y/d' .config
    sed -i "2r "<(
cat  <<'EOF' | sed -r 's#^\s+#\t#'
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_friendlyarm_nanopi-r4s=y
CONFIG_TARGET_DEVICE_rockchip_armv8_DEVICE_friendlyarm_nanopi-r4se=y
EOF
  ) .config
    true
fi

if echo "$repo_name" | grep -Pq 'DHDAXCW' &&  ! echo "$kernel_ver" | grep -Pq '5.15';then

# https://github.com/DHDAXCW/NanoPi-R4S-R4SE/commit/164571cbc87595293606cf370777eda2ca2c8a8d
# https://github.com/DHDAXCW/lede-rockchip/commit/baf932fd1d96a0bbfe5192974a034741d3448333#comments
    cat >> .config  <<'EOF'
# 开启GPU硬件 
CONFIG_PACKAGE_kmod-backlight=y
CONFIG_PACKAGE_kmod-backlight-pwm=y
CONFIG_PACKAGE_kmod-drm=y
CONFIG_PACKAGE_kmod-drm-display-helper=y
CONFIG_PACKAGE_kmod-drm-kms-helper=y
CONFIG_PACKAGE_kmod-drm-ttm=y
CONFIG_PACKAGE_kmod-fb=y
CONFIG_PACKAGE_kmod-fb-cfb-copyarea=y
CONFIG_PACKAGE_kmod-fb-cfb-fillrect=y
CONFIG_PACKAGE_kmod-fb-cfb-imgblt=y
CONFIG_PACKAGE_kmod-fb-sys-fops=y
CONFIG_PACKAGE_kmod-fb-sys-ram=y
CONFIG_PACKAGE_kmod-multimedia-input=y
CONFIG_PACKAGE_kmod-video-core=y
CONFIG_PACKAGE_kmod-drm-rockchip=y
EOF

fi

# https://github.com/coolsnowwolf/lede/pull/9059
# https://github.com/immortalwrt/immortalwrt/issues/735
# 只有lede 和骷髅头修复了这个问题，这里脚本用 lede 的
# 2022/09/01 https://github.com/coolsnowwolf/lede/commit/22d08ddd3d23e4ad3b98b943089d03af832c3022 然后又还原了
# 把 r4s 的无 eeprom mac 逻辑删除，从骷髅头的获取覆盖
if ! grep -Pq '/sys/bus/i2c/devices/2-0051/eeprom' target/linux/rockchip/armv8/base-files/etc/board.d/02_network;then
    curl -s https://raw.githubusercontent.com/DHDAXCW/lede-rockchip/d1599efbcf664e29dd23aebd72b6cd31887a7b7d/target/linux/rockchip/armv8/base-files/etc/board.d/02_network > target/linux/rockchip/armv8/base-files/etc/board.d/02_network
fi
mac_patch_file=$(grep -P '^\+\s+.+?\<&mac_address\>' target/linux/rockchip/patches-${kernel_ver}/* | cut -d ':' -f 1)
if [ -n "$mac_patch_file" ];then
    sed_num=$( grep -Pn '^\+\s+.+?\<&mac_address\>' $mac_patch_file | awk -F':' '{print $1-1}' )
    sed -ri "$sed_num,$[sed_num+3]s#^\+([^/])#+//\1#" $mac_patch_file
fi

if [ "$repo_name" != 'lede' ] && [ "$repo_name" != 'DHDAXCW' ];then
    # https://github.com/immortalwrt/immortalwrt/discussions/736
    if [ "$repo_branch" = 'openwrt-18.06-k5.4' ];then
        if [ -z "$(awk '/^CMAKE_HOST_OPTIONS/{flag=1}flag==1{if($0~"DFEATURE_glib=OFF"){print 1}}flag==1&&(flag==1)&&/^\s*$/{exit;}' ./feeds/packages/libs/qt6base/Makefile)" ];then
            sed -ri '/^CMAKE_HOST_OPTIONS/r '<(echo -e '\t-DFEATURE_glib=OFF \\') ./feeds/packages/libs/qt6base/Makefile
        fi

        # 天灵的 18.06 分支源码下，rootfs 得修改下
        rootfs_size=$( awk -F= '/^CONFIG_TARGET_ROOTFS_PARTSIZE/{print $2+24}' .config )
        if [ -n "$rootfs_size" ];then
            sed -ri '/^CONFIG_TARGET_ROOTFS_PARTSIZE=/s#=[0-9]+$#='"${rootfs_size}"'#' .config
        fi
    fi
    # 修复 openwrt r4s target 编译完成变成 r2s 的文件名
    # 2022/08/01 还是无法编译成功，懒得搞官方的了
    if [ "$repo_name" == 'openwrt' ];then
        if ! grep -Eq nanopi-r4s target/linux/rockchip/image/armv8.mk ;then
cat >> target/linux/rockchip/image/armv8.mk <<'EOF'

define Device/friendlyarm_nanopi-r4s
  DEVICE_VENDOR := FriendlyARM
  DEVICE_MODEL := NanoPi R4S
  DEVICE_VARIANT := 4GB LPDDR4
  SOC := rk3399
  UBOOT_DEVICE_NAME := nanopi-r4s-rk3399
  IMAGE/sysupgrade.img.gz := boot-common | boot-script nanopi-r4s | pine64-img | gzip | append-metadata
  DEVICE_PACKAGES := kmod-r8169
endef
TARGET_DEVICES += friendlyarm_nanopi-r4s

EOF
            svn export https://github.com/immortalwrt/immortalwrt/branches/${repo_branch}/package/boot/arm-trusted-firmware-rockchip-vendor \
                package/boot/arm-trusted-firmware-rockchip-vendor
            rm -rf package/boot/uboot-rockchip
            svn export https://github.com/immortalwrt/immortalwrt/branches/${repo_branch}/package/boot/uboot-rockchip \
                package/boot/uboot-rockchip
        fi
    fi
fi



# https://github.com/vernesong/OpenClash/issues/1930
# if [ -d feeds/others/luci-app-openclash ];then
#     sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' feeds/others/luci-app-openclash/root/etc/init.d/openclash
# fi



# merge_package "-b 18.06 https://github.com/jerrykuku/luci-theme-argon"
# merge_package "https://github.com/jerrykuku/luci-app-argon-config"

#svn co https://github.com/immortalwrt/luci/trunk/themes/luci-theme-argon ./package/lean/luci-theme-argon


# enable fan control
# git apply 报错
# wget https://github.com/friendlyarm/friendlywrt/commit/cebdc1f94dcd6363da3a5d7e1e69fd741b8b718e.patch
# git apply cebdc1f94dcd6363da3a5d7e1e69fd741b8b718e.patch
# rm cebdc1f94dcd6363da3a5d7e1e69fd741b8b718e.patch
# sed -i 's/pwmchip1/pwmchip0/' target/linux/rockchip/armv8/base-files/usr/bin/fa-fancontrol.sh target/linux/rockchip/armv8/base-files/usr/bin/fa-fancontrol-direct.sh



# https://github.com/NateLol/luci-app-oled/issues/21 解决中文问题
[ -d package/custom/luci-app-oled/po/zh_Hans ] && mv package/custom/luci-app-oled/po/zh_Hans package/custom/luci-app-oled/po/zh-cn



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
