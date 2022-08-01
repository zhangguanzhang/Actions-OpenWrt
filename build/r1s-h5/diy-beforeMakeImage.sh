# #!/bin/bash

[ -z "$suffix" ] && source $GITHUB_ENV

# if [ "$repo_name" == 'openwrt' ] && [ "$repo_branch" == 'openwrt-21.02' ] && [ "$suffix" = '-full' ];then
if [ "$suffix" = '-full' ];then
    # full 版本加大一些容量
    # 参考 https://forum.openwrt.org/t/how-to-set-root-filesystem-partition-size-on-x86-imabebuilder/4765/4?u=zhangguanzhang
    rootfs_size=$( awk -F= '/^CONFIG_TARGET_ROOTFS_PARTSIZE/{print $2+93}' .config )
fi

if [ -n "$rootfs_size" ];then
    sed -ri '/^CONFIG_TARGET_ROOTFS_PARTSIZE=/s#=[0-9]+$#='"${rootfs_size}"'#' .config
fi
