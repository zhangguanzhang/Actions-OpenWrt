
https://github.com/coolsnowwolf/lede/issues/5681

```
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