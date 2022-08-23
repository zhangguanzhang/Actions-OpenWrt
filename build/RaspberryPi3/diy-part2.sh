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

kernel_ver=$(grep -Po '^KERNEL_PATCHVER=\K\S+' target/linux/bcm27xx/Makefile)



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


# https://github.com/immortalwrt/immortalwrt/discussions/736
if [ "$repo_branch" = 'openwrt-18.06-k5.4' ];then
    # svn export https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent        ./feeds/packages/net/qBittorrent
    # svn export https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent-static ./feeds/packages/net/qBittorrent-static
    # merge_package https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent
    # merge_package https://github.com/coolsnowwolf/packages/trunk/net/qBittorrent-static
    # sed -ri '/^LUCI_DEPENDS/s#qBittorrent-Enhanced-Edition#qBittorrent#' ./feeds/luci/applications/luci-app-qbittorrent/Makefile
    if [ -z "$(awk '/^CMAKE_HOST_OPTIONS/{flag=1}flag==1{if($0~"DFEATURE_glib=OFF"){print 1}}flag==1&&(flag==1)&&/^\s*$/{exit;}' ./feeds/packages/libs/qt6base/Makefile)" ];then
        sed -ri '/^CMAKE_HOST_OPTIONS/r '<(echo -e '\t-DFEATURE_glib=OFF \\') ./feeds/packages/libs/qt6base/Makefile
    fi
#     rm -rf ./feeds/routing/cjdns \
#         ./feeds/routing/luci-app-cjdns \
#         ./package/feeds/routing/cjdns \
#         ./package/feeds/routing/luci-app-cjdns
#     cat >> .config <<'EOF'

# # CONFIG_PACKAGE_luci-app-cjdns is not set

# EOF
fi

# https://github.com/SuLingGG/OpenWrt-Rpi/blob/31c574d043d65328d6c8d7fb9cab388941336445/.github/workflows/bcm27xx-bcm2711.yml#L297
echo -e "CONFIG_USB_LAN78XX=y\nCONFIG_USB_NET_DRIVERS=y" >> target/linux/bcm27xx/bcm2711/config-5.4
sed -i 's/36/44/g;s/VHT80/VHT20/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# https://github.com/SuLingGG/OpenWrt-Rpi/blob/31c574d043d65328d6c8d7fb9cab388941336445/scripts/custom.sh#L15
# Fix mt76 wireless driver
pushd package/kernel/mt76
sed -i '/mt7662u_rom_patch.bin/a\\techo mt76-usb disable_usb_sg=1 > $\(1\)\/etc\/modules.d\/mt76-usb' Makefile
popd

# merge_package "-b 18.06 https://github.com/jerrykuku/luci-theme-argon"
# merge_package "https://github.com/jerrykuku/luci-app-argon-config"


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
