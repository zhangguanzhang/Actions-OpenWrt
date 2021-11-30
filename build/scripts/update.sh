# https://raw.githubusercontent.com/klever1988/nanopi-openwrt/master/scripts/autoupdate.sh
# 参考这个脚本，目前只支持r2s
#!/bin/sh

set -e

# FSTYPE=ext4,squashfs

: ${SKIP_BACK:=false} ${DEBUG:=false}
: ${TEST:=false} # 默认使用 main 分支编译的，test分支是测试阶段
: ${USER_FILE:=/opt/openwrt.img.gz} # 用户本地升级的固件文件路径，是压缩包
# 用户可以声明上面文件路径来本地不联网升级



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
        printf '%b\n' "\033[1;91m[DEBUG] $@\033[0m"
        $@
    fi
}

function proceed_command() {
	if ! command -v $1 &> /dev/null; then opkg install --force-overwrite $1; fi
	if ! command -v $1 &> /dev/null; then err "'$1'命令不可用，升级中止"; fi
}


function download(){
    local img=$1
    local fsType=$2
    local isTest=$3

}

function r2s(){
    local block_device='mmcblk0'
    local bs
    proceed_command parted
    proceed_command losetup
    proceed_command resize2fs
    proceed_command truncate
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

    if [ -f "${USER_FILE}" ];then
        info "此次使用本地文件: ${USER_FILE} 来升级"
    else
        if [ -z "$VER" ];then
            if [ "${TEST}" != false ];then
                VER=latest-${FSTYPE}
            else
                VER=$(curl -s  https://hub.docker.com/v2/repositories/zhangguanzhang/r2s/tags/?page_size=100 |\
                    jsonfilter -e '@["results"][*].name' | grep -E release | sort -rn | head -n1)
            fi
        fi
        if [ ! -f "${USER_FILE}" ];then
            info "开始从 dockerhub 下载包含固件的 docker 镜像，镜像名: zhangguanzhang/r2s:${VER}"
            docker pull zhangguanzhang/r2s:${VER}
            CTR_PATH=`docker run --rm zhangguanzhang/r2s:${VER} sh -c 'ls /openwrt*r2s*'`
            # openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-ext4-sysupgrade.img.gz
            # openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz
            info "开始从 docker 镜像里提取固件的 tag.gz 文件到: ${USER_FILE}"
            docker create --name update zhangguanzhang/r2s:${VER}
            docker cp update:${CTR_PATH} ${USER_FILE}
            docker rm update
        fi
    fi
    if [ -f "${USER_FILE}" ] && [ ! -f "${USE_FILE}" ];then
        info "开始解压 ${USER_FILE} 到 ${USE_FILE}"
        gzip -dc ${USER_FILE} > ${USE_FILE} || true
        debug ls -lh ${WORK_DIR}
        success "解压固件文件到: ${USE_FILE}"
    fi 
    truncate -s $bs $USE_FILE

    parted $USE_FILE resizepart 2 100%

    lodev=$(losetup -f)
    losetup -P $lodev $USE_FILE
    if [ "$SKIP_BACK" == false ];then
        mkdir -p /mnt/img
        mount -t ext4 ${lodev}p2 /mnt/img
        success '解压已完成，准备编辑镜像文件，写入备份信息'
        sleep 1
        debug df -h
        sysupgrade -b back.tar.gz
        tar zmxf back.tar.gz -C /mnt/img # -m 忽略时间戳的警告
        debug df -h
        if ! grep -q macaddr /etc/config/network; then
            warning '注意：由于已知的问题，“网络接口”配置无法继承，重启后需要重新设置WAN拨号和LAN网段信息'
            rm /mnt/img/etc/config/network;
        fi
        success '备份文件已经写入，移除挂载'
        umount /mnt/img
        rm back.tar.gz
    fi

    cd ${WORK_DIR}

    sleep 1
    grep -q ${lodev}p1 /proc/mounts && umount ${lodev}p1
    grep -q ${lodev}p2 /proc/mounts && umount ${lodev}p2

    e2fsck -yf ${lodev}p2 || true
    resize2fs ${lodev}p2

    losetup -d $lodev
    success '正在打包...'
    warning '开始写入，请勿中断...'
    if [ -f "${IMG_FILE}" ]; then
        echo 1 > /proc/sys/kernel/sysrq
        echo u > /proc/sysrq-trigger && umount / || true
        #pv FriendlyWrt.img | dd of=/dev/$block_device conv=fsync
        /tmp/ddnz ${IMG_FILE} /dev/$block_device
        success '刷机完毕，正在重启...'
        echo b > /proc/sysrq-trigger
    fi
}

function opkgUpdate(){
    local domain http_code

    domain=$(grep -Ev '^\s*$|^\s*#' /etc/opkg/*.conf  | awk '{print $3}' | grep -Eo 'https?://[^/]+' | uniq | head -n1)
    http_code=$(curl --write-out '%{http_code}' --silent --output /dev/null $domain 2>/dev/null || echo 000)
    # 可联网下并且 /etc/opkg 的 mtime 大于 20 分钟则 opkg update
    if [ "$http_code" != 000 ] && [[ $(( $(date +%s) - $(date +%s -r /etc/opkg ) )) -ge 1200 ]];then
        opkg update || true
        touch -m /etc/opkg
    fi
}

function main(){
    opkgUpdate
    if [ -z "${FSTYPE}" ] && [ ! -f "${USER_FILE}" ] ;then
        LOCAL_FSTYPE=$(findmnt / -no FSTYPE 2>/dev/null)
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

    board_id=$(jsonfilter -e '@["model"].id' < /etc/board.json | \
        sed -r -e 's/friendly.*,nanopi-//' )
    $board_id
}

main
