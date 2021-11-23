#!/bin/bash

function upload_dockerhub(){

    local hub_img=zhangguanzhang/r2s BUILD_DIR=$(mktemp -d)
    local BRANCH=${GITHUB_REF##*/}
    local file=$1
    local tag=release-$(date +%Y-%m-%d)
    local FSTYPE=${file##*r2s-}
    FSTYPE=${FSTYPE%-*}

    cp $1 ${BUILD_DIR}/
    cp $(dirname $1)/{sha256sums,config.buildinfo,feeds.buildinfo,version.buildinfo} ${BUILD_DIR}/
cat >${BUILD_DIR}/Dockerfile << EOF
FROM alpine
COPY * /
EOF
    [ "${BRANCH}" != main ] && tag=latest

    local build_img=${hub_img}:${tag}-${FSTYPE}

    (
        cd ${BUILD_DIR}
        echo docker buildx build --platform linux/arm64  -t ${build_img} --push .
        docker buildx build --platform linux/arm64  -t ${build_img} --push .
    )
    # docker push ${build_img}
    # if [ "${BRANCH}" != main ];then
    #     docker tag ${build_img} ${hub_img}:release-${FSTYPE}
    #     docker push ${hub_img}:release-${FSTYPE}
    # fi
    rm -rf ${BUILD_DIR}
}

function upload(){
    if [ -n "${DOCKER_PASS}" ];then
        upload_dockerhub $1
    fi    
}

for file in $(ls $GITHUB_WORKSPACE/openwrt/bin/targets/*/*/openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-*-sysupgrade.img.gz);do
    upload $file
done
