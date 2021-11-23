# https://github.com/klever1988/nanopi-openwrt/raw/master/scripts/autoupdate.sh
# 参考这个脚本，但是我脚本支持 squashfs 格式的升级，以及支持其他人固件切换到我的固件来
# 目前只支持r2s
#!/bin/sh

set -e

# FSTYPE=ext4,squashfs

: ${SKIP_BACK:=false} ${DEBUG:=false}
: ${TEST:=false} # 默认使用 main 分支编译的，test分支是测试阶段
: ${USER_FILE:=/opt/openwrt.img.gz} # 用户本地升级的固件文件路径，是压缩包
# 用户可以声明上面文件路径来本地不联网升级

NO_NET=''
: ${VER:=} # slim or full

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
        if [ -n "$NO_NET" ];then
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
function download(){
    local img=$1
    local fsType=$2
    local isTest=$3

}

function EnsureDockerStart(){
    local i=0
    while true;do
        if [ "$i" -eq 0 ];then
            /etc/init.d/dockerd start
            i=1
        fi
        if docker info --format '{{.DockerRootDir}}' &>/dev/null;then
            break
        fi
        sleep 2
    done
}

function r2s(){
    local block_device='mmcblk0'
    local bs part_num NEED_GROW
    proceed_command parted
    proceed_command losetup
    proceed_command resize2fs
    proceed_command truncate coreutils-truncate
    proceed_command curl
    proceed_command wget
    [ -f /usr/bin/ddnz ] && cp /usr/bin/ddnz /tmp/
    if [ ! -f /tmp/ddnz ]; then 
        wget -NP /tmp https://ghproxy.com/https://raw.githubusercontent.com/klever1988/nanopi-openwrt/zstd-bin/ddnz
        chmod +x /tmp/ddnz
    fi
    debug df -h
    mount -t tmpfs -o remount,size=870m tmpfs /tmp
    [ ! -d /sys/block/$block_device ] && block_device='mmcblk1'
    [ "$board_id" = 'x86' ] && block_device='sda'
    bs=`expr $(cat /sys/block/$block_device/size) \* 512`

    mkdir -p ${WORK_DIR}
    cd ${WORK_DIR}

    EnsureDockerStart

    if [ $(df  -m /opt | awk 'NR==2{print $4}') -lt 2400 ];then
        NEED_GROW=1
        
        warning '检测到当前未扩容，先创建一个分区挂载为 docker 数据目录'
        df -h
        parted /dev/$block_device p
        if [ ! -f '/root/.parted' ];then
            start_sec=$(parted /dev/$block_device unit s print free | awk '$1~"s"{a=$1}END{print a}')
            parted /dev/$block_device mkpart p ext4 ${start_sec} 4G
            part_num=$( parted /dev/$block_device p | awk '$5=="primary"{a=$1}END{print a}' )
            sleep 3 # 此处会自动挂载造成蛋疼
            if grep -E /dev/${block_device}p${part_num} /proc/mounts;then
                if mountpoint -q  /mnt/${block_device}p${part_num};then
                    touch /mnt/${block_device}p${part_num}/test &>/dev/null || NEED_MKFS=1
                    umount /mnt/${block_device}p${part_num}
                fi
                [ -n "$NEED_MKFS" ] && mkfs.ext4 -F /dev/${block_device}p${part_num}
            else
                mkfs.ext4 -F /dev/${block_device}p${part_num}
            fi
            echo ${part_num} > /root/.parted
        else
            part_num=$(cat /root/.parted)
        fi
        DockerRootDir=$(docker info --format '{{.DockerRootDir}}')
        /etc/init.d/dockerd stop
        mountpoint -q  ${DockerRootDir} || mount -o rw /dev/${block_device}p${part_num} ${DockerRootDir}

        if mountpoint -q  /mnt/${block_device}p${part_num};then
            umount /mnt/${block_device}p${part_num}
        fi

        EnsureDockerStart

        #mkdir -p /tmp/update/download
        #mountpoint -q  /tmp/update/download || mount /dev/${block_device}p${part_num} /tmp/update/download
        # USER_FILE=/tmp/update/download/openwrt.img.gz
        # if [ ! -f "${USER_FILE}" ];then
        #     wget https://ghproxy.com/https://github.com/zhangguanzhang/Actions-OpenWrt/releases/download/fs/openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-ext4-sysupgrade.img.gz -O ${USER_FILE}
        #     wget https://ghproxy.com/https://github.com/zhangguanzhang/Actions-OpenWrt/releases/download/fs/sha256sums -O /tmp/sha256sums
        # fi
    fi

    if [ -f "${USER_FILE}" ];then
        info "此次使用本地文件: ${USER_FILE} 来升级"
    else
        REPO=lede
        # lede immortalwrt openwrt 的 os-release 都包含 lede，非 lede 判断放后面
        #grep -qw 'immortalwrt' /etc/os-release && REPO=immortalwrt
        # lede 的 /etc/openwrt_release 里 DISTRIB_REVISION 是大 R 开头，openwrt 里是小 r 开头
        #if [ "$REPO" != 'immortalwrt' ] &&  grep -Eq "DISTRIB_REVISION='r" /etc/openwrt_release;then
        #    REPO=openwrt
        #fi

        if [ "${TEST}" != false ];then
            IMG_TAG=latest-${FSTYPE}${VER}-${REPO}
        else
            IMG_TAG=$(curl -s  https://hub.docker.com/v2/repositories/zhangguanzhang/r2s/tags/?page_size=100 | \
                jsonfilter -e '@["results"][*].name' | grep -E release | sort -rn | head -n1)
        fi
        # 没合并到 master 上暂时使用测试固件
        [ -z "${IMG_TAG}" ] && IMG_TAG=latest-${FSTYPE}${VER}-${REPO}

        if [ ! -f "${USER_FILE}" ];then
            info "开始从 dockerhub 下载包含固件的 docker 镜像，如果拉取失败，可以自己手动 docker pull registry.aliyuncs.com/zhangguanzhang/r2s:${IMG_TAG}"
            docker pull registry.aliyuncs.com/zhangguanzhang/r2s:${IMG_TAG}
            # CTR_PATH=`docker run --rm zhangguanzhang/r2s:${IMG_TAG} sh -c 'ls /openwrt*r2s*'`
            CTR_PATH=$( docker inspect registry.aliyuncs.com/zhangguanzhang/r2s:${IMG_TAG} --format '{{ .Config.Labels }}' | grep -Eo 'openwrt-.+img.gz' )
            # openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-ext4-sysupgrade.img.gz
            # openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz
            info "开始从 docker 镜像里提取固件的 tar.gz 压缩文件到: ${USER_FILE}"
            docker create --name update registry.aliyuncs.com/zhangguanzhang/r2s:${IMG_TAG}
            docker cp update:/${CTR_PATH} ${USER_FILE}
            docker cp update:/sha256sums /tmp/
            docker rm update
            IMG_EXIST=1
        fi
    fi
    if [ -f /tmp/sha256sums ];then
        file_sum=`sha256sum ${USER_FILE} | awk '{print $1}'`
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
            mkdir -p ${DockerRootDir}/update/img ${DockerRootDir}/update/img_sq
            umount /mnt/update/img
            mount --bind ${DockerRootDir}/update /mnt/update
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
    opkg list-installed | grep -E "luci-(i18n|app)-" | cut -d ' '  -f1 | \
        sort -r | xargs -n1 echo opkg install --force-overwrite > /mnt/update/img/packages_needed
    sed -i '1i opkg update' /mnt/update/img/packages_needed

    if [ "$SKIP_BACK" != false ] || [ -n "$NEED_GROW" ] ;then
        if [ -n "$NEED_GROW" ];then
            warning '注意：初版扩容，或者其他人固件升级到我的固件时候只备份网卡配置文件'
        fi
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
    if ! grep -q macaddr /etc/config/network; then
        warning '注意：由于已知的问题，“网络接口”配置无法继承，重启后需要重新设置WAN拨号和LAN网段信息'
        rm /mnt/update/img/etc/config/network;
    fi


    if [ "$IMG_FSTYPE" = 'squashfs' ];then
        proceed_command unsquashfs squashfs-tools-unsquashfs
        proceed_command mksquashfs squashfs-tools-mksquashfs
        info "开始打包 squashfs 文件系统，请耐心等待"
        unsquashfs -s ${lodev}p2 > squashfs.info
        comp=$(awk '$1=="Compression"{print $2}' squashfs.info)
        sq_block_size=$(awk '$1=="Block"{print $NF}' squashfs.info)
        xattrs='-xattrs' # CONFIG_SELINUX=y
        grep -Eq 'Xattrs.+?not' squashfs.info && xattrs='-no-xattrs'
        # nmbd samba 
        init_d_stop netdata snmpd ttyd vsftpd nmbd
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
            -comp ${comp} ${LZMA_XZ_OPTIONS} \
            -b $[sq_block_size/1024]k \
            -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1' \
            $xattrs -mem 20M 
        
        losetup -l -O NAME -n | grep -Eqw $lodev && losetup -d $lodev
        dd if=/opt/op.squashfs of=${IMG_FILE} bs=512 seek=${part2_seek} conv=notrunc
        rm -rf /opt/op.squashfs /mnt/update/img
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
    sleep 1
    sync
    # squashfs 可能提前 -d 了，这里判断的逻辑兼容 ext4
    losetup -l -O NAME -n | grep -Eqw $lodev && losetup -d $lodev
    sleep 1
    [ -n "$IMG_EXIST" ] && docker rmi registry.aliyuncs.com/zhangguanzhang/r2s:${IMG_TAG}
    [ -f "${USER_FILE}" ] && rm -f ${USER_FILE}
    [ -f '/root/.parted' ] && rm -f /root/.parted
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
            NO_NET=1
        fi
    else # slim 固件
        if grep -Eq '^\s*src.gz\s+\S+\s+file' /etc/opkg/*.conf;then
            opkg update
        fi
    fi
}

function main(){
    opkgUpdate
    if [ -z "${FSTYPE}" ] && [ ! -f "${USER_FILE}" ] ;then
        # 有些其他固件没 findmnt 命令
        # LOCAL_FSTYPE=$(findmnt / -no FSTYPE 2>/dev/null)
        LOCAL_FSTYPE=$(df -T / | awk 'NR==2{print $2}')
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

    board_id=$(jsonfilter -e '@["model"].id' < /etc/board.json | \
        sed -r -e 's/friendly.*,nanopi-//' )
    $board_id
}

main
