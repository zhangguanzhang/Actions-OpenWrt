
## 说明

files 目录没被打包，以后再看

### target 选择

```
Target System 选择 MediaTek Ralink MIPS
Subtarget选择MT7621 based boards
Target Profile选择Phicomm K2P
```

### 闭源驱动

https://github.com/coolsnowwolf/lede/issues/9384#issuecomment-1125375453

默认即可，不需要开 `luci-app-mtwifi`

酸酸乳开启 xray 之类的就会容量爆了无法编译出 `openwrt-ramips-mt7621-phicomm_k2p-squashfs-sysupgrade.bin`

### 刷机

刷好 breeed 后，恢复出厂设置，和固件备份，eeprom 和编程器固件都备份。然后固件更新 点击固件选 `openwrt-ramips-mt7621-phicomm_k2p-squashfs-sysupgrade.bin` 后，内存布局选斐讯，然后刷完等待

## 固件信息

```
root@OpenWrt:~# df -h
Filesystem          Size  Used Avail Use% Mounted on
/dev/root            10M   10M     0 100% /rom
tmpfs                60M  560K   59M   1% /tmp
tmpfs                60M  1.2M   59M   2% /tmp/root
tmpfs               512K     0  512K   0% /dev
/dev/mtdblock7      3.3M  536K  2.8M  17% /overlay
overlayfs:/overlay  3.3M  536K  2.8M  17% /
root@OpenWrt:~# lsblk
NAME      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
mtdblock0  31:0    0  192K  1 disk 
mtdblock1  31:1    0   64K  1 disk 
mtdblock2  31:2    0   64K  1 disk 
mtdblock3  31:3    0  320K  1 disk 
mtdblock4  31:4    0 15.4M  0 disk 
mtdblock5  31:5    0  2.4M  1 disk 
mtdblock6  31:6    0 12.9M  1 disk /rom
mtdblock7  31:7    0  3.3M  0 disk /overlay
root@OpenWrt:~# free -h
              total        used        free      shared  buff/cache   available
Mem:          118Mi        55Mi        27Mi       1.0Mi        35Mi        20Mi
Swap:            0B          0B          0B
root@OpenWrt:~# lscpu
Architecture:          mips
  Byte Order:          Little Endian
CPU(s):                4
  On-line CPU(s) list: 0-3
Model name:            -
  Model:               MIPS 1004Kc V2.15
  Thread(s) per core:  2
  Core(s) per socket:  2
  Socket(s):           1
  BogoMIPS:            598.01
  Flags:               mips16 dsp mt
Caches (sum of all):   
  L1d:                 64 KiB (2 instances)
  L1i:                 64 KiB (2 instances)
  L2:                  256 KiB (1 instance)
root@OpenWrt:~# iperf3 -s
-----------------------------------------------------------
Server listening on 5201 (test #1)
-----------------------------------------------------------
Accepted connection from 192.168.1.137, port 10149
[  5] local 192.168.1.1 port 5201 connected to 192.168.1.137 port 10150
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec   100 MBytes   838 Mbits/sec                  
[  5]   1.00-2.00   sec   108 MBytes   907 Mbits/sec                  
[  5]   2.00-3.00   sec  99.4 MBytes   833 Mbits/sec                  
[  5]   3.00-4.00   sec  66.8 MBytes   560 Mbits/sec                  
[  5]   4.00-5.00   sec  65.6 MBytes   550 Mbits/sec                  
[  5]   5.00-6.00   sec   106 MBytes   886 Mbits/sec                  
[  5]   6.00-7.00   sec   106 MBytes   888 Mbits/sec                  
[  5]   7.00-8.00   sec   106 MBytes   892 Mbits/sec                  
[  5]   8.00-9.00   sec  69.2 MBytes   580 Mbits/sec                  
[  5]   9.00-10.00  sec  89.2 MBytes   751 Mbits/sec                  
[  5]  10.00-10.00  sec   256 KBytes   790 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-10.00  sec   916 MBytes   768 Mbits/sec                  receiver
```
