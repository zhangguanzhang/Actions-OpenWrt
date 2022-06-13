#!/bin/bash

repo_name=$1
target=$2
if [ "$target" = '-full' ];then
    target=''
fi

function upload_dockerhub(){

    local hub_img=zhangguanzhang/${DEVICE_NAME} BUILD_DIR=$(mktemp -d)
    local BRANCH=${GITHUB_REF##*/}
    local file=$(basename $1)
    local tag=release-$(date +%Y-%m-%d)
    local FSTYPE suffix
    FSTYPE=$( echo $file | grep -Po '\-\K(ext4|squashfs)(?=-)' )
    # .img .img.gz 啥的后缀
    suffix=${file#*.}

    cp $1 ${BUILD_DIR}/openwrt-${DEVICE_NAME}-${FSTYPE}.${suffix}
    # cp $(dirname $1)/{sha256sums,config.buildinfo,feeds.buildinfo,version.buildinfo} ${BUILD_DIR}/
    cp $(dirname $1)/sha256sums ${BUILD_DIR}/
    echo 'Dockerfile' > ${BUILD_DIR}/.dockerignore
cat >${BUILD_DIR}/Dockerfile << EOF
FROM alpine
LABEL FILE=$file
LABEL NUM=${GITHUB_RUN_NUMBER}
COPY * /
EOF
    [ "${BRANCH}" != main ] && tag=latest

    local build_img=${hub_img}:${tag}-${FSTYPE}${target}-${repo_name}

    (
        cd ${BUILD_DIR}
        echo docker buildx build --platform linux/amd64  -t ${build_img} --push .
        docker buildx build --platform linux/amd64  -t ${build_img} --push .
        # 同步到阿里云
        docker buildx build --platform linux/amd64  -t registry.aliyuncs.com/${build_img} --push .
    )
    # docker push ${build_img}
    # if [ "${BRANCH}" != main ];then
    #     docker tag ${build_img} ${hub_img}:release-${FSTYPE}
    #     docker push ${hub_img}:release-${FSTYPE}
    # fi
    rm -rf ${BUILD_DIR}
}

function upload(){
    if [ -z "${NOT_PUSH}" ];then
        upload_dockerhub $1
    fi    
}

firmware_path=$( dirname $( find $GITHUB_WORKSPACE/openwrt/bin/targets -type f -name sha256sums)  )

for file in $(ls ${firmware_path}/openwrt-* | grep -Pv 'kernel|rootfs|manifest' | grep -P 'squashfs|ext4' );do
    upload $file
done
