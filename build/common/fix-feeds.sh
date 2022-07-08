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
[ -d ./feeds/others/luci-app-mosdns ] && \
    svn export --force https://github.com/sbwml/luci-app-mosdns/trunk/luci-app-mosdns ./feeds/others/luci-app-mosdns
[ -d ./feeds/others/mosdns ] && \
    svn export --force https://github.com/sbwml/luci-app-mosdns/trunk/mosdns ./feeds/others/mosdns

rm -f ./tmp/info/.packageinfo-*mosdns

# [ -d ./feeds/small/v2ray-geodata ] && \
# svn co --force https://github.com/sbwml/v2ray-geodata/trunk ./feeds/small/v2ray-geodata

if [ "$repo_name" = 'lede' ] || [ "$repo_branch" = 'openwrt-18.06-k5.4' ];then
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
                .packageinfo-*luci-theme-tomato \
        popd
    fi
fi

# https://github.com/coolsnowwolf/luci/issues/127
[ -d package/lean/luci-app-filetransfer ] && sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' package/lean/luci-app-filetransfer/root/etc/uci-defaults/luci-filetransfer
[ -f feeds/luci/applications/luci-app-unblockmusic/root/etc/init.d/unblockmusic ] && \
    sed -i '1a [ ! -f /etc/openwrt_release ] && exit 0' feeds/luci/applications/luci-app-unblockmusic/root/etc/init.d/unblockmusic
[ -f ./feeds/others/luci-app-argonne-config/root/etc/uci-defaults/luci-argonne-config ] && \
    sed -i '1a [ ! -f /etc/openwrt_release ] && exit 0' ./feeds/others/luci-app-argonne-config/root/etc/uci-defaults/luci-argonne-config
[ -f ./feeds/others/luci-theme-argonne/root/etc/uci-defaults/90_luci-theme-argonne ] && \
    sed -i '1a [ ! -f /etc/openwrt_release ] && exit 0'  ./feeds/others/luci-theme-argonne/root/etc/uci-defaults/90_luci-theme-argonne

# mksquashfs 工具 segment fault
# https://github.com/plougher/squashfs-tools/issues/190
if [ -d feeds/packages/utils/squashfs-tools ];then
    curl -sL https://raw.githubusercontent.com/coolsnowwolf/packages/caad6dedd4a029d10c6e75281e6e6e31d8d74eaf/utils/squashfs-tools/Makefile > feeds/packages/utils/squashfs-tools/Makefile
fi

# 'package/feeds/others/luci-app-unblockneteasemusic/Makefile' has a dependency on 'ucode'
[ ! -d package/utils/ucode ] && svn export https://github.com/coolsnowwolf/lede/trunk/package/utils/ucode  package/utils/ucode

if [ "$repo_name" = 'lede' ] && grep -Eq '^CONFIG_IB=y' .config;then
    # https://github.com/coolsnowwolf/packages/issues/352
    rm -rf ./feeds/luci/applications/luci-app-docker
fi

# 修复 imageBuilder 打包 ntpdate 的 uci 错误
if [ -f feeds/packages/net/ntpd/files/ntpdate.init ];then
    sed -i '2a [ ! -f /etc/openwrt_release ] && exit 0' feeds/packages/net/ntpd/files/ntpdate.init
fi

#[ -f ./feeds/others/luci-theme-argonne/Makefile ] && sed -i '/LUCI_DEPENDS/s#=#&+libc#' ./feeds/others/luci-theme-argonne/Makefile
if [ -f ./feeds/others/luci-theme-argonne/Makefile ];then
    SED_NUM=$( grep -Pn '^\s*define\s+Package/\S+/postinst' ./feeds/others/luci-theme-argonne/Makefile |  awk -F: '$0~":"{print $1}')
    if [ -n "SED_NUM" ];then
        sed -i "$[SED_NUM+2]i [ ! -f /etc/openwrt_release ] && exit 0" ./feeds/others/luci-theme-argonne/Makefile
    fi
fi


if [ "$repo_name" != 'immortalwrt' ];then
    svn co https://github.com/immortalwrt/luci/trunk/applications/luci-app-gowebdav luci/applications/luci-app-gowebdav
    svn co https://github.com/immortalwrt/packages/trunk/net/gowebdav packages/net/gowebdav
fi
