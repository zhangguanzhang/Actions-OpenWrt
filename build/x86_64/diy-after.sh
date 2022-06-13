#!/bin/bash

source $GITHUB_WORKSPACE/common/upload_docker_img.sh

# cd openwrt-imagebuilder-*/bin/targets/*/*
cd $FIRMWARE
rm -f *-rootfs*
rm -f *kernel.bin
