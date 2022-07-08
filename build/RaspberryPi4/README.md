

https://www.raspberrypi.com/products/
https://zh.m.wikipedia.org/zh/%E6%A0%91%E8%8E%93%E6%B4%BE

kernel size 看刷入是使用 17M，rootfs size 为 680 时候，2022/07/26为下面情况

```
root@ImmortalWrt:~# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0 259.6M  0 loop /overlay
mmcblk0     179:0    0  29.7G  0 disk
├─mmcblk0p1 179:1    0    22M  0 part /boot
└─mmcblk0p2 179:2    0   680M  0 part /rom
root@ImmortalWrt:~# df -h
Filesystem          Size  Used Avail Use% Mounted on
/dev/root           421M  421M     0 100% /rom
tmpfs               930M  616K  929M   1% /tmp
/dev/loop0          258M   89M  170M  35% /overlay
overlayfs:/overlay  258M   89M  170M  35% /
/dev/mmcblk0p1       22M   17M  5.7M  75% /boot
tmpfs               512K     0  512K   0% /dev
root@ImmortalWrt:~# ls -l /local_feed/*.ipk | wc -l
1291
```