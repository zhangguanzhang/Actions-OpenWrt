#!/bin/bash

# 此脚本工作目录就是 op 的目录，此脚本用于搞一些公共 diy-part2.sh
# 这里添加的一些包，也适用于 非 updateFeeds 的

[ -f "$GITHUB_ENV" ] && source $GITHUB_ENV

[ "$return_common_diy" = true ] && exit 0

# fix bios boot partition is under 1 MiB
sed -i 's/256/1024/g' target/linux/x86/image/Makefile

# 取消默认的 autosamba 依赖的 luci-app-samba 到 slim 里
find  ./target/linux/ -maxdepth 2 -type f  -name Makefile -exec sed -i 's#autosamba##' {} \;
if grep -Eq '^CONFIG_IB=y'  .config;then
    echo 'CONFIG_PACKAGE_autosamba=m' >> .config
else
    echo 'CONFIG_PACKAGE_autosamba=y' >> .config
fi


# openwrt 的目录里没这目录
# https://github.com/coolsnowwolf/lede/issues/3462
[ ! -d tools/upx ] && svn export https://github.com/coolsnowwolf/lede/trunk/tools/upx   tools/upx
[ ! -d tools/ucl ] && svn export https://github.com/coolsnowwolf/lede/trunk/tools/ucl   tools/ucl
if ! grep -q upx tools/Makefile;then
    SED_NUM=$(awk '$1=="tools-y"{a=NR}$1~/tools-\$/{print a;exit}' tools/Makefile)
    sed -ri "${SED_NUM}a tools-y += ucl upx" tools/Makefile
    sed -ri '/dependencies/a $(curdir)/upx/compile := $(curdir)/ucl/compile' tools/Makefile
fi

# Modify default theme
# https://github.com/jerrykuku/luci-theme-argon/tree/18.06
# https://github.com/kenzok8/openwrt-packages
if [ "$repo_name" = 'lede' ];then
    if grep -Eq '^CONFIG_IB=y'  .config;then
        sed -ri 's/luci-theme-\S+/luci-theme-argonne/g' feeds/luci/collections/luci/Makefile  # feeds/luci/modules/luci-base/root/etc/config/luci
        # https://github.com/coolsnowwolf/packages/issues/352
        rm -rf ./feeds/luci/applications/luci-app-docker
    fi
fi

if [ "$repo_name" = 'openwrt' ] || [ "$repo_name" = 'immortalwrt' ];then
    # rm -rf package/network/services/dnsmasq
    # svn export https://github.com/coolsnowwolf/lede/trunk/package/network/services/dnsmasq package/network/services/dnsmasq
    # # openwrt 编译会默认打开 dnsmasq，而我的 .config 里会把 dnsmasq-full 打开
    if grep -Eq '^CONFIG_IB=y' .config;then
        sed -ri 's/dnsmasq\s/dnsmasq-full /' include/target.mk
        cat >>.config << 'EOF'
# CONFIG_PACKAGE_dnsmasq is not set' >> 
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y

EOF
    fi

    # 天灵的非18.06 分支，openwrt 的 21.02 22.03 必须 luci-theme-argon 这种 21 分支的主题
    # argonne 是 18.06 分支使用
    if echo $repo_branch | grep -Pq '18\.0';then
        sed -ri 's/luci-theme-\S+/luci-theme-argonne/g' feeds/luci/collections/luci/Makefile
        sed -i 's/argon=y/argonne=y/' .config
        find -type d -regex '.*/luci-[a-z]+-argon' -exec rm -rf {} \;
    else
        # 
        sed -ri 's/luci-theme-\S+/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
        sed -i 's/argonne=y/argon=y/' .config
        # 这个不兼容 openwrt 
        find -type d -name 'luci-*-argonne*' -exec rm -rf {} \;
    fi
    sed -i 's/\+IPV6:luci-proto-ipv6//' feeds/luci/collections/luci/Makefile
    if [ "$repo_name" != 'immortalwrt' ];then
        svn export --force https://github.com/immortalwrt/immortalwrt/trunk/package/emortal/autocore   package/emortal/autocore
        svn export --force https://github.com/immortalwrt/immortalwrt/trunk/package/emortal/ipv6-helper   package/emortal/ipv6-helper
    fi
    cat > package/base-files/files/etc/uci-defaults/zzz-default-settings <<'EOF'
# 默认密码 password
# sed -i 's/root::0:0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' /etc/shadow
sed -i '/^root::/c root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::' /etc/shadow
EOF
    echo 'CONFIG_LUCI_LANG_zh_Hans=y' >> .config

fi

mkdir -p files/root/
echo 'set paste' >> files/root/.vimrc

# 修改banner
echo -e " zgz built on "$(TZ=Asia/Shanghai date '+%Y.%m.%d %H:%M') - ${GITHUB_RUN_NUMBER}"\n -----------------------------------------------------" >> package/base-files/files/etc/banner
# 天灵修改banner
if [ -n "$default_banner_file" ];then
    echo -e " zgz built on "$(TZ=Asia/Shanghai date '+%Y.%m.%d %H:%M') - ${GITHUB_RUN_NUMBER}"\n -----------------------------------------------------" >> $default_banner_file
fi
