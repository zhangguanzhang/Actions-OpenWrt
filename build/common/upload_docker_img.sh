#!/bin/bash

repo_name=$1
target=$2
if [ "$target" = '-full' ];then
    target=''
fi

[ -z "$real_branch" ] && real_branch=${GITHUB_REF##*/}

function upload_dockerhub(){
    local DEVICE_NAME=$1
    local hub_img=zhangguanzhang/${DEVICE_NAME,,} BUILD_DIR=$(mktemp -d)
    local BRANCH=${real_branch}
    local file=$(basename $2)
    local tag=release-$(date +%Y-%m-%d)
    local FSTYPE suffix
    FSTYPE=$( echo $file | grep -Po '\-\K(ext4|squashfs)(?=-)' )
    # .img .img.gz 啥的后缀
    suffix=${file#*.}

    cp $2 ${BUILD_DIR}/openwrt-${DEVICE_NAME}-${FSTYPE}.${suffix}
    # cp $(dirname $2)/{sha256sums,config.buildinfo,feeds.buildinfo,version.buildinfo} ${BUILD_DIR}/
    cp $(dirname $2)/sha256sums ${BUILD_DIR}/
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
        echo docker build  -t ${build_img} .
        # 同步到阿里云
        docker build  -t registry.aliyuncs.com/${build_img} . && docker push registry.aliyuncs.com/${build_img}
        docker tag registry.aliyuncs.com/${build_img} ${build_img} && docker push ${build_img} 
        docker rmi ${build_img}
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
        upload_dockerhub $1 $2
    fi    
}

firmware_path=$( dirname $( find $GITHUB_WORKSPACE/openwrt/bin/targets -type f -name sha256sums)  )

[ -n "$exclude_str" ] && exclude_str="|${exclude_str#|}"
# 有些 build_target 没设置 exclude_str
if echo $multi_target | grep -Pq ,;then
    for target_ins in `echo $multi_target| sed -e 's/,/ /' -e "s/'//g"`;do
        for file in $(ls ${firmware_path}/*-${target_ins}-* | grep -Pv "kernel|rootfs|manifest${exclude_str}" | grep -P 'squashfs|ext4' );do
            upload $target_ins $file
        done
    done
else
    for file in $(ls ${firmware_path}/*-*-* | grep -Pv "kernel|rootfs|manifest${exclude_str}" | grep -P 'squashfs|ext4' );do
        upload ${DEVICE_NAME} $file
    done
fi
