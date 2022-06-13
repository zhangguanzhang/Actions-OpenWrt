#!/bin/bash

oldPATH=$(pwd)

sudo apt-get update && \
   sudo apt-get install -y  jq btrfs-progs dosfstools uuid-runtime parted gawk wget patch xz-utils

git clone --depth 1 https://github.com/unifreq/openwrt_packit /opt/openwrt_packit

mkdir -p /opt/kernel

cp bin/targets/*/*/openwrt-armvirt-64-default-rootfs.tar.gz /opt/openwrt_packit/

if [ -n "$n1_kernal" ];then
    export KERNEL_VERSION=$n1_kernal
fi

# fix https://github.com/unifreq/openwrt_packit/issues/31 https://github.com/zhangguanzhang/Actions-OpenWrt/issues/1
if [ -z "$KERNEL_VERSION" ];then
    grep -Po '^\s*\KKERNEL_VERSION=\S+' /opt/openwrt_packit/make.env > /tmp/make.env
    source /tmp/make.env
    DOWNLOAD_KERNEL_VERSION=$(curl -s  https://api.github.com/repos/breakings/OpenWrt/git/trees/main?recursive=1 | \
        jq -r '.tree[].path' | \
        grep -Pom1 "^opt/kernel/${KERNEL_VERSION%%-*}/boot-\K.+?(?=.tar.gz)")
    if [ -n "$DOWNLOAD_KERNEL_VERSION" ];then
        export KERNEL_VERSION="$DOWNLOAD_KERNEL_VERSION"
    else
        kernel_num=${KERNEL_VERSION%%-*} # 5.x.x
        kerrnel_major=${kernel_num%.*} #5.18 
        export KERNEL_VERSION=$(curl -s  https://api.github.com/repos/breakings/OpenWrt/git/trees/main?recursive=1 | \
        jq -r '.tree[].path' | \
        grep -Pom1 "^opt/kernel/${kerrnel_major}\.\d+/boot-\K.+?(?=.tar.gz)" )
    fi
fi
# 下面的 mk_s905d_n1.sh 里会执行 source 它
#source /opt/openwrt_packit/make.env

export kernel_URL=https://raw.githubusercontent.com/breakings/OpenWrt/main/opt/kernel

export kernel_VER=${KERNEL_VERSION%%-*} # 5.13.13
export KERNEL_VERSION=$KERNEL_VERSION
# KERNEL_VERSION="5.13.13-flippy-63+"
(
    cd /opt/kernel/
    wget ${kernel_URL}/${kernel_VER}/boot-${KERNEL_VERSION}.tar.gz
    wget ${kernel_URL}/${kernel_VER}/dtb-allwinner-${KERNEL_VERSION}.tar.gz
    wget ${kernel_URL}/${kernel_VER}/dtb-amlogic-${KERNEL_VERSION}.tar.gz
    wget ${kernel_URL}/${kernel_VER}/dtb-rockchip-${KERNEL_VERSION}.tar.gz
    wget ${kernel_URL}/${kernel_VER}/modules-${KERNEL_VERSION}.tar.gz
    cd /opt/openwrt_packit
    export ENABLE_WIFI_K510=1
    sudo -E ./mk_s905d_n1.sh 
    find -type f -size +100M -name 'openwrt*.img' -exec mv {} /opt/openwrt_packit/tmp/ \;
)

mv bin/targets/*/*/config.buildinfo /opt/openwrt_packit/tmp/

rm -f bin/targets/*/*/*
mv /opt/openwrt_packit/tmp/* bin/targets/*/*/
ls -lh bin/targets/*/*/


# docker run -tid --name test \
#     --device=/dev/loop-control:/dev/loop-control \
#     --device=/dev/loop0:/dev/loop0 \
#     --device=/dev/loop0p1:/dev/loop0p1 \
#     --device=/dev/loop0p2:/dev/loop0p2 \
#     -v $PWD/openwrt_packit:/opt/ --cap-add SYS_ADMIN ubuntu
