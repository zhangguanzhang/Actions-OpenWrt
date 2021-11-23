##

## ci 涉及

1. 第一阶段设置好第二阶段构建的并行参数：
   1. 例如是否 n 种仓库源，例如 r2s 使用 lede 和 immortalwrt，脚本生成参数
2. 第二阶段是构建，注意设计：
   1. 初始化设置 action 的一些 env，作为欸后续一些 step 的执行 if 判断
      1. 可能 依赖安装也许不同，这里可能也抽象成配置文件
      2. 例如 sft1200 官方自己提供源码，不会执行 feeds update 和 install
   2. 仓库源码准备，有些特殊，并不是直接拉取仓库，可能有前置行为，这里预留属性 custom_pull
   3. 是否使用 cache 给后续构建加速，也就是缓存 build_dir，staging_dir

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
