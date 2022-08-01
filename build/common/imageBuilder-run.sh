#!/bin/bash

[ -f "$GITHUB_ENV" ] && source $GITHUB_ENV

function compile(){
    local count=0
    tar xf *-imagebuilder-*.Linux-x86_64.tar.xz
    rm -f *-imagebuilder-*.Linux-x86_64.tar.xz
    ln -sf *-imagebuilder-*.Linux* openwrt
    cd openwrt
    ls -al
    if [ -f imageBuilderEnv.buildinfo ];then
        source imageBuilderEnv.buildinfo
        cat imageBuilderEnv.buildinfo >> $GITHUB_ENV
    fi

    if [ "${suffix}" == '-slim' ];then
        mkdir -p files/local_feed && sudo mount --bind packages files/local_feed
    fi

    [ -f ${GITHUB_WORKSPACE}/diy-beforeMakeImage.sh ] && bash ${GITHUB_WORKSPACE}/diy-beforeMakeImage.sh
    grep -P '^CONFIG_TARGET_ROOTFS_PARTSIZE=' .config

    echo -e "$(nproc) thread compile"
    ls -1 packages/*.ipk | wc -l
    ls packages/

    # 必要包拆分到 small 和 common，这里合并下。这里前面的步骤 hack 了 imageBuilderr 的cp文件，这里俩文件和 ${GITHUB_WORKSPACE}/common/ 下是一样的
    cat small.buildinfo >> common.buildinfo

    sed -i 's/luci-app-[^ ]*//g' include/target.mk $(find target/ -name Makefile)
    ls packages/*.ipk | xargs -n1 basename > package.list

    function make_image(){
        local PROFILE extra_pkgs PACKAGES
        [ -n $1 ] && PROFILE=PROFILE=$1

        extra_pkgs="luci-i18n-base-zh-cn "
        if [ "${suffix}" == '-slim' ];then
            extra_pkgs+=' -luci-app-docker '
            #PACKAGES=$( grep -Po '^CONFIG_PACKAGE_\K[^A-Z=]+' ${GITHUB_WORKSPACE}/common/common.buildinfo | grep -Ev '_INCLUDE_|_$' | tr '\n' ' ' )
            PACKAGES=$(grep -Po '^CONFIG_PACKAGE_\K[^A-Z=]+' common.buildinfo | \
                grep -Ev '_INCLUDE_|_$' | \
                xargs -n1 -i grep -o {} package.list | \
                sort -u| tr '\n' ' ' )
        else
            # TODO full-noupdate grep -Po '^CONFIG_PACKAGE_\K[^A-Z=]+(?==(y|m))' full.buildinfo
            PACKAGES=$( grep -Po '^CONFIG_PACKAGE_\K[^A-Z=]+(?==y)' full.buildinfo | xargs -n1 -i grep -o {} package.list | awk '!a[$0]++' | xargs echo )
            # 存在 docker.buildinfo 就安装docker
            [ -f docker.buildinfo ] && extra_pkgs+=' luci-app-dockerman'
        fi

        > /tmp/log
        make image $PROFILE PACKAGES="$PACKAGES ${extra_pkgs} " FILES="files" |& tee -a /tmp/log
        REMOVE_PKGS=$( grep -Po 'Cannot install package \K[^.]+' /tmp/log | awk '{printf "-%s ",$0}' )
        if [ -n "$REMOVE_PKGS" ];then
            echo "打包报错，以下包存在依赖问题: ${REMOVE_PKGS}"
            echo "尝试移除上面的包打包"
            # 不删除则会文件已存在而不更新签名，貌似这样也解决不了。。,后面改 sed -ri '/check_signature/s@^[^#]@#&@' /etc/opkg.conf 暂时屏蔽前面错误
            # 签名貌似是下面两个选项
            # TODO
            # # CONFIG_SIGNED_PACKAGES is not set
            # # CONFIG_SIGNATURE_CHECK is not set
            rm -f files/local_feed/Packages*
            make image $PROFILE PACKAGES="$PACKAGES ${extra_pkgs} ${REMOVE_PKGS}" FILES="files"
        fi
    }
    make info
    for profile in `make info| grep -Po '^\S+(?=:$)'`;do
        if grep -Pq "${profile}=y" .config;then
            echo "===========${profile}==========="
            make_image ${profile}
            let count++
            continue
        fi
    done
    # 没匹配到的时候，可能是例如 x86 的 generic
    if [ "$count" -eq 0 ];then
        make_image
    fi

}

function release(){
    [ -z "$real_branch" ] && real_branch=${GITHUB_REF##*/}
    # 一个 build 多个 target 的
    [ -z "$multi_target" ] && multi_target=$build_target
    [ "$multi_target" = x86-64 ] && multi_target=
    echo "multi_target: ${multi_target}"

    for target_do in ${multi_target/,/ };do
        if ls -l *${target_do}* &>/dev/null;then
            prename -v "s#^.+?[-_]${target_do}-#${repo_name}-${repo_branch}-${target_do}${suffix}-#" *[-_]${target_do}[-]*
            ls *[-_]${target_do}.* &>/dev/null && prename -v "s#^.+?[-_]${target_do}#${repo_name}-${repo_branch}-${target_do}${suffix}#" *[-_]${target_do}.*
            if [ -f sha256sums ];then
                cp sha256sums ${repo_name}-${repo_branch}-${target_do}${suffix}-sha256sums
            fi
        else
            # 没有的时候，特殊处理下，例如 x86_64的 openwrt-x86-64-generic-squashfs-combined-efi.img
            prename -v "s#^.+${firmware_wildcard}#${repo_name}-${repo_branch}-${target_do}${suffix}#" *${firmware_wildcard}*
        fi
    done
    [ -f profiles.json ] && mv profiles.json ${repo_name}-${repo_branch}-${build_target}${suffix}-profiles.json
    rm -f sha256sums
    ls -l

    [ "${real_branch}" = 'main' ] && tag=latest || tag=test
    gh release -R ${GITHUB_REPOSITORY} list | grep -Eqw ${tag} || gh release -R ${GITHUB_REPOSITORY} create ${tag} -t '' -n ''
    if [ $tag == 'test' ];then
        gh release -R ${GITHUB_REPOSITORY} list | grep -Ew ${build_target} || gh release -R ${GITHUB_REPOSITORY} create ${build_target} -t '' -n ''
        gh release -R ${GITHUB_REPOSITORY} upload ${build_target} * --clobber
        return
    fi

    gh release -R ${GITHUB_REPOSITORY} upload ${tag} * --clobber
    if [ "${input_os}" = 'self-hosted' ];then
        gh auth logout 
    fi
}

$1
