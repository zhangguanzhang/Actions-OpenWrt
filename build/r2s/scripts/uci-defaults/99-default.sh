# ipk
opkg install /*_*_*.ipk
rm -f /*_*_*.ipk

if [ -s /tmp/resolv.conf.d/resolv.conf.auto ];then
    echo nameserver 223.5.5.5 >> /tmp/resolv.conf.d/resolv.conf.auto
fi

