
https://github.com/coolsnowwolf/lede/issues/5681

```
root@OpenWrt:~# lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0 280.3M  0 loop /overlay
mmcblk0     179:0    0  29.7G  0 disk
├─mmcblk0p1 179:1    0    18M  0 part /mnt/mmcblk0p1
└─mmcblk0p2 179:2    0   656M  0 part /rom
root@OpenWrt:~# df -h
Filesystem          Size  Used Avail Use% Mounted on
/dev/root           376M  376M     0 100% /rom
tmpfs               998M  780K  997M   1% /tmp
/dev/loop0          279M   89M  190M  32% /overlay
overlayfs:/overlay  279M   89M  190M  32% /
tmpfs               512K     0  512K   0% /dev
/dev/mmcblk0p1       18M   13M  5.0M  72% /mnt/mmcblk0p1
root@OpenWrt:~# ls -l /local_feed/*.ipk | wc -l
1202
root@OpenWrt:~# cat /etc/board.json
{
	"model": {
		"id": "friendlyarm,nanopi-neo3",
		"name": "FriendlyElec NanoPi NEO3"
	},
	"network": {
		"lan": {
			"ifname": "eth0",
			"protocol": "static"
		}
	}
}
```