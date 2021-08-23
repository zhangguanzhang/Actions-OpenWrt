opkg install /*_*_*.ipk
rm -f /*_*_*.ipk

pwd > /root/test
echo this is a test in default > /test

ls -l /tmp >> /test
ls -l /tmp/resolv.conf.d/ >> /test

if [ -s /tmp/resolv.conf.d/resolv.conf.auto ];then
    echo nameserver 223.5.5.5 >> /tmp/resolv.conf.d/resolv.conf.auto
fi
