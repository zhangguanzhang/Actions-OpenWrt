#!/bin/bash

if [ -z "$repository_owner" ] && [ -f "$GITHUB_ENV" ];then
    source $GITHUB_ENV
fi

: ${cache_func:=dockerhub} ${Need_Avail_G_NUM:=15}
#: ${cache_func:=github_release}

# cache 实现要求
# 下载的时候，需要生成 /tmp/cache_list 存放文件，每行一个，用于上传的判断数量大于10没有
# 下载完的时候还要合并文件

# ghcr 不建议用，辣鸡


function clean_dl(){
    if [ -z "$no_imageBuilder" ] && [ `grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l` -ge 7 ] ;then
        rm -rf openwrt/dl
        echo "dl 缓存清理"
    else
        echo "dl 缓存命中"
    fi
    if [ -f dl/time ];then
        last_time=$(cat dl/time)
        # echo 3*24*60*60 | bc # 超过上一次三天就清理一次 
        if [ $(( `date +%s` - $last_time  )) -ge $[15*24*60*60] ];then
            echo "dl 缓存清理"
            rm -rf dl
        else
            echo "dl 缓存命中"
        fi
    else
        mkdir -p dl
        date +%s > dl/time
    fi
}


# $1=download/upload $2=file_name
function github_release(){
# cache_repo 新创建仓库的话，必须有文件，否则后面操作无法上传和创建release
: ${cache_release_name:=cache-$build_target}  {cache_repo:=$GITHUB_REPOSITORY}

if ! [[ "$cache_repo" =~ / ]];then
    # 不包含 / ，就拼接上用户名，用于单独一个仓库存储缓存
    cache_repo=${GITHUB_REPOSITORY%%/*}/${cache_repo}
fi

    local action=$1 

case $action in
    download)
        gh release -R ${cache_repo} list | grep -Ew ${cache_release_name} || gh release -R ${cache_repo} create ${cache_release_name} -t '' -n ''
        gh release -R ${cache_repo} view ${cache_release_name} 2>/dev/null | grep -Po 'asset:\s+\K\S+' > /tmp/cache_list || true
        if grep -E "${cache_name}.img.zst" /tmp/cache_list;then
            echo 'start download cache:' `grep -E "^${cache_name}.img.zst" /tmp/cache_list`
            # TODO
            # 有小几率会下载失败
            gh release -R ${cache_repo} download ${cache_release_name} -p "${cache_name}.img.zst.*"
            # for i in `seq -w 15`
            # do
            #   curl -fsL https://github.com/$GITHUB_REPOSITORY/releases/download/cache/${cache_name}.img.zst.$i >> ${cache_name}.img.zst || break
            # done
            if cat ${cache_name}.img.zst.* | zstdmt -d -o ${GITHUB_WORKSPACE}/${cache_name}.img;then
                rm -f ${cache_name}.img.zst.*
            else
                # 缓存文件损坏
                rm -rf ${cache_name}.img*
                echo "缓存文件损坏"
            fi
        fi
    ;;
    get_reserved_time)
        cache_file_count=`grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l`
        if [ "$cache_file_count" -eq 0 ];then
            echo 16
        elif [ "$cache_file_count" -lt 10 ];then
            echo 18
        else
            echo 20
        fi 
    ;;
    clean)
        pushd openwrt
        clean_dl
        popd
        if [ -z "$no_imageBuilder" ] && [ `grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l` -ge 10 ];then
            #echo "clean openwrt/build_dir"
            true
        fi
    ;;
    upload)
        cache_file_count=`grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l`
        # 可能存在当前上传的切割文件数量少于 cache release 上的，需要提前删除
        gh release -R ${cache_repo} view ${cache_release_name}  2>/dev/null | grep -Po "asset:\s+\K${cache_name}.img.zst.\d+" | \
            xargs -r -n1 gh release -R ${cache_repo} delete-asset ${cache_release_name}  -y
        if [ "$Avail_G_NUM" -gt ${Need_Avail_G_NUM} -a "$cache_file_count" -lt 10 ] && zstdmt -c --long ${cache_name}.img | split --numeric=1 -b 2000m - ${cache_name}.img.zst.;then
            ls -l
            rm -f ${cache_name}.img # 减少容量
            gh release -R ${cache_repo} upload ${cache_release_name} ${cache_name}.img.zst.* --clobber
            last_file_name=$(ls ${cache_name}.img.zst.* | tail -n1)
            rm -f ${cache_name}.img.zst.*
        else
            echo "上传失败，容量爆满，开始单线程顺序临时文件占用方式上传"
            df -h
            rm -f ${cache_name}.img.zst.*
            zstdmt -c --long ${cache_name}.img | split --numeric=1 -b 2000m \
                --filter "cat /dev/stdin > \$FILE;  gh release -R ${cache_repo} upload ${cache_release_name} \$FILE --clobber && rm -f \$FILE && echo \$FILE Successfully uploaded && echo \$FILE > /tmp/count_num" - ${cache_name}.img.zst.
            rm -f ${cache_name}.img # 减少容量
            last_file_name=$(cat /tmp/count_num)
        fi
    ;;
    *)
        true
    ;;
esac

}


function ghcr(){
    local action=$1 
    local tag pipe file token
    local repo_user=${repository_owner}
    export repo_user

    function docker_build_push(){
        local copy_file=$1
        local docker_build_dir=$(mktemp -d -p .)
        echo -e 'FROM scratch\nCOPY '"${copy_file} /" > ${docker_build_dir}/Dockerfile
        mv $copy_file ${docker_build_dir}/
        (
            cd ${docker_build_dir};
            docker build -t ghcr.io/${repo_user}/openwrt_cache:$copy_file .
        )
        rm -rf ${docker_build_dir}
        docker push ghcr.io/${repo_user}/openwrt_cache:$copy_file
        docker rmi ghcr.io/${repo_user}/openwrt_cache:$copy_file
    }
    export SHELL=/bin/bash
    # https://stackoverflow.com/questions/51022049/filtering-gnu-split-with-a-custom-shell-function
    export -f docker_build_push

case $action in
    download)
        # 列表文件不要动，后面上传后清理缓存会用到
        skopeo --insecure-policy list-tags docker://ghcr.io/${repo_user}/openwrt_cache 2>/dev/null | jq -r '.Tags[]' | grep -P "^${cache_name}.img.zst" > /tmp/cache_list
        if grep -E "${cache_name}.img.zst" /tmp/cache_list;then
            echo 'start download cache:' `grep -E "${cache_name}.img.zst" /tmp/cache_list`
            cat /tmp/cache_list | parallel -j3 "docker pull ghcr.io/${repo_user}/openwrt_cache:{}"
            while read tag;do
                skopeo --insecure-policy copy docker-daemon:ghcr.io/${repo_user}/openwrt_cache:${tag} dir:${tag}-dir
                docker rmi ghcr.io/${repo_user}/openwrt_cache:${tag}
                for file in ${tag}-dir/*;do
                    file $file | grep -Eq 'archive' || continue
                    if tar tf $file | grep -Eq ${tag};then
                        tar xf $file -C . ${tag}
                        rm -rf ${tag}-dir
                        break
                    fi
                done
            done < /tmp/cache_list

            ls -lh
            if cat ${cache_name}.img.zst.* | zstdmt -d -o ${GITHUB_WORKSPACE}/${cache_name}.img;then
                rm -f ${cache_name}.img.zst.*
            else
            # 缓存文件损坏
                rm -rf ${cache_name}.img*
                echo "缓存文件损坏"
            fi
        fi
    ;;
    get_reserved_time)
        cache_file_count=`grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l`
        if [ "$cache_file_count" -eq 0 ];then
            echo 17
        elif [ "$cache_file_count" -lt 10 ];then
            echo 20
        else
            echo 23
        fi 
    ;;
    clean)
        pushd openwrt
        clean_dl
        popd
        if [ -z "$no_imageBuilder" ] && [ `grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l` -ge 10 ];then
            #echo "clean openwrt/build_dir"
            true
        fi
    ;;
    upload)
        cache_file_count=`grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l`
        # 不行 skopeo --insecure-policy delete --authfile ~/.docker/config.json docker://ghcr.io/${repo_user}/openwrt_cache:{}
        if [ "$Avail_G_NUM" -gt ${Need_Avail_G_NUM} -a "$cache_file_count" -lt 10 ] && zstdmt -c --long ${cache_name}.img | split --numeric=1 -b 2000m - ${cache_name}.img.zst.;then
            rm -f ${cache_name}.img # 减少容量
            last_file_name=$(ls ${cache_name}.img.zst.* | tail -n1)
            ls ${cache_name}.img.zst.*| parallel -j4 "docker_build_push {}"
        else
            echo "切割失败，容量爆满，开始单线程顺序临时文件占用方式上传"
            df -h
            rm -f ${cache_name}.img.zst.*

            zstdmt -c --long ${cache_name}.img | split --numeric=1 -b 2000m \
                --filter "cat /dev/stdin > \$FILE;  docker_build_push \$FILE; rm -f \$FILE; echo \$FILE > /tmp/count_num" - ${cache_name}.img.zst.
            rm -f ${cache_name}.img Dockerfile # 减少容量
            last_file_name=$(cat /tmp/count_num)
        fi
        if [ -n "$last_file_name" ];then
            # 删除多余的缓存
            set +x # 这个区域关闭调试输出，防止token泄漏
            awk -vname="$last_file_name" '$1==name{flag=1;next}flag' /tmp/cache_list | while read line;do
                tag_id=$(
                    curl -s   -H "Authorization: token $gh_package_token" \
                    https://api.github.com/user/packages/container/openwrt_cache/versions | \
                    jq '.[]|select(.metadata.container.tags[]=="'$line'")|.id'
                )
                if [ -n "$tag_id" ];then
                    curl -X DELETE -H "Authorization: token $gh_package_token" https://api.github.com/user/packages/container/openwrt_cache/versions/${tag_id}
                    # 上面只是删除 tag ，没彻底删除，彻底删除用下面的
                    # https://docs.github.com/en/rest/packages#delete-package-version-for-a-user
                    curl -X DELETE -H "Authorization: token $gh_package_token" \
                        https://api.github.com/users/${repo_user}/packages/container/openwrt_cache/versions/${tag_id}
                fi
            done
            set -x
        fi
    ;;
    *)
        true
    ;;
esac

}

function dockerhub(){
    local action=$1 
    local tag pipe file token
    local repo_user=${repository_owner}
    export repo_user

    function docker_build_push(){
        local copy_file=$1
        local docker_build_dir=$(mktemp -d -p .)
        echo -e 'FROM scratch\nCOPY '"${copy_file} /" > ${docker_build_dir}/Dockerfile
        mv $copy_file ${docker_build_dir}/
        (
            cd ${docker_build_dir};
            docker build -t ${repo_user}/openwrt_cache:$copy_file .
        )
        rm -rf ${docker_build_dir}
        docker push ${repo_user}/openwrt_cache:$copy_file
        docker rmi ${repo_user}/openwrt_cache:$copy_file
    }
    export SHELL=/bin/bash
    # https://stackoverflow.com/questions/51022049/filtering-gnu-split-with-a-custom-shell-function
    export -f docker_build_push

case $action in
    download)
        # 列表文件不要动，后面上传后清理缓存会用到
        skopeo --insecure-policy list-tags docker://${repo_user}/openwrt_cache 2>/dev/null | jq -r '.Tags[]' | grep "^${cache_name}.img.zst" > /tmp/cache_list
        if grep -E "${cache_name}.img.zst" /tmp/cache_list;then
            echo 'start download cache:' `grep -E "${cache_name}.img.zst" /tmp/cache_list`
            cat /tmp/cache_list | parallel -j3 "docker pull ${repo_user}/openwrt_cache:{}"
            while read tag;do
                skopeo --insecure-policy copy docker-daemon:${repo_user}/openwrt_cache:${tag} dir:${tag}-dir
                docker rmi ${repo_user}/openwrt_cache:${tag}
                for file in ${tag}-dir/*;do
                    file $file | grep -Eq 'archive' || continue
                    if tar tf $file | grep -Eq ${tag};then
                        tar xf $file -C . ${tag}
                        rm -rf ${tag}-dir
                        break
                    fi
                done
            done < /tmp/cache_list

            ls -lh
            if cat ${cache_name}.img.zst.* | zstdmt -d -o ${GITHUB_WORKSPACE}/${cache_name}.img;then
                rm -f ${cache_name}.img.zst.*
            else
            # 缓存文件损坏
                rm -rf ${cache_name}.img*
                echo "缓存文件损坏"
            fi
        fi
    ;;
    get_reserved_time)
        cache_file_count=`grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l`
        if [ "$cache_file_count" -eq 0 ];then
            echo 18
        elif [ "$cache_file_count" -lt 10 ];then
            echo 21
        else
            echo 23
        fi 
    ;;
    clean)
        pushd openwrt
        clean_dl
        popd
        if [ -z "$no_imageBuilder" ] && [ `grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l` -ge 10 ];then
            # echo "clean openwrt/build_dir"
            true
        fi
    ;;
    upload)
        # cache_file_count=`grep -E "${cache_name}.img.zst" /tmp/cache_list| wc -l`
        # # 不行 skopeo --insecure-policy delete --authfile ~/.docker/config.json docker://${repo_user}/openwrt_cache:{}
        # if [ "$Avail_G_NUM" -gt ${Need_Avail_G_NUM} -a "$cache_file_count" -lt 10 ] && zstdmt -c --long ${cache_name}.img | split --numeric=1 -b 2000m - ${cache_name}.img.zst.;then
        #     rm -f ${cache_name}.img # 减少容量
        #     last_file_name=$(ls ${cache_name}.img.zst.* | tail -n1)
        #     ls ${cache_name}.img.zst.*| parallel -j4 "docker_build_push {}"
        # else
            # echo "切割失败，容量爆满，开始单线程顺序临时文件占用方式上传"
            df -h
            # rm -f ${cache_name}.img.zst.*

            zstdmt -c --long ${cache_name}.img | split --numeric=1 -b 2000m \
                --filter "cat /dev/stdin > \$FILE;  docker_build_push \$FILE; rm -f \$FILE; echo \$FILE > /tmp/count_num" - ${cache_name}.img.zst.
            rm -f ${cache_name}.img Dockerfile # 减少容量
            last_file_name=$(cat /tmp/count_num)
        # fi
        if [ -n "$last_file_name" ];then
            # 删除多余的缓存
            set +x # 这个区域关闭调试输出，防止token泄漏
            token=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${repo_user}'", "password": "'${repo_pass}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
            [ -z "$token" ] && echo 'token 为空,错误'
            # https://github.com/docker/hub-feedback/issues/2127 2022/07/13 只能用密码，后续换 access token
            # 上传完才删除数字大的缓存
            # skopeo --insecure-policy list-tags docker://${repo_user}/openwrt_cache 2>/dev/null | jq -r '.Tags[]' | grep "${cache_name}.img.zst" | \
            #     xargs -r -n1 -I{} curl -X DELETE -s -LH "Authorization: JWT ${token}" https://hub.docker.com/v2/repositories/${repo_user}/openwrt_cache/tags/{}
            awk -vname="$last_file_name" '$1==name{flag=1;next}flag' /tmp/cache_list | xargs -r -n1 -I{} \
                curl -X DELETE -s -LH "Authorization: JWT ${token}" https://hub.docker.com/v2/repositories/${repo_user}/openwrt_cache/tags/{}
            set -x
        fi
    ;;
    *)
        true
    ;;
esac

}

${cache_func} $1
