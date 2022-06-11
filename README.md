## 固件说明

### 支持的设备列表

1. `r2s`
2. `x86_64`
3. `sft1200`
4. `k2p`
5. `N1`

`r2s` 和 `x86_64` 的固件经过测试，推荐使用 `slim-squashfs` 本地源的版本，可以在下面 `latest` 或者 `test` 的 release 下载：

```
https://github.com/zhangguanzhang/Actions-OpenWrt/releases/tag/latest
https://github.com/zhangguanzhang/Actions-OpenWrt/releases/tag/test
# 上面的 latest 没有就用 test的，下载慢可以下面的 gh 代理
# https://github.cooluc.com/
```

`latest` 分支存放最新稳定的，`test` 分支是有问题的时候我 check 后尝试的修复，以及实验了稳定的包会转到 `latest`

### 在线升级

目前 `r2s` 和 `x86_64` 的固件可以在线升级，但是要求：内存大于等于 1G，容量大于等于 3G，升级步骤为下：

1. r2s tf 卡推荐使用软件 `balenaEtcher-Portable` ，压缩包里是 img 的话会自动解压刷入，`x86_64` 在导入成硬盘后，给硬盘扩容，例如添加最少 2G 容量
2. 配置好 wan 口（接上级路由做 dhcp 客户端还是 ppoe 拨号都行）或者你的 x86_64 单网口，确保路由器能上网
3. ssh 上去执行 `bash -x /update.sh` ，如果升级失败，请提 issue 贴日志，r2s 升级死机的话可以试试升级过程物理降温。
4. 默认密码均为 `password` ，路由器 ip 你可以电脑接它的 lan 后看网关 IP
5. 初次升级的同时会扩容，**扩容完只有两个分区，剩余空间所有目录均可享用**，升级完后连上去，可以自行安装想要的软件源，例如下面
   1. `opkg update`
   2. `opkg install luci-app-dockerman`
6. 推荐使用 `squashfs` 格式固件，因为 `ext4` 格式的断电关机会有几率开机变成根分区只读，我的 r2s 和其他人都遇到过。
7. x86_64 目前只有 `squashfs-combined-efi.img` 格式，有其他 `vmdk` 之类格式的需求的话可以帮忙测的话，可以提
8. 理论上有相关命令的话都可以从别人的固件切换到我的固件上，可以下载我的升级脚本执行：
   1. `wget https://raw.githubusercontent.com/zhangguanzhang/Actions-OpenWrt/main/build/scripts/update.sh`
   2. `SKIP_BACK=1 VER=slim FSTYPE=squashfs bash -x /update.sh`

## ci 涉及

1. 创建 img 文件，挂载使用 zstd 成目录，整个源码目录都会被 zstd 压缩
2. 然后使用 gh cli 登录和上传 split 文件，后续下载合并后解压再 mount img 成目录，就是缓存了之前的构建结果了


## 分隔

下面的内容是笔记，没整理，不要照抄执行

## 构建

机器最好 100G 以上

```
docker pull openwrtorg/sdk:x86_64-openwrt-21.02


git clone https://github.com/coolsnowwolf/lede.git --depth 1
cd lede

docker run --name openwrt --rm -tid -v $PWD:/home/build/openwrt openwrtorg/sdk:x86_64-openwrt-21.02

docker exec -ti openwrt bash

echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
echo "src-git others https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default



./scripts/feeds update -a

./scripts/feeds install -a

rm -rf feeds/small/ipt2socks
rm -rf feeds/small/pdnsd-alt
rm -rf package/lean/kcptun
rm -rf package/lean/trojan
rm -rf feeds/small/v2ray-plugin

make defconfig
./scripts/diffconfig.sh > seed.config
```

```
# CONFIG_TARGET_IMAGES_GZIP is not set
```

```
CONFIG_TARGET_IMAGES_GZIP=y

CONFIG_TARGET_ROOTFS_PARTSIZE=2048
```

```
Target System (x86)  --->   目标系统（x86）
Subtarget (x86_64)  --->   子目标（x86_64）
Target Profile (Generic)  --->目标配置文件（通用）
Target Images  ---> 保存目标镜像的格式
Global build settings  --->      全局构建设置
Advanced configuration options (for developers)  ---- 高级配置选项（适用于开发人员）
Build the OpenWrt Image Builder 构建OpenWrt图像生成器
Build the OpenWrt SDK构建OpenWrt SDK
Package the OpenWrt-based Toolchain打包基于OpenWrt的工具链
Image configuration  ---> 图像配置
Base system  --->     基本系统
Administration  --->     管理
Boot Loaders  --->引导加载程序
Development  --->   开发
Extra packages  --->  额外包
Firmware  --->固件
Fonts  --->字体
Kernel modules  --->  内核模块
Languages  --->语言
Libraries  --->  库
LuCI  --->      LuCI
Mail  --->邮件
Multimedia  --->多媒体
Network  --->网络
Sound  ---> 声音
Utilities  --->实用程序
Xorg  --->Xorg
```

文件格式区别
1：固件文件名中带有 ext4 字样的文件为搭载 ext4 文件系统固件，ext4 格式的固件更适合熟悉 Linux 系统的用户使用，在 Linux 下可以比较方便地调整 ext4 分区的大小；

2：固件文件名中带有 squashfs 字样的文件为搭载 squashfs 文件系统固件，而 squashfs 格式的固件适用于 “不折腾” 的用户，其优点是可以比较方便地进行系统还原，哪怕你一不小心玩坏固件，只要还能进入控制面板或 SSH，就可以很方便地进行 “系统还原操作”。

3：固件文件名中带有 sysupgrade 字样的文件为升级 OpenWrt 所用的固件，无需解压 gz 文件，可直接在 Luci 面板中升级。

4：rootfs的镜像，不带引导，可自行定义用 grub 或者 syslinux 来引导，存储区为 ext4。（小白不建议）

1：config.buildinfoOpenWrt --------------------------------------------------------------------------------编译配置文件

2：openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-ext4-sysupgrade.img.gz--------------------------Ext4 格式固件

3：openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-rootfs.tar.gz---------------------------------------RootFS 文件

4：openwrt-rockchip-armv8-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz---------------------Squashfs 格式固件

5：openwrt-rockchip-armv8-friendlyarm_nanopi-r2s.manifest------------------------------------------ 固件内已集成软件包列表

6：packages-server.zip-------------------------------------------------------------------------------------IPK 软件包归档

7：sha256sums--------------------------------------------------------------------------------------------------------固件完整性校验文件

8：Source code.zip-----------------------------------------------------------------------------------------源代码.zip

9：Source code(tar.gz)-------------------------------------------------------------------------------------源代码.tar.gz

https://www.right.com.cn/forum/thread-3682029-1-1.html

## 参考
- https://mlapp.cn/1009.html
- https://www.v2rayssr.com/openwrtimg.html/comment-page-1
- https://mianao.info/2020/05/05/%E7%BC%96%E8%AF%91%E6%9B%B4%E6%96%B0OpenWrt-PassWall%E5%92%8CSSR-plus%E6%8F%92%E4%BB%B6

dnsmasq 取消 `/etc/resolv.conf` 里的 `nameserver ::1`

```
cat /etc/init.d/dnsmasq 
[ -e /proc/sys/net/ipv6 ] && DNS_SERVERS="$DNS_SERVERS ::1"

/etc/init.d/dnsmasq reload
```

https://www.youtube.com/watch?v=35ImdukpmyY


https://openwrt.org/zh/docs/guide-user/additional-software/imagebuilder


