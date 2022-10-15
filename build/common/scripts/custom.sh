#!/bin/bash

[ -e files ] && mv files openwrt/files
export CONFIG=${config}
\cp config/${CONFIG} openwrt/.config
echo "use the file: `md5sum config/${CONFIG}`"
cd openwrt
    if [ -f "$GITHUB_WORKSPACE/common/delete.list" ];then
    grep -Pv '^\s*#' $GITHUB_WORKSPACE/common/delete.list | while read dir;do
        echo "查找移除目录：$dir"
        find -name $dir -exec bash -c '[ -d {} ] && rm -rf {}' \; || true
    done
    fi

    if [ "$UdateFeeds" = true ];then
        bash -x ${GITHUB_WORKSPACE}/common/fix-feeds.sh

        # 添加的 feeds 应用包优先于自带的 feed 里的 app
        echo "重复的包检测：👇"
        ./scripts/feeds list  | awk '{if(a[$1]){print $1}else{a[$1]++}}'
        echo "重复的包检测：👆"
        ./scripts/feeds list  | awk '{if(a[$1]){print $1}else{a[$1]++}}' | while read pkg_name;do
            # 目录是 / 分隔，feeds/xxx/ 一样就不打印
            find feeds/ -maxdepth 4 -type d -name $pkg_name | \
            awk -F/ 'NR==1{a[$2]=$0};NR==2{if(!a[$2]){for(i in a){if(a[i]){printf "%s/ %s\n",$0,a[i]}}}}' | \
            xargs -r -n2 echo  👉 rsync -av --delete
            find feeds/ -maxdepth 4 -type d -name $pkg_name | \
            awk -F/ 'NR==1{a[$2]=$0};NR==2{if(!a[$2]){for(i in a){if(a[i]){printf "%s/ %s\n",$0,a[i]}}}}' | \
            xargs -r -n2 rsync -av --delete
        done
        # 更新包后，如果存在修改了依赖名字，需要删除某些索引后再更新
        cp .config /tmp/
        ./scripts/feeds update -i -f # 这步操作会类似 make defconfig 更改 .config 
        cat /tmp/.config > .config
        #./scripts/feeds install -a
fi
cd -

set -x

# feeds 后做些修改
pushd openwrt
echo "running $GITHUB_WORKSPACE/$DIY_P2_SH at ${PWD}, repo_name: ${repo_name}, build_target: ${build_target}"
bash -x ${GITHUB_WORKSPACE}/common/diy.sh
bash -x $GITHUB_WORKSPACE/$DIY_P2_SH
popd

# 有缓存存在才构建 imageBuilder，否则第一次生成缓存可能会很久甚至失败，此刻构建 imageBuilder 没有意义
if grep -Eq '^CONFIG_IB=y'  openwrt/.config;then
    export USED_CONFIG_IB=true
    echo 'USED_CONFIG_IB=true'  >> $GITHUB_ENV
    echo 'MAKE_OPTS=IGNORE_ERRORS=1' >> $GITHUB_ENV
    if [ "$CACHE" == true ];then
    # 缓存存在下，slim 和 full 版本的准备行为
        pushd openwrt
        sed_num=$( grep -n '$(TOPDIR)/.config' target/imagebuilder/Makefile | cut -d: -f1 )
        # hack imageBuilder 构建出来带 *.buildinfo 和 files/
        sed -ri ${sed_num}'{s#cp#& -a $(TOPDIR)/files $(TOPDIR)/*.buildinfo#;s#.config$##;}' target/imagebuilder/Makefile

        # 可能
        if true;then
            find package/ -type d -name luci-app-* | awk -F/ '{printf "CONFIG_PACKAGE_%s=m\n",$NF}' | sort >> app.config
            # TODO 查找更多的 app 包，但是不知道容量能撑住不 find  -type d -name luci-app-* | awk -F/ '!a[$NF]++{print $NF}'
            # find -type d -name luci-app-* | awk -F/ '!a[$NF]++{printf "CONFIG_PACKAGE_%s=m\n",$NF}'| sort >> .config
            # 主题不在 package 里，
            find feeds/ -type d -name luci-theme-* | awk -F/ '!a[$NF]++{printf "CONFIG_PACKAGE_%s=m\n",$NF}' | sort >> app.config
        fi

        # 去重，如果 make defconfig 时候.config 里不是后面值覆盖前面的值，那就需要提前删掉 .config 里的 luci-app* 
        find feeds -type d -name 'luci-app-*' | awk -F'/' '!a[$NF]++{print $NF}'  | \
            sort | xargs -n1 -i echo CONFIG_PACKAGE_{}=m >> app.config
        find feeds -type d -name 'luci-proto-*' | awk -F'/' '!a[$NF]++{print $NF}'  | \
            sort | xargs -n1 -i echo CONFIG_PACKAGE_{}=m >> app.config
        
        # 下面这样太多包参与编译了，action 会超时，只像上面开启 luci-app-*
        #sed -ri '/CONFIG_PACKAGE_[0-9a-z-]+(=| )/{s@^#\s+@@;s@(=y|\s+is not set)@=m@}' .config
        popd
    else
        true
        # 没缓存就不打包应用和驱动，这部是为了 x86，防止初次构建失败
        sed -ri '/luci-app-.+?=y/s#=y#=m#' openwrt/.config
        sed -ri '/_INCLUDE_/s#=m#=y#' openwrt/.config
        sed -ri '/^CONFIG_.+?-firmware-.+?=y/s#=y#=m#' openwrt/.config
    fi
else # 没开 imageBuilder 
    echo 'USED_CONFIG_IB=false'  >> $GITHUB_ENV
    echo 'MAKE_OPTS=' >> $GITHUB_ENV
fi

# common目录的 common docker last
cp common/*.buildinfo openwrt/
rm -f openwrt/disable.buildinfo
# ${target}/config/last.buildinfo 放最后面
[ -f config/last.buildinfo ] && cat config/last.buildinfo >> common/disable.buildinfo

[ "$EnableDocker" != 'true' ] && rm -f openwrt/docker.buildinfo
if [ "${EnableCommonBuildInfo:=true}" = true ];then
    cat openwrt/*.buildinfo >> openwrt/.config
else
    sed -i '1r openwrt/small.buildinfo' openwrt/.config
fi
# 最后写入 last，理论上能覆盖掉前面的一些开启
cat common/disable.buildinfo >> openwrt/.config
cp common/disable.buildinfo  openwrt/

# 保留一个原来副本，后续 full 使用
\cp config/${CONFIG} openwrt/config.buildinfo

if grep -Eq '^CONFIG_IB=y' openwrt/.config && [ "$CACHE" == true ];then
    \cp openwrt/.config openwrt/full.buildinfo
fi

pushd openwrt
[ -f app.config ] && cat app.config >> .config && rm -f app.config

grep -Eq '^CONFIG_IB=y' .config && sed -ri 's#(^CONFIG_PACKAGE_luci-app-[^A-Z]*=)y#\1m#' .config
sed -ri '/[-_]static=m/d' .config
sed -ri '/luci-app-.+?_dynamic=m/s#=m#=y#' .config

if [ "$repo_name" == 'immortalwrt' ];then
    # https://github.com/immortalwrt/immortalwrt/discussions/783
    if grep -Pq '^CONFIG_PACKAGE_ntfs-3g=y' .config;then
cat >> .config <<'EOF'
# CONFIG_PACKAGE_ntfs-3g is not set
# CONFIG_PACKAGE_ntfs-3g-utils is not set
CONFIG_PACKAGE_ntfs3-mount=y
EOF
    fi
fi

cp .config befor_defconfig.buildinfo
if ! make defconfig;then
    cat .config 
    exit 2
fi
sed -i -E 's/# (CONFIG_.*_COMPRESS_UPX) is not set/\1=y/' .config
if grep -Eq '^CONFIG_IB=y' .config;then
    # include 开启，可能有些是二选一，二选一得提前在 config.buildinfo 里开启
    sed -ri '/^#\s+CONFIG_PACKAGE_luci-app-\S+?_INCLUDE_/{s@^# @@;s#\sis not set#=y#}' .config
    grep -P 'CONFIG_PACKAGE_luci-app-\S+?_INCLUDE_' common.buildinfo >> .config
fi
make defconfig
