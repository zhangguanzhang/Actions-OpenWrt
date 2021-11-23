# 关闭 led 
# i2cset  -f -y 0 0x30 0x04 0x00


# https://github.com/openwrt/packages/pull/8477/files
if grep -wq '../perl/perlver.mk' feeds/packages/lang/perl/perlmod.mk;then
  sed -i "4r "<(
cat<<'EOF' | sed -r 's#^\s+#\t#'
ifeq ($(origin PERL_INCLUDE_DIR),undefined)
  PERL_INCLUDE_DIR:=$(dir $(lastword $(MAKEFILE_LIST)))
endif

include $(PERL_INCLUDE_DIR)/perlver.mk

EOF
  ) feeds/packages/lang/perl/perlmod.mk
fi

# https://github.com/openwrt/packages/commit/618771c3a3305df9bc925fbf1ff0f43757262c69
SED_NUM=$( grep -nw -- '--libs libcrypto libssl' feeds/packages/lang/python/python3/Makefile | cut -d':' -f1 )
  sed -i "${SED_NUM}r "<(
cat<<'EOF'
  $$$$(pkg-config --static --libs libcrypto libssl) -Wl$(comma)-rpath=$(STAGING_DIR_HOSTPKG)/lib
EOF
  ) feeds/packages/lang/python/python3/Makefile
sed -i "${SED_NUM}d " feeds/packages/lang/python/python3/Makefile



svn export https://github.com/coolsnowwolf/lede/trunk/tools/upx   tools/upx
svn export https://github.com/coolsnowwolf/lede/trunk/tools/ucl   tools/ucl
svn export https://github.com/coolsnowwolf/lede/trunk/tools/ninja tools/ninja


# tools makefile 修改内容：

if ! grep -Eq '^tools-y \+= ucl upx ninja' tools/Makefile;then
  SED_NUM=$(grep -En '^tools-.+?genext2fs$' tools/Makefile | cut -d: -f1)
  sed -i "${SED_NUM}r "<(
cat<<'EOF'
tools-y += ucl upx ninja
$(curdir)/upx/compile := $(curdir)/ucl/compile
$(curdir)/cmake/compile += $(curdir)/libressl/compile $(curdir)/ninja/compile
EOF
  ) tools/Makefile
fi

sed -ri '/foreach tool.+?\/ccache\/compile/s#xz patch,#xz patch ninja,#' tools/Makefile


# https://github.com/gl-inet/gl-feeds/issues/2 

pushd feeds/gl/libgpg-error/patches/
[ ! -f 020-gawk5-support.patch ] &&  wget https://raw.githubusercontent.com/openwrt/packages/openwrt-18.06/libs/libgpg-error/patches/020-gawk5-support.patch
[ ! -f 021-gawk5-support1.patch ] && wget https://raw.githubusercontent.com/openwrt/packages/openwrt-18.06/libs/libgpg-error/patches/021-gawk5-support1.patch
popd

# GL.iNet SFT1200 不能中继kvr无线信号的解决方法
# https://www.right.com.cn/forum/thread-7481630-1-1.html

sed -ri '875i \\tset_default ieee80211r 1' package/network/services/hostapd/files/hostapd.sh

mkdir package/community

svn export https://github.com/kenzok8/openwrt-packages/trunk/luci-app-adguardhome package/community/luci-app-adguardhome
svn export https://github.com/kenzok8/openwrt-packages/trunk/adguardhome package/community/adguardhome
svn export https://github.com/kenzok8/openwrt-packages/trunk/luci-app-aliyundrive-webdav package/community/luci-app-aliyundrive-webdav
svn export https://github.com/kenzok8/openwrt-packages/trunk/aliyundrive-webdav package/community/aliyundrive-webdav
svn export https://github.com/kenzok8/openwrt-packages/trunk/luci-app-pushbot package/community/luci-app-pushbot


svn export https://github.com/kenzok8/openwrt-packages/trunk/luci-app-openclash package/community/luci-app-openclash
rm -rf feeds/packages/libs/libcap
# 解决 openclash 的依赖 libcap-bin 问题 https://github.com/vernesong/OpenClash/issues/839#issuecomment-884605382
svn export https://github.com/openwrt/packages/branches/openwrt-21.02/libs/libcap/ feeds/packages/libs/libcap

# fullconenat, sft1200 上用不到
# svn export https://github.com/coolsnowwolf/lede/trunk/package/lean/openwrt-fullconenat package/community/openwrt-fullconenat


# 用不了, batctl-default dwan 依赖问题 
#svn checkout https://github.com/kenzok8/openwrt-packages/trunk/luci-app-easymesh
# 这个看不懂 Makefile 怎么接入 op
#svn export https://github.com/berlin-open-wireless-lab/DAWN/branches/master/  dwan

pushd package/community
if [ -d luci-app-adguardhome ];then
    sed -i '/configpath/s#/etc/AdGuardHome.yaml#/etc/config/AdGuardHome.yaml#' luci-app-adguardhome/root/etc/config/AdGuardHome
    # https://github.com/rufengsuixing/luci-app-adguardhome/issues/130
    SED_NUM=$(awk '/^start_service/,/configpath/{a=NR}END{print a}' luci-app-adguardhome/root/etc/init.d/AdGuardHome)
    sed -i "$SED_NUM"'a [ ! -f "${configpath}" ] && cp /usr/share/AdGuardHome/AdGuardHome_template.yaml ${configpath}' luci-app-adguardhome/root/etc/init.d/AdGuardHome
    # 依赖问题，固件自带了 wget ca-bundle ca-certificates
    sed -ri '/^LUCI_DEPENDS:=/s#\+(ca-certs|wget-ssl)##g' luci-app-adguardhome/Makefile
fi
if [ -d adguardhome -a ! -f 'adguardhome/files//AdGuardHome' ];then
    wget  https://static.adguard.com/adguardhome/release/AdGuardHome_linux_mipsle_softfloat.tar.gz -O - | \
      tar -zxvf -  --strip-components 2 -C adguardhome/files/ ./AdGuardHome/AdGuardHome 
    upx -9 adguardhome/files/AdGuardHome
    # 自带编译出来的 16.2M ，直接下载 upx 压缩会 9M 
    sed -ri '/GoPackage/d' adguardhome/Makefile
    SED_NUM=$(awk '$2=="Package/adguardhome/install"{print NR}' adguardhome/Makefile)
    # 下面的插入内容前面必须是tab，而不是空格
    sed -i "${SED_NUM}r "<(
cat  <<'EOF' | sed -r 's#^\s+#\t#'
  $(INSTALL_DIR) $(1)/usr/bin
  $(INSTALL_DATA) ./files/AdGuardHome $(1)/usr/bin/AdGuardHome
  chmod 0755 $(1)/usr/bin/AdGuardHome
EOF
  ) adguardhome/Makefile
  # 必须保留最后的 BuildPackage ，否则编译不出来该包
  sed -ri '/GoBinPackage,adguardhome/d' adguardhome/Makefile
fi

popd

rm -rf feeds/packages/lang/node
svn export https://github.com/openwrt/packages/branches/master/lang/node   feeds/packages/lang/node
# adg 需要，但是貌似不用也行
# svn export https://github.com/openwrt/packages/branches/master/lang/node-yarn   feeds/packages/lang/node-yarn
rm -rf feeds/packages/lang/golang
# export 导不出
#svn export https://github.com/openwrt/packages/branches/master/lang/golang feeds/packages/lang/golang
svn checkout https://github.com/openwrt/packages/trunk//lang/golang feeds/packages/lang/golang

# luci-app-ttyd 相关
rm -rf  feeds/packages/utils/ttyd
svn export https://github.com/openwrt/packages/branches/master/utils/ttyd feeds/packages/utils/ttyd
svn export https://github.com/coolsnowwolf/luci/branches/master/applications/luci-app-ttyd feeds/luci/applications/luci-app-ttyd
# 不创建软链，列表会没有它
pushd package/feeds/luci/
ln -sf ../../../feeds/luci/applications/luci-app-ttyd luci-app-ttyd
popd

# 用不了貌似，缺很多依赖
# svn export https://github.com/coolsnowwolf/luci/branches/master/applications/luci-app-turboacc feeds/luci/applications/luci-app-turboacc
# pushd package/feeds/luci/
# ln -sf ../../../feeds/luci/applications/luci-app-turboacc luci-app-turboacc
# popd

rm -rf  feeds/packages/utils/bash
svn export https://github.com/openwrt/packages/branches/master/utils/bash feeds/packages/utils/bash
# parted 
svn export https://github.com/openwrt/packages/branches/master/utils/parted package/utils/parted



# /etc/init.d/ttyd start
# /etc/rc.common: eval: line 12: uci_load_validate: not found
if ! grep -Eq '^uci_load_validate' package/system/procd/files/procd.sh;then
  SED_NUM=$(awk '$1=="_procd_wrapper"{print NR-1}' package/system/procd/files/procd.sh)
  sed -i "${SED_NUM}r "<(
cat<<'EOF' | sed -r 's#^\s+#\t#'
uci_load_validate() {
  local _package="$1"
  local _type="$2"
  local _name="$3"
  local _function="$4"
  local _option
  local _result
  shift; shift; shift; shift
  for _option in "$@"; do
    eval "local ${_option%%:*}"
  done
  uci_validate_section "$_package" "$_type" "$_name" "$@"
  _result=$?
  [ -n "$_function" ] || return $_result
  eval "$_function \"\$_name\" \"\$_result\""
}

EOF
  ) package/system/procd/files/procd.sh
fi

# /etc/init.d/AdGuardHome: line 15: extra_command: not found
if ! grep -Eq '^extra_command' package/base-files/files/etc/rc.common;then
  SED_NUM=$( awk '$1=="help()"{print NR-1}' package/base-files/files/etc/rc.common )
  sed -i "${SED_NUM}r "<(
cat<<'EOF' | sed -r 's#^\s+#\t#'

ALL_HELP=""
ALL_COMMANDS="boot shutdown depends"
extra_command() {
    local cmd="$1"
    local help="$2"

    local extra="$(printf "%-16s%s" "${cmd}" "${help}")"
    ALL_HELP="${ALL_HELP}\t${extra}\n"
    ALL_COMMANDS="${ALL_COMMANDS} ${cmd}"
}

EOF
  ) package/base-files/files/etc/rc.common
fi

# 开机启动 ntp 调整时间
# echo 'timeout 4 ntpd  -n -d -p 120.25.115.20 || true' >> ./target/linux/siflower/sf19a28-fullmask/base-files-SF19A28-GL-SFT1200/etc/rc.local
mkdir -p -m 0755 ./target/linux/siflower/sf19a28-fullmask/base-files-SF19A28-GL-SFT1200/etc/crontabs
echo '0 * * * * timeout 4 ntpd -n -d -p 120.25.115.20 || true' >> ./target/linux/siflower/sf19a28-fullmask/base-files-SF19A28-GL-SFT1200/etc/crontabs/root
# 取消注释掉的 1Ghz
sed -ri '/scaling_m.._freq/s@^#@@' ./target/linux/siflower/sf19a28-fullmask/base-files-SF19A28-GL-SFT1200/etc/rc.local

# udp2raw 
if [ 1 -eq 1 ];then
    svn export https://github.com/sensec/luci-app-udp2raw/trunk package/community/luci-app-udp2raw
    VERSION=latest url=$( curl -sL https://api.github.com/repos/wangyu-/udp2raw-tunnel/releases/${VERSION} | \
        jq -r '.assets[]| select(.name=="udp2raw_binaries.tar.gz") | .browser_download_url' )
    if [ -n "$url" ];then
      wget $url -O - | \
        tar -zxvf - -C . udp2raw_mips24kc_le
      upx -9 udp2raw_mips24kc_le
      mkdir -p package/community/luci-app-udp2raw/files/root/usr/bin/
      sed -ri 's#\s隧道##' package/community/luci-app-udp2raw/files/luci/i18n/udp2raw.zh-cn.po
      mv udp2raw_mips24kc_le package/community/luci-app-udp2raw/files/root/usr/bin/udp2raw
      if ! grep -qw 'files/root/usr/bin/udp2raw' package/community/luci-app-udp2raw/Makefile;then
          sed -i "/\/root\/etc\/init.d\/udp2raw/r "<(
cat <<'EOF' | sed -r 's#^\s+#\t#'
    $(INSTALL_DIR) $(1)/usr/bin
    $(INSTALL_DATA) ./files/root/usr/bin/udp2raw $(1)/usr/bin/udp2raw
    chmod 0755 $(1)/usr/bin/udp2raw
EOF
)   package/community/luci-app-udp2raw/Makefile
      fi
    fi
fi

# usb-rndis # https://zhangguanzhang.github.io/2021/09/03/openwrt-usb-net/
cat > package/base-files/files/etc/hotplug.d/net/01_usb-rndis.sh <<'EOF'
#!/bin/sh

# [ "$DEVICENAME" = usb0 ]
echo $DEVPATH | grep -Eq '/net/usb0$' || exit 0

. /lib/functions.sh
. /lib/netifd/netifd-proto.sh
case "$ACTION" in
	add)
        if [ -L /sys/class/net/usb0 ];then
            ip link set usb0 up
            udhcpc -i usb0
            sleep 1
            uci set network.mobile=interface
            uci set network.mobile.proto='dhcp'
            uci set network.mobile.ifname='usb0'
            # 设置本机 dns 好像会 loop
            # op_local_ip=$(ip r s | grep -Ev 'docker|usb0' | awk '$0~"src"{print $NF}')
            # uci set network.mobile.dns="${op_local_ip}"
            uci delete network.mobile.dns

            uci commit network
            sleep 1

            wan_zone_network=$(uci get firewall.@zone[1].network)

            if ! echo "$wan_zone_network" | grep -q mobile;then
                uci set firewall.@zone[1].network="$wan_zone_network mobile"
                uci commit firewall
            fi
            if ! grep -Eq '^\s*nameserver ' /etc/resolv.conf;then
                echo 'nameserver 127.0.0.1' >> /etc/resolv.conf
            fi
        fi
        ;;
esac
EOF

cat > package/base-files/files/etc/uci-defaults/zzz-default-settings <<'EOF'
# 默认密码 password
sed -i 's/root::0:0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.:0:0:99999:7:::/g' /etc/shadow

if [ -f /bin/bash ];then
  sed -i '/^root:/s#/bin/ash#/bin/bash#' /etc/passwd
fi

uci add_list system.ntp.server=120.25.115.20
uci commit system

uci set luci.main.lang=zh_cn
uci commit luci

uci set system.@system[0].timezone=CST-8
uci set system.@system[0].zonename=Asia/Shanghai
uci commit system

# dnsmasq
uci set dhcp.@dnsmasq[0].rebind_protection='0'
uci set dhcp.@dnsmasq[0].localservice='0'
uci set dhcp.@dnsmasq[0].nonwildcard='0'
# 不使用 dhcp 的 dns 
uci set dhcp.@dnsmasq[0].resolvfile=''
uci set dhcp.@dnsmasq[0].server='223.5.5.5'
uci commit dhcp


echo 'iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
echo 'iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
echo '[ -n "$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
echo '[ -n "$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 53' >> /etc/firewall.user
echo '# 允许wan口指定网段访问，一般二级路由上访问它需要' >> /etc/firewall.user
echo 'iptables -I input_wan_rule -s 192.168.0.0/16  -j ACCEPT' >> /etc/firewall.user
echo '# 只插 wan 下做旁路由时候，wan 的 zone 需要开 forward accept' >> /etc/firewall.user
echo 'iptables -I forwarding_wan_rule -s 192.168.0.0/16  -j ACCEPT' >> /etc/firewall.user


echo 'hsts=0' > /root/.wgetrc
touch /etc/crontabs/root
chmod 0600 /etc/crontabs/root

exit 0
EOF


# 修改banner
echo -e " built on "$(TZ=Asia/Shanghai date '+%Y.%m.%d %H:%M') - ${GITHUB_RUN_NUMBER}"\n -----------------------------------------------------" >> package/base-files/files/etc/banner

# TODO: 下面是一些需要修复的东西

# /etc/init.d/network reload
# /etc/rc.common: line 32: ./usr/bin/hnat_update_interface.sh: not found

# /lib/netifd/dhcp.script: line 62: netclash: not found

# $ cat bin/sf_reset.sh 
# #!/bin/sh
# /bin/led-button -l 33 &
# /sbin/jffs2reset -y && /sbin/reboot


# $ cat /etc/init.d/led 
# #!/bin/sh /etc/rc.common
# # Copyright (C) 2008 OpenWrt.org

# START=96
# USE_PROCD=1
# PROG=/usr/bin/gl_led_daemon

# load_led() {
# 	local name
# 	local sysfs
# 	local trigger
# 	local dev
# 	local ports
# 	local mode
# 	local default
# 	local delayon
# 	local delayoff
# 	local interval

# 	config_get sysfs $1 sysfs
# 	config_get name $1 name "$sysfs"
# 	config_get trigger $1 trigger "none"
# 	config_get dev $1 dev
# 	config_get ports $1 port
# 	config_get mode $1 mode
# 	config_get_bool default $1 default "nil"
# 	config_get delayon $1 delayon
# 	config_get delayoff $1 delayoff
# 	config_get interval $1 interval "50"
# 	config_get port_state $1 port_state
# 	config_get delay $1 delay "150"
# 	config_get message $1 message ""
# 	config_get gpio $1 gpio "0"
# 	config_get inverted $1 inverted "0"

# 	if [ "$trigger" = "rssi" ]; then
# 		# handled by rssileds userspace process
# 		return
# 	fi

# 	[ "$trigger" = "usbdev" ] && {
# 		# Backward compatibility: translate to the new trigger
# 		trigger="usbport"
# 		# Translate port of root hub, e.g. 4-1 -> usb4-port1
# 		ports=$(echo "$dev" | sed -n 's/^\([0-9]*\)-\([0-9]*\)$/usb\1-port\2/p')
# 		# Translate port of extra hub, e.g. 2-2.4 -> 2-2-port4
# 		[ -z "$ports" ] && ports=$(echo "$dev" | sed -n 's/\./-port/p')
# 	}

# 	[ -e /sys/class/leds/${sysfs}/brightness ] && {
# 		echo "setting up led ${name}"

# 		printf "%s %s %d\n" \
# 			"$sysfs" \
# 			"$(sed -ne 's/^.*\[\(.*\)\].*$/\1/p' /sys/class/leds/${sysfs}/trigger)" \
# 			"$(cat /sys/class/leds/${sysfs}/brightness)" \
# 				>> /var/run/led.state

# 		[ "$default" = 0 ] &&
# 			echo 0 >/sys/class/leds/${sysfs}/brightness

# 		echo $trigger > /sys/class/leds/${sysfs}/trigger 2> /dev/null
# 		ret="$?"

# 		[ $default = 1 ] &&
# 			cat /sys/class/leds/${sysfs}/max_brightness > /sys/class/leds/${sysfs}/brightness

# 		[ $ret = 0 ] || {
# 			echo >&2 "Skipping trigger '$trigger' for led '$name' due to missing kernel module"
# 			return 1
# 		}
# 		case "$trigger" in
# 		"netdev")
# 			[ -n "$dev" ] && {
# 				echo $dev > /sys/class/leds/${sysfs}/device_name
# 				for m in $mode; do
# 					[ -e "/sys/class/leds/${sysfs}/$m" ] && \
# 						echo 1 > /sys/class/leds/${sysfs}/$m
# 				done
# 				echo $interval > /sys/class/leds/${sysfs}/interval
# 			}
# 			;;

# 		"timer"|"oneshot")
# 			[ -n "$delayon" ] && \
# 				echo $delayon > /sys/class/leds/${sysfs}/delay_on
# 			[ -n "$delayoff" ] && \
# 				echo $delayoff > /sys/class/leds/${sysfs}/delay_off
# 			;;

# 		"usbport")
# 			local p

# 			for p in $ports; do
# 				echo 1 > /sys/class/leds/${sysfs}/ports/$p
# 			done
# 			;;

# 		"port_state")
# 			[ -n "$port_state" ] && \
# 				echo $port_state > /sys/class/leds/${sysfs}/port_state
# 			;;

# 		"gpio")
# 			echo $gpio > /sys/class/leds/${sysfs}/gpio
# 			echo $inverted > /sys/class/leds/${sysfs}/inverted
# 			;;

# 		switch[0-9]*)
# 			local port_mask speed_mask

# 			config_get port_mask $1 port_mask
# 			[ -n "$port_mask" ] && \
# 				echo $port_mask > /sys/class/leds/${sysfs}/port_mask
# 			config_get speed_mask $1 speed_mask
# 			[ -n "$speed_mask" ] && \
# 				echo $speed_mask > /sys/class/leds/${sysfs}/speed_mask
# 			[ -n "$mode" ] && \
# 				echo "$mode" > /sys/class/leds/${sysfs}/mode
# 			;;
# 		esac
# 	}
# }

# start_service() {
# 	[ -e /sys/class/leds/ ] && {
# 		[ -s /var/run/led.state ] && {
# 			local led trigger brightness
# 			while read led trigger brightness; do
# 				[ -e "/sys/class/leds/$led/trigger" ] && \
# 					echo "$trigger" > "/sys/class/leds/$led/trigger"

# 				[ -e "/sys/class/leds/$led/brightness" ] && \
# 					echo "$brightness" > "/sys/class/leds/$led/brightness"
# 			done < /var/run/led.state
# 			rm /var/run/led.state
# 		}

# 		config_load system
# 		config_foreach load_led led
# 	}

# 	if [ "$(cat /tmp/sysinfo/model)" = "GL-SFT1200" ]; then	
# 		gl_led off
# 		procd_open_instance
# 		procd_set_param respawn
# 		procd_set_param command "$PROG"
# 		procd_close_instance
# 	fi
# }
