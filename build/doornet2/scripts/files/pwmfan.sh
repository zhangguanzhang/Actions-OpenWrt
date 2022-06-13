# https://github.com/fanck0605/openwrt-nanopi-r2s/issues/9#issuecomment-767224902

mkdir -p files/usr/bin/ files/etc/init.d/ files/etc/rc.d/
wget https://raw.githubusercontent.com/friendlyarm/friendlywrt/master-v19.07.1/target/linux/rockchip-rk3328/base-files/usr/bin/start-rk3328-pwm-fan.sh \
    -O files/usr/bin/start-rk3328-pwm-fan.sh

wget https://raw.githubusercontent.com/friendlyarm/friendlywrt/master-v19.07.1/target/linux/rockchip-rk3328/base-files/etc/init.d/fa-rk3328-pwmfan \
    -O files/etc/init.d/fa-rk3328-pwmfan

chmod 0755 files/usr/bin/start-rk3328-pwm-fan.sh  files/etc/init.d/fa-rk3328-pwmfan

# 相对路径处理，符合规范
(
    cd files/etc/rc.d/
    ln -sf ../init.d/fa-rk3328-pwmfan S96fa-rk3328-pwmfan
)
