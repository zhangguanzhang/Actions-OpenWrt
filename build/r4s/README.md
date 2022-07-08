
https://wiki.friendlyelec.com/wiki/index.php/NanoPi_R4S/zh

R4S【企业版】内置一颗具有全球唯一MAC地址的EEPROM芯片(型号:24AA025E48T)，该MAC地址永久存在，且无法被修改。
R4S【标准版】不带此芯片，但会根据其他硬件ID由软件自动生成一个MAC地址。除此之外，其他完全相同。
【标准版】不带全球唯一MAC地址芯片，【企业版】带全球唯一MAC地址芯片，【标准版】和【企业版】均使用同样的网卡芯片（RealTek RTL8211E 和R8111H），详细信息请查看下方硬件配置说明。个人用户可选择【标准版】，企业用户推荐选择【企业版】


先安装i2c工具, 用如下命令:
```
opkg install i2c-tools

# 然后通过如下命令可以读取 EEPROM 中的 Mac Address, 仅适用于有 EEPROM 芯片的型号:

i2ctransfer -y 2 w1@0x51 0xfa r6

#会输出类拟如下格式的Mac Address:

0x68 0x27 0x19 0xa5 0x2d 0xdf
如果命令出错, 则表示没有内建EEPROM芯片.
```

网卡驱动必须要 r8168 或者 8169 ，不要抄 https://github.com/SuLingGG/OpenWrt-Rpi/blob/31c574d043d65328d6c8d7fb9cab388941336445/config/rockchip/armv8.config#L36
