# 要 json raw 字符串
#echo '::set-output name=matrix::[{"name":"lede","branch":"master","addr":"https://github.com/coolsnowwolf/lede"}]'
# 下面日后适配天灵
# echo '::set-output name=matrix::[{"name":"lede","branch":"master","addr":"https://github.com/coolsnowwolf/lede"},{"name":"immortalwrt","branch":"master","addr":"https://github.com/immortalwrt/immortalwrt"}]'

#echo '::set-output name=matrix::[{"name":"immortalwrt","branch":"master","addr":"https://github.com/immortalwrt/immortalwrt"}]'


# echo '::set-output name=matrix::[{"name":"openwrt","branch":"openwrt-21.02","addr":"https://github.com/openwrt/openwrt"}]'

# echo '::set-output name=matrix::[{"name":"immortalwrt","branch":"openwrt-18.06-k5.4","addr":"https://github.com/immortalwrt/immortalwrt"}]'

echo '::set-output name=matrix::[{"name":"lede","branch":"master","addr":"https://github.com/coolsnowwolf/lede"},{"name":"immortalwrt","branch":"openwrt-18.06-k5.4","addr":"https://github.com/immortalwrt/immortalwrt"},{"name":"DHDAXCW","branch":"stable","addr":"https://github.com/DHDAXCW/lede-rockchip"}]'

#op21.02 target会变成r2s