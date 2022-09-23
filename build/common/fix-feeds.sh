#!/bin/bash

# 此脚本工作目录就是 op 的目录，此脚本用于搞一些公共操作，预处理一些包的历史问题

[ -f "$GITHUB_ENV" ] && source $GITHUB_ENV

[ "$return_fix_feeds" = true ] && exit 0

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

# https://github.com/kenzok8/openwrt-packages/issues/308
# https://github.com/QiuSimons/openwrt-mos/issues/126#issuecomment-1170739004
#find -type f -name Makefile -exec sed -ri  's#mosdns[-_]neo#mosdns#g' {} \;
# [ -d ./feeds/others/luci-app-mosdns ] && \
#     svn export --force https://github.com/sbwml/luci-app-mosdns/trunk/luci-app-mosdns ./feeds/others/luci-app-mosdns
# [ -d ./feeds/others/mosdns ] && \
#     svn export --force https://github.com/sbwml/luci-app-mosdns/trunk/mosdns ./feeds/others/mosdns

# rm -f ./tmp/info/.packageinfo-*mosdns

# [ -d ./feeds/small/v2ray-geodata ] && \
# svn co --force https://github.com/sbwml/v2ray-geodata/trunk ./feeds/small/v2ray-geodata

if [ "$repo_name" = 'lede' ] || [ "$repo_branch" = 'openwrt-18.06-k5.4' ] || echo "$repo_name" | grep -Pq '^DHDAXCW' ;then
    # https://github.com/coolsnowwolf/routing/issues/1
    # https://github.com/openwrt/routing/issues/882
    # if grep -qP '^PKG_VERSION:=v21$' ./feeds/routing/cjdns/Makefile;then
    #     rm -rf ./feeds/routing/cjdns
    #     svn export https://github.com/openwrt/routing/trunk/cjdns ./feeds/routing/cjdns
    # fi
    rm -rf ./feeds/routing/cjdns
    svn export https://github.com/openwrt/routing/branches/openwrt-21.02/cjdns ./feeds/routing/cjdns

fi

# https://github.com/kenzok8/luci-theme-ifit/issues/1
# ifit 主题不支持 21 分支
if echo $repo_branch | grep -Pq '^(openwrt-)?2[1-4]\.0';then
    pushd ./feeds/others/
    rm -rf luci-theme-ifit \
        luci-theme-atmaterial_new \
        luci-theme-mcat \
        luci-theme-neobird \
        luci-theme-tomato
    popd
    if [ -d ./tmp/info/ ];then
        pushd ./tmp/info/
            rm -f .packageinfo-*luci-theme-ifit \
                .packageinfo-*luci-theme-atmaterial_new \
                .packageinfo-*luci-theme-mcat \
                .packageinfo-*luci-theme-neobird \
                .packageinfo-*luci-theme-tomato
        popd
    fi
fi

# mosdns adguardhome 必须 1.18 的 golang编译，openwrt 21 分支的 golang 版本是 1.17
if [ "$repo_name" = 'openwrt' ] && [ "$repo_branch" = 'openwrt-21.02' ];then
    rm -rf feeds/packages/lang/golang/
    svn export https://github.com/immortalwrt/packages/branches/openwrt-21.02/lang/golang   feeds/packages/lang/golang
fi

# 修复 imageBuilder 打包 某些服务的时候/etc/init.d/x 的 uci 错误
function fix_uci_err(){
    file=$1
    if [ -f "${file}" ];then
        sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' "${file}"
    fi
}
fix_uci_err feeds/packages/net/ntpd/files/ntpdate.init
fix_uci_err ./feeds/others/filebrowser/files/filebrowser.init

# https://github.com/coolsnowwolf/luci/issues/127
fix_uci_err package/lean/luci-app-filetransfer/root/etc/uci-defaults/luci-filetransfer
fix_uci_err feeds/luci/applications/luci-app-unblockmusic/root/etc/init.d/unblockmusic
fix_uci_err ./feeds/others/luci-app-argonne-config/root/etc/uci-defaults/luci-argonne-config
fix_uci_err ./feeds/others/luci-theme-argonne/root/etc/uci-defaults/90_luci-theme-argonne

# mksquashfs 工具 segment fault
# https://github.com/plougher/squashfs-tools/issues/190
if [ -d feeds/packages/utils/squashfs-tools ] && grep -Pq '^PKG_VERSION:=4.5.1' feeds/packages/utils/squashfs-tools/Makefile;then
    curl -sL https://raw.githubusercontent.com/coolsnowwolf/packages/caad6dedd4a029d10c6e75281e6e6e31d8d74eaf/utils/squashfs-tools/Makefile > feeds/packages/utils/squashfs-tools/Makefile
fi

# 'package/feeds/others/luci-app-unblockneteasemusic/Makefile' has a dependency on 'ucode'
[ ! -d package/utils/ucode ] && svn export https://github.com/coolsnowwolf/lede/trunk/package/utils/ucode  package/utils/ucode

if [ "$repo_name" = 'lede' ];then

    if grep -Eq '^CONFIG_IB=y' .config;then
        # https://github.com/coolsnowwolf/packages/issues/352
        rm -rf ./feeds/luci/applications/luci-app-docker
    fi
fi


#[ -f ./feeds/others/luci-theme-argonne/Makefile ] && sed -i '/LUCI_DEPENDS/s#=#&+libc#' ./feeds/others/luci-theme-argonne/Makefile
if [ -f ./feeds/others/luci-theme-argonne/Makefile ];then
    SED_NUM=$( grep -Pn '^\s*define\s+Package/\S+/postinst' ./feeds/others/luci-theme-argonne/Makefile |  awk -F: '$0~":"{print $1}')
    if [ -n "SED_NUM" ];then
        sed -i "$[SED_NUM+2]i [ ! -f /etc/openwrt_release ] && exit 0" ./feeds/others/luci-theme-argonne/Makefile
    fi
fi


if [ "$repo_name" != 'immortalwrt' ];then
    # 注意有些应用的是相对路径 include ../../luci.mk
    # 后续可以
    # find package/ -type f -name Makefile -path '*/luci-app-*/Makefile' -exec sed -ri 's#../../luci.mk#$(TOPDIR)/feeds/luci/luci.mk#' \;
    svn co https://github.com/immortalwrt/luci/trunk/applications/luci-app-gowebdav package/custom/luci-app-gowebdav
    sed -ri '/^include\s.+?\/luci.mk/c include $(TOPDIR)/feeds/luci/luci.mk' package/custom/luci-app-gowebdav/Makefile
    svn co https://github.com/immortalwrt/packages/trunk/net/gowebdav package/custom/gowebdav
    sed -ri 's#../../lang/golang/golang-package.mk$#$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk#' package/custom/gowebdav/Makefile
fi

if [ "$repo_name" = 'lede' ] || echo "$repo_name" | grep -Pq '^DHDAXCW' ;then
    # https://github.com/coolsnowwolf/lede/issues/10126
    if ! grep -Pq 'no-address-of-packed-member' package/network/utils/umbim/Makefile;then
        sed_num=$(awk '/^TARGET_CFLAGS/{print NR+1}' package/network/utils/umbim/Makefile)
        sed -ri "$sed_num"'s#$# -Wno-address-of-packed-member#' package/network/utils/umbim/Makefile
    fi
    # https://github.com/coolsnowwolf/lede/issues/10161
    sed -i 's/-fno-rtti/-fno-rtti -std=c++14/g' package/network/services/e2guardian/Makefile

    # https://github.com/coolsnowwolf/lede/issues/10195
    sed -ri '/^PKG_SOURCE_URL:=/s#=.+$#=https://sources.openwrt.org/#' ./feeds/packages/utils/jq/Makefile
    grep PKG_HASH ./feeds/packages/utils/jq/Makefile
fi
