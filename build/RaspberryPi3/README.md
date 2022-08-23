

https://www.raspberrypi.com/products/
https://zh.m.wikipedia.org/zh/%E6%A0%91%E8%8E%93%E6%B4%BE

kernel size 看刷入是使用 17M，rootfs size 为 680 时候，2022/07/26为下面情况

```
root@ImmortalWrt:~# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0 248.3M  0 loop /overlay
mmcblk0     179:0    0  29.7G  0 disk
├─mmcblk0p1 179:1    0    22M  0 part /boot
└─mmcblk0p2 179:2    0   670M  0 part /rom
root@ImmortalWrt:~# df -h
Filesystem          Size  Used Avail Use% Mounted on
/dev/root           422M  422M     0 100% /rom
tmpfs               460M   68K  460M   1% /tmp
/dev/loop0          247M   85M  162M  35% /overlay
overlayfs:/overlay  247M   85M  162M  35% /
/dev/mmcblk0p1       22M   18M  4.5M  80% /boot
tmpfs               512K     0  512K   0% /dev
root@ImmortalWrt:~# ls -l /local_feed/*.ipk | wc -l
1300
root@ImmortalWrt:~# cat /etc/board.json
{
	"model": {
		"id": "raspberrypi,3-model-b",
		"name": "Raspberry Pi 3 Model B Rev 1.2"
	},
	"network": {
		"lan": {
			"ifname": "eth0",
			"protocol": "static"
		}
	}
}
```
