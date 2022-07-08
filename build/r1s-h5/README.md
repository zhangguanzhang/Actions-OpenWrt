## about

内核分区使用了 11M 的样子，设备的 ram 大小是 512M ，固件解压了是 699M 大小，远大于内存大小，所以无法在线升级扩容

```
CONFIG_TARGET_KERNEL_PARTSIZE=16
CONFIG_TARGET_ROOTFS_PARTSIZE=645
```

上述情况下出来的固件

```
root@ImmortalWrt:~# df -h
Filesystem          Size  Used Avail Use% Mounted on
/dev/root           419M  419M     0 100% /rom
tmpfs               242M  776K  241M   1% /tmp
/dev/loop0          225M  154M   72M  69% /overlay
overlayfs:/overlay  225M  154M   72M  69% /
tmpfs               512K     0  512K   0% /dev
/dev/mmcblk0p1       20M   11M  9.0M  56% /mnt/mmcblk0p1
root@ImmortalWrt:~# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0 226.8M  0 loop /overlay
mmcblk0     179:0    0 974.5M  0 disk
├─mmcblk0p1 179:1    0    20M  0 part /mnt/mmcblk0p1
└─mmcblk0p2 179:2    0   645M  0 part /rom
root@ImmortalWrt:~#
```
