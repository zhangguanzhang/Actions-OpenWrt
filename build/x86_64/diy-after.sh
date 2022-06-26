#!/bin/bash
exclude_str=vmdk
source $GITHUB_WORKSPACE/common/upload_docker_img.sh

# cd openwrt-imagebuilder-*/bin/targets/*/*
cd $FIRMWARE
rm -f *-rootfs*
rm -f *kernel.bin
