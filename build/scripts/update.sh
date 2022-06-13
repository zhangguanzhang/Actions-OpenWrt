# https://github.com/klever1988/nanopi-openwrt/raw/master/scripts/autoupdate.sh
# 参考这个脚本，但是我脚本支持 squashfs 格式的升级，以及支持其他人固件切换到我的固件来
# 目前只支持r2s
#!/bin/sh

set -e

# FSTYPE=ext4,squashfs
: ${IM_BRANCH:=}
: ${SKIP_BACK:=false} ${DEBUG:=false}
: ${TEST:=false} # 默认使用 main 分支编译的，test分支是测试阶段
: ${REPO:=} # lede openwrt

tmp_mountpoint=/opt

: ${USER_FILE:=${tmp_mountpoint}/openwrt.img.gz} # 用户本地升级的固件文件路径，是压缩包
# 用户可以声明上面文件路径来本地不联网升级

NO_NET=''
: ${VER:=} # slim or full

: ${ghproxy:=https://github.cooluc.com/}
: ${docker_repo_ns:=registry.aliyuncs.com/zhangguanzhang}

repo_domain=${docker_repo_ns%/*}
repo_namespace=${docker_repo_ns#*/}

# 必须 /tmp 目录里操作
WORK_DIR=/tmp/update
IMG_FILE=openwrt.img
USE_FILE=${WORK_DIR}/${IMG_FILE}

readonly CUR_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)



err() {
    printf '%b\n' "\033[1;31m[ERROR] $@\033[0m"
    exit 1
} >&2

info() {
    printf '%b\n' "\033[1;32m[INFO] $@\033[0m"
}

success() {
    printf '%b\n' "\033[1;32m[SUCCESS] $@\033[0m"
}

warning(){
    printf '%b\n' "\033[1;91m[WARNING] $@\033[0m"
}

debug(){
    if [ "$DEBUG" != false ];then
        #printf '%s\n' "\033[1;91m[DEBUG] $@\033[0m"
        echo -e "\033[1;91m[DEBUG] $@\033[0m"
        $@
    fi
}

function proceed_command() {
    local install=$1
    [ -n "$2" ] && install=$2
	if ! command -v $1 &> /dev/null; then
        if [ "$NO_NET" = true ];then
            err "检测到无法联网，并且固件没有扩容所需命令: $1"
        fi
        opkg install --force-overwrite $install
    fi
	if ! command -v $1 &> /dev/null; then
        err "'$1'命令不可用，升级中止"
    fi
}

function init_d_stop(){
    for i in $@;
    do
        if [ -f /etc/init.d/$i ];then
            /etc/init.d/$i stop
        fi
    done 
}

# TODO
# 从 ghproxy 下载
function registry_api_setting(){
    local target=$1 realm service scope url
    curl -L https://${repo_domain}/v2/${repo_namespace}/${target}/tags/list -v 2>&1 |  awk 'tolower($2)~"www-authenticate"{print $4}' | sed 's/,/\n/g' > /tmp/registr_realm
    source /tmp/registr_realm
    url="${realm}?service=${service}&scope=${scope}"
    # https://stackoverflow.com/questions/35018899/using-curl-in-a-bash-script-and-getting-curl-3-illegal-characters-found-in-ur
    url=${url%$'\r'}
    curl -sL "${url}" > /tmp/registr_token
    regirey_header="Authorization: Bearer `jsonfilter -e '@["token"]' < /tmp/registr_token`"
}

function registry_tag_list(){
    local target=$1 
    [ -z "$regirey_header" ] && registry_api_setting $target
    # curl -s  https://hub.docker.com/v2/repositories/zhangguanzhang/${$board_id}/tags/?page_size=100
    # 阿里的仓库不支持 /tags/?page_size=100
    curl -sL -H "${regirey_header}"  https://${repo_domain}/v2/${repo_namespace}/${target}/tags/list?page_size=100 
}

# 阿里云镜像仓库下载
function registry_blob_download_op(){
    # target=r2s
    # tag=latest-squashfs-slim-lede-master
    local target=$1 tag=$2 url blob_id
    # https://stackoverflow.com/questions/71409458/how-to-download-docker-image-using-http-api-using-docker-hub-credentials

    [ -z "$regirey_header" ] && registry_api_setting $target

    curl -sL https://${repo_domain}/v2/${repo_namespace}/${target}/manifests/${tag} -H "${regirey_header}" > /tmp/registr_manifest.json
    blob_id=$(jsonfilter -e '@["fsLayers"][0]["blobSum"]' < /tmp/registr_manifest.json)
    info "开始从 ${docker_repo_ns} 下载包含 $target $tag 固件的 blob 数据，左下角数据是下载进度百分比"
    # TODO
    # 直接下载和解压
    curl -L https://${repo_domain}/v2/${repo_namespace}/${target}/blobs/${blob_id} -H "${regirey_header}" -o ${USER_FILE}.tar.gz
    rm -f /tmp/registr_*
}

function r1s-h3(){
    #part_prefix=p
    tmp_mountpoint_end_size=2600MB
    first_grow_condition_size=1800
    blob_layer_reg_str=r1s-h3
    # [ ! -d /sys/block/$block_device ] && block_device='mmcblk1'
    update
}

function r1s-h5(){
    #part_prefix=p
    tmp_mountpoint_end_size=2600MB
    first_grow_condition_size=1800
    blob_layer_reg_str=r1s-h5
    # [ ! -d /sys/block/$block_device ] && block_device='mmcblk1'
    update
}

function r2s(){
    #part_prefix=p
    tmp_mountpoint_end_size=2600MB
    first_grow_condition_size=1800
    blob_layer_reg_str=r2s
    # [ ! -d /sys/block/$block_device ] && block_device='mmcblk1'
    update
}

function r4s(){
    #part_prefix=p
    tmp_mountpoint_end_size=2600MB
    first_grow_condition_size=1800
    blob_layer_reg_str=r4s
    # [ ! -d /sys/block/$block_device ] && block_device='mmcblk1'
    update
}

function doornet2(){
    #part_prefix=p
    tmp_mountpoint_end_size=2600MB
    first_grow_condition_size=1800
    blob_layer_reg_str=doornet2
    # [ ! -d /sys/block/$block_device ] && block_device='mmcblk1'
    update
}

function x86_64(){
    #part_prefix=''
    tmp_mountpoint_end_size=2400MB
    first_grow_condition_size=1500
    blob_layer_reg_str=x86_64
    update
}

function update(){
    debug df -h
    mount -t tmpfs -o remount,size=100% tmpfs /tmp
    bs=`expr $(cat /sys/block/$block_device/size) \* 512`

    mkdir -p ${WORK_DIR}
    cd ${WORK_DIR}

    [ ! -d ${tmp_mountpoint} ] && mkdir -p ${tmp_mountpoint}
    if [ $(df  -m ${tmp_mountpoint} | awk 'NR==2{print $4}') -lt "$first_grow_condition_size" ];then
        NEED_GROW=1
        init_d_stop dockerd
        warning "检测到当前未扩容，先创建一个分区挂载为 ${tmp_mountpoint} 数据目录用于存放升级固件"
        df -h
        rm -f /tmp/parted_info
        parted --script /dev/$block_device p 2>&1 | tee -a /tmp/parted_info
        # gpt 扩容警告
        if grep -Eq 'fix the GPT' /tmp/parted_info;then
            echo -e "OK\nFix\n" | parted ---pretend-input-tty /dev/$block_device print 1>/dev/null
            rm -f /tmp/parted_info
        fi
        # 分区后在升级前报错，此处提前记录
        #p_4g_num=$(parted --script /dev/$block_device p | awk '$1~/[1-9]/&& $3=="'${tmp_mountpoint_end_size}'"{print $1}')
        unset part_num
        part_num=$(parted --script /dev/$block_device p | awk '$1~/[1-9]/&& $3=="'${tmp_mountpoint_end_size}'"{print $1}')

        if [ -z "${part_num}" ];then
            start_sec=$(parted /dev/$block_device unit s print free | awk '$1~"s"{a=$1}END{print a}')
            align_size=$(parted /dev/$block_device align-check optimal 2 | awk '$2!="aligned"{print +$6}')
            if [ -n "$align_size" ];then
                start_sec_align=$(expr $(echo $start_sec | sed 's/s//') / $align_size )
                start_sec_align=$(expr $start_sec_align \* $align_size )
                start_sec=$(expr $start_sec_align + $align_size )s
            fi
            parted /dev/$block_device mkpart p ext4 ${start_sec} ${tmp_mountpoint_end_size}
            part_num=$(parted --script /dev/$block_device p | awk '$1~/[1-9]/&& $3=="'${tmp_mountpoint_end_size}'"{print $1}')
            sleep 3 # 此处会自动挂载造成蛋疼
            if grep -E "/dev/${block_device}${part_prefix}${part_num} " /proc/mounts;then
                if mountpoint -q  /mnt/${block_device}${part_prefix}${part_num};then
                    touch /mnt/${block_device}${part_prefix}${part_num}/.fs.exit &>/dev/null || true
                    umount /mnt/${block_device}${part_prefix}${part_num}
                    try_fsck=0
                    while [ "$try_fsck" -le 10 ];do
                        e2fsck -y -f /dev/${block_device}${part_prefix}${part_num} && break || true
                        let try_fsck+1
                    done
                    resize2fs /dev/${block_device}${part_prefix}${part_num}
                fi
                [ ! -f "${tmp_mountpoint}/.fs.exit" ] && mkfs.ext4 -F /dev/${block_device}${part_prefix}${part_num}
            else
                mkfs.ext4 -F /dev/${block_device}${part_prefix}${part_num}
            fi
        fi

        mountpoint -q  ${tmp_mountpoint} || mount -o rw /dev/${block_device}${part_prefix}${part_num} ${tmp_mountpoint}

        if mountpoint -q  /mnt/${block_device}${part_prefix}${part_num};then
            umount /mnt/${block_device}${part_prefix}${part_num}
        fi
        if mountpoint -q  /mnt/${block_device}${part_prefix}1;then
            umount /mnt/${block_device}${part_prefix}1
        fi


    fi

    if [ -f "${USER_FILE}" ];then
        info "此次使用本地文件: ${USER_FILE} 来升级"
    else

        registry_tag_list ${board_id}  |  jsonfilter -e '@["tags"][*]' > /tmp/registr_list

        if [ "${TEST}" != false ];then
            IMG_TAG=latest-${FSTYPE}${VER}-${REPO}-${IM_BRANCH}
        else
            # dockerhub jsonfilter -e '@["results"][*].name'
            IMG_TAG=$(grep -E release /tmp/registr_list | sort -rn | grep '${FSTYPE}${VER}-${REPO}' | grep ${IM_BRANCH} | head -n1)
        fi
        # 没合并到 master 上暂时使用测试固件
        [ -z "${IMG_TAG}" ] && IMG_TAG=latest-${FSTYPE}${VER}-${REPO}-${IM_BRANCH}
        
        # 部分源码的 branch 带 openwrt- 前缀，IM_BRANCH 获取到的是数字
        # 这里查找下确认镜像存在否
        IMG_TAG_prefix=$(echo ${IMG_TAG} | sed "s/-${IM_BRANCH}//" )
        IMG_TAG=$(grep $IMG_TAG_prefix /tmp/registr_list  | grep $IM_BRANCH)

        [ -z "$IMG_TAG" ] && err "没有查询到可用镜像，分支是否有误"

        if [ ! -f "${USER_FILE}" ];then
            if [ -f ${USER_FILE}.tar.gz ] && [ ! -f ${tmp_mountpoint}/sha256sums ] && [ ! -f /tmp/sha256sums ];then
                # 下载 layer 被中断，删除掉走下面的下载逻辑
                rm -f ${USER_FILE}.tar.gz
            fi
            if [ ! -f  ${USER_FILE}.tar.gz ];then
                registry_blob_download_op ${board_id} ${IMG_TAG}
            fi
            cd ${tmp_mountpoint}
            info "下载完成，开始解压 blob layer"
            tar zxf ${USER_FILE}.tar.gz
            rm -f ${USER_FILE}.tar.gz
            # x86-64 是 img 结尾，其余的是 img.gz
            if ls *${blob_layer_reg_str}* | grep -Eq 'img$';then
                # 不再继续解压
                mv *${blob_layer_reg_str}* ${USE_FILE}
                check_file=$USE_FILE
            else
                mv *${blob_layer_reg_str}* ${USER_FILE}
            fi
            mv sha256sums /tmp/
        fi
    fi
    if [ -f /tmp/sha256sums ];then
        [ -z "$check_file" ] && check_file=$USER_FILE
        file_sum=`sha256sum ${check_file} | awk '{print $1}'`
        # 直接查 hash 字符串，不管文件名
        if ! grep -Eq "${file_sum}" /tmp/sha256sums;then
            rm -f ${USER_FILE}
            err '文件校验失败，文件可能损坏，请再次重试'
        fi
        success '文件校验成功'
    fi
    if [ -f "${USER_FILE}" ] && [ ! -f "${USE_FILE}" ];then
        info "开始解压 ${USER_FILE} 到 ${USE_FILE}"
        gzip -dc ${USER_FILE} > ${USE_FILE} || true
        debug ls -lh ${WORK_DIR}
        success "解压固件文件到: ${USE_FILE}"
    fi
    
    truncate -s $bs $USE_FILE
    rm -f /tmp/parted_info
    parted --script $USE_FILE p 2>&1 | tee -a /tmp/parted_info
    # gpt 扩容警告
    if grep -Eq 'fix the GPT' /tmp/parted_info;then
        echo -e "OK\nFix\n" | parted ---pretend-input-tty $USE_FILE print 1>/dev/null
        rm -f /tmp/parted_info
    fi
    parted $USE_FILE resizepart 2 100%

    part2_seek=$(parted $USE_FILE u s p | awk '$1==2{print +$2}')

    lodev=$(losetup -f)
    losetup -P $lodev $USE_FILE
    sleep 2
    mkdir -p /mnt/update/img
    # FSTYPE ext4 squashfs
    # -t ${FSTYPE}  不需要指定，会自动挂载
    mount ${lodev}p2 /mnt/update/img
    IMG_FSTYPE=$(df -T /mnt/update/img | awk 'NR==2{print $2}')
    [ "$IMG_FSTYPE" = 'ext4' ] && success '解压已完成，准备编辑镜像文件，写入备份信息'
    sleep 1
    debug df -h

    if [ "$IMG_FSTYPE" = 'squashfs' ];then
        info "检测到使用 squashfs 固件，开始导出文件系统"
        # https://github.com/plougher/squashfs-tools/issues/139#issuecomment-991779738
        # unsquashfs -da 10 -fr 10 /dev/loop0p2
        # 这个解压太耗时了，只能拷贝整了
        if [ "${NEED_GROW}" == 1 ];then
            # 初次root没容量，第三个临时分区这里 bind 挂载到 /mnt/img
            mkdir -p ${tmp_mountpoint}/update/img ${tmp_mountpoint}/update/img_sq
            umount /mnt/update/img
            mount --bind ${tmp_mountpoint}/update /mnt/update
            sleep 1
            mount ${lodev}p2 /mnt/update/img
            sleep 1
        fi
        mkdir -p /mnt/update/img_sq
        cp -a /mnt/update/img/* /mnt/update/img_sq
        umount /mnt/update/img
        rm -rf /mnt/update/img
        mv /mnt/update/img_sq /mnt/update/img
    fi

    # 无论备份不备份，都把应用列表保留到新固件的 rootfs 里
    # TODO
    # 当前主题写入
    echo 'opkg update' > /mnt/update/img/packages_needed
    opkg list-installed | grep -E "luci-(i18n|app|proto)-|kmod-fs-" | cut -d ' '  -f1 | \
        sort -r | xargs -n1 echo opkg install --force-overwrite >> /mnt/update/img/packages_needed

    if [ "$SKIP_BACK" != false ] || [ -n "$NEED_GROW" ] ;then
        if [ -n "$NEED_GROW" ];then
            warning '注意：初版扩容，或者其他人固件升级到我的固件时候只备份网卡配置文件'
        fi
        cp /etc/config/network /mnt/update/img/etc/config/network.bak
        cat /etc/config/network > /mnt/update/img/etc/config/network
    else
        sysupgrade -b back.tar.gz
        # 其他人的固件 tar 可能不带 -m选项
        tarOPts=""
        tar --help |& grep -q -- --touch && tarOPts=m
        tar zxf${tarOPts} back.tar.gz -C /mnt/update/img # -m 忽略时间戳的警告
        if [ "${VER}" == '-slim' ];then
            sed -i '/exit/i\sed -i "/packages_needed/d" /etc/rc.local; [ -e /packages_needed ] && (mv /packages_needed /packages_needed.installed && sh /packages_needed.installed)\' /mnt/update/img/etc/rc.local
        fi
        debug df -h
        rm back.tar.gz
        success '备份文件已经写入，移除挂载'
    fi
    # 一直备份网卡配置文件
    # if ! grep -q macaddr /etc/config/network; then
    #     warning '注意：由于已知的问题，“网络接口”配置无法继承，重启后需要重新设置WAN拨号和LAN网段信息'
    #     rm /mnt/update/img/etc/config/network;
    # fi


    if [ "$IMG_FSTYPE" = 'squashfs' ];then
        proceed_command unsquashfs squashfs-tools-unsquashfs
        proceed_command mksquashfs squashfs-tools-mksquashfs

        if [ -z "$(mksquashfs --help 2>&1 | awk 'a>0{a++}/Compressors available:/{a=1}a>0&&a<5&&$1=="xz"{print 1}')" ];then
            warning "squashfs-tools-mksquashfs 的 mksquashfs 不支持 xz 压缩，继续打包可能存在无法开机的情况"
            read -p "继续或者退出 (y/n)?" choice
            case "$choice" in 
                y|Y ) choice=1;;
                n|N ) choice=0;;
                * ) choice=0;;
            esac 
            if [ "$choice" = 0 ];then
                exit 2
            fi
        fi

        info "开始打包 squashfs 文件系统，请耐心等待"
        unsquashfs -s ${lodev}p2 &> squashfs.info
        comp=$(awk '$1=="Compression"{print $2}' squashfs.info)
        comp="-comp ${comp}"
        # 压缩可能用不了
        grep -qw 'xz compression is not supported' squashfs.info && comp=''
        sq_block_size=$(awk '$1=="Block"{print $NF}' squashfs.info)
        xattrs='' # CONFIG_SELINUX=y # xattrs='-xattrs'
        grep -Eq 'Xattrs.+?not' squashfs.info && xattrs='-no-xattrs'
        # nmbd samba 
        init_d_stop netdata snmpd vsftpd nmbd dockerd
        init_d_stop ttyd 2>/dev/null # op官方的 ttyd 脚本貌似有问题
        # mksquashfs 吃内存和缓存，导出的文件不能放 tmp 目录下，此处也调整父级进程 oom_score_adj 防止 oom
        echo -998 > /proc/$$/oom_score_adj 2>/dev/null || true
        # 
        # mksquashfs 参数来源于源码下./include/image.mk 的 SQUASHFSOPT 和 define Image/mkfs/squashfs-common
        # CONFIG_TARGET_SQUASHFS_BLOCK_SIZE=1024k 默认
        # SQUASHFS_BLOCKSIZE := $(CONFIG_TARGET_SQUASHFS_BLOCK_SIZE)k
        # SQUASHFSOPT := -b $(SQUASHFS_BLOCKSIZE)
        # SQUASHFSOPT += -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1'
        # SQUASHFSOPT += $(if $(CONFIG_SELINUX),-xattrs,-no-xattrs)
        # SQUASHFSCOMP := gzip
        # LZMA_XZ_OPTIONS := -Xpreset 9 -Xe -Xlc 0 -Xlp 2 -Xpb 2
        # ifeq ($(CONFIG_SQUASHFS_XZ),y)
        #   ifneq ($(filter arm x86 powerpc sparc,$(LINUX_KARCH)),)
        #     BCJ_FILTER:=-Xbcj $(LINUX_KARCH)   # 例如此处  -Xbcj x86
        #   endif
        #   SQUASHFSCOMP := xz $(LZMA_XZ_OPTIONS) $(BCJ_FILTER)
        # endif

        # JFFS2_BLOCKSIZE ?= 64k 128k
        # 下面这段可以在 action 上调小 CONFIG_TARGET_ROOTFS_PARTSIZE 触发报错来查看 mksquashfs4 的参数
        # rm -f /workdir/openwrt/build_dir/target-aarch64_generic_musl/linux-rockchip_armv8/image-rk3328-orangepi-r1-plus.dtb.tmp
        # mkdir -p /workdir/openwrt/bin/targets/rockchip/armv8 /workdir/openwrt/build_dir/target-aarch64_generic_musl/linux-rockchip_armv8/tmp
        # rm -rf /workdir/openwrt/build_dir/target-aarch64_generic_musl/json_info_files
        # /workdir/openwrt/staging_dir/host/bin/mksquashfs4 /workdir/openwrt/build_dir/target-aarch64_generic_musl/root-rockchip /workdir/openwrt/build_dir/target-aarch64_generic_musl/linux-rockchip_armv8/root.squashfs \
        #     -nopad -noappend -root-owned -comp xz -Xpreset 9 -Xe -Xlc 0 -Xlp 2 -Xpb 2  \
        #     -b 1024k -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1' -no-xattrs -processors 2
        
        # ext4 则是: /workdir/openwrt/staging_dir/host/bin/make_ext4fs -L rootfs -l 456130560 -b 4096 -m 0 -J -T 1639243554 /workdir/openwrt/build_dir/target-aarch64_generic_musl/linux-rockchip_armv8/root.ext4 /workdir/openwrt/build_dir/target-aarch64_generic_musl/root-rockchip/
        #                                           1048576
        # mksquashfs  squashfs-root/ op.squashfs -nopad -noappend -root-owned  -comp xz -Xpreset 9 -Xe -Xlc 0 -Xlp 2 -Xpb 2 \
        # -b 1024k -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1' \
        # -no-xattrs -mem 20M
        LZMA_XZ_OPTIONS=''
        # 注意，x86_64的 mksquashfs4 是源码打了patch后编译的，多了 -Xpreset 9 -Xe -Xlc 0 -Xlp 2 -Xpb 2 这些选项
        # LZMA_XZ_OPTIONS='-Xpreset 9 -Xe -Xlc 0 -Xlp 2 -Xpb 2'
        mksquashfs /mnt/update/img /opt/op.squashfs -nopad -noappend -root-owned \
            ${comp} ${LZMA_XZ_OPTIONS} \
            -b $[sq_block_size/1024]k \
            -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1' \
            $xattrs -mem 20M 
    fi

    mountpoint -q  /mnt/update/img && umount /mnt/update/img

    cd ${WORK_DIR}

    sleep 5
    # openwrt 存在 auto mount，此处取消挂载
    grep -q ${lodev}p1 /proc/mounts && umount ${lodev}p1
    grep -q ${lodev}p2 /proc/mounts && umount ${lodev}p2
    sleep 1
    if [ "$IMG_FSTYPE" = 'ext4' ];then
        try_fsck=0
        while [ "$try_fsck" -le 10 ];do
            e2fsck -y -f ${lodev}p2 && break ||
            let try_fsck+1
        done
        resize2fs ${lodev}p2
    fi
    if [ "$IMG_FSTYPE" = 'squashfs' ];then
        losetup -l -O NAME -n | grep -Eqw $lodev && losetup -d $lodev
        dd if=/opt/op.squashfs of=${IMG_FILE} bs=512 seek=${part2_seek} conv=notrunc
        rm -rf /opt/op.squashfs /mnt/update/img
    fi
    sleep 1
    sync
    # squashfs 可能提前 -d 了，这里判断的逻辑兼容 ext4
    losetup -l -O NAME -n | grep -Eqw $lodev && losetup -d $lodev
    sleep 1

    [ -f "${USER_FILE}" ] && rm -f ${USER_FILE}

    # 后面的 umount / 前清理掉相关文件
    success '正在打包...'
    warning '开始写入，请勿中断...'
    if [ -f "${IMG_FILE}" ]; then
        echo 1 > /proc/sys/kernel/sysrq
        echo u > /proc/sysrq-trigger && umount / || true
        #pv FriendlyWrt.img | dd of=/dev/$block_device conv=fsync
        dd if=${IMG_FILE} of=/dev/$block_device oflag=direct conv=sparse status=progress bs=1M
        #/tmp/ddnz ${IMG_FILE} /dev/$block_device
        # success '刷机完毕，正在重启...'
        printf '%b\n' "\033[1;32m[SUCCESS] 刷机完毕，正在重启，如果重启无响应请拔插电源...\033[0m"
        echo b > /proc/sysrq-trigger
    fi
}

function opkgUpdate(){
    local domain http_code

    domain=$(grep -Ev '^\s*$|^\s*#' /etc/opkg/*.conf  | awk '{print $3}' | grep -Eo 'https?://[^/]+' | uniq | head -n1)
    if [ -n "${domain}" ];then
        http_code=$(curl --write-out '%{http_code}' --silent --output /dev/null $domain 2>/dev/null || echo 000)
        # 可联网下并且 /etc/opkg 的 mtime 大于 20 分钟则 opkg update
        if [ "$http_code" != 000 ] && [ "$http_code" != 000000 ];then
            if [[ $(( $(date +%s) - $(date +%s -r /etc/opkg ) )) -ge 1200 ]];then
                opkg update || true
                touch -m /etc/opkg
            fi
        else
            NO_NET=true
        fi
    else # slim 固件
        if grep -Eq '^\s*src.gz\s+\S+\s+file' /etc/opkg/*.conf;then
            opkg update
        fi
    fi
}

# 获取根分区所在的 block_device
# newifi d2 固件格式的 lsblk 很奇怪，日后看看
function auto_set_block_var(){
    local block rootfs_part
    rootfs_part=$(lsblk --output NAME,FSTYPE,LABEL,MOUNTPOINT | awk '($4=="/"&&tolower($3)~/rootfs/)||($2=="squashfs"&&$3=="/rom"){print $1}' | sed -r 's/[^a-zA-Z0-9]//g')
    [ -z "$rootfs_part" ] && err "自动获取根分区所在块设备失败"
    #for block in `ls -l /dev/ | awk '$1~/^br/&&$NF!~/loop|ram/{print $NF}'`;do
    for block in `ls -1 /sys/block/ | grep -Ev 'loop|ram'`;do
        if echo ${rootfs_part} | grep -Eq $block &&  [ "$rootfs_part" != "$block" ];then
            block_device=$block
            # 去掉结尾的数字，取
            part_prefix=$( echo ${rootfs_part/$block/}| sed 's#[0-9]$##' )
            return
        fi
    done
    err "无法在 /sys/block 里匹配到 $rootfs_part"
}

function main(){
    opkgUpdate
    # 有些其他固件没 findmnt 命令
    # LOCAL_FSTYPE=$(findmnt / -no FSTYPE 2>/dev/null)
    LOCAL_FSTYPE=$(df -T / | awk 'NR==2{print $2}')
    if [ -z "${FSTYPE}" ] && [ ! -f "${USER_FILE}" ] ;then
        [ -z "${LOCAL_FSTYPE}" ] && LOCAL_FSTYPE=ext4
        case "${LOCAL_FSTYPE}" in
            'overlay')
                FSTYPE=squashfs
                ;;
            'ext4')
                FSTYPE=ext4
                ;;
            *)
                err "暂不支持该文件系统: ${LOCAL_FSTYPE}"
                ;;
        esac
    fi
    [ "${VER}" == 'slim' ] && VER=-slim
    if [ -z "$VER" ] && [ -d /local_feed/ ];then
        VER=-slim
    fi
    [ "$VER" == full ] && VER=''

    [ "$TEST" = true ] && release_name=test || release_name=latest

    [ -f /etc/openwrt_release ] && source /etc/openwrt_release
    if [ -z "$MATRIX_TARGET" ];then
        board_id=$(jsonfilter -e '@["model"].id' < /etc/board.json | \
            sed -r -e 's/friendly.*,nanopi-//' )
        arch=`uname -m`
        [ $arch == 'x86_64' ] && board_id='x86_64'
    else
        board_id="$MATRIX_TARGET"
    fi

    type -t $board_id 1>/dev/bull || err "暂不支持该设备: ${board_id}"

    if [ -z "$REPO" ];then
        if [ -z "$MATRIX_REPO_NAME" ];then
            REPO=lede
            # lede immortalwrt openwrt 的 os-release 都包含 lede，非 lede 判断放后面
            #grep -qw 'immortalwrt' /etc/os-release && REPO=immortalwrt
            # lede 的 /etc/openwrt_release 里 DISTRIB_REVISION 是大 R 开头，openwrt 里是小 r 开头
            if [ "$REPO" != 'immortalwrt' ] &&  grep -Eq "DISTRIB_REVISION='r" /etc/openwrt_release;then
                REPO=openwrt
            fi
        else
            REPO=$MATRIX_REPO_NAME
        fi
    fi

    if [ -z "$IM_BRANCH" ];then
        if [ -z "$MATRIX_REPO_BRANCH" ];then
            # awk -F"[-=.']" '$1=="DISTRIB_RELEASE"&& $3!="SNAPSHOT"{printf "%s.%s\n",$3,$4}'
            IM_BRANCH=$(awk -F"[-=']" '$1=="DISTRIB_RELEASE"&& $3!="SNAPSHOT"{print $3}' /etc/openwrt_release 2>/dev/null)
            [ -z "$IM_BRANCH" ] && IM_BRANCH=master
        else
            IM_BRANCH=$MATRIX_REPO_BRANCH
        fi
    fi

    proceed_command parted
    proceed_command losetup
    proceed_command resize2fs
    proceed_command truncate coreutils-truncate
    proceed_command curl
    proceed_command wget
    proceed_command lsblk

    # 不存在本地文件离线升级，并且没网就退出
    if [ ! -f "$USER_FILE" ];then
        http_code=$(curl --write-out '%{http_code}' --silent --output /dev/null https://$repo_domain 2>/dev/null || echo 000)
        if [ "$http_code" != 200 ];then
            err "无法访问: ${repo_domain}，是否没有配置 wan 或者无法上网"
        fi
    fi
    auto_set_block_var

    # 自带的 dd 不行
    [ ! -f /usr/libexec/dd-coreutils ] && opkg install coreutils-dd

    $board_id
}

main
