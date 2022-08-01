#!/bin/bash

[ -z "$suffix" ] && source $GITHUB_ENV

# lede 的没开 ext4 的 img 文件生成，所以不需要这里增加容量

if [ "$repo_name" == 'openwrt' ] && [ "$repo_branch" == 'openwrt-21.02' ] && [ "$suffix" = '-full' ];then
    # full 版本加大一些容量
    # 参考 https://forum.openwrt.org/t/how-to-set-root-filesystem-partition-size-on-x86-imabebuilder/4765/4?u=zhangguanzhang
    # 其实 670 + 60 多 squashfs 的就可以，但是 ext4 的 blocksize 是 4096 ，这俩格式又是一起打包的，这里测了下要 800 多M
    rootfs_size=$( awk -F= '/^CONFIG_TARGET_ROOTFS_PARTSIZE/{print $2+138}' .config )
    if [ -n "$rootfs_size" ];then
        sed -ri '/^CONFIG_TARGET_ROOTFS_PARTSIZE=/s#=[0-9]+$#='"${rootfs_size}"'#' .config
    fi
fi
