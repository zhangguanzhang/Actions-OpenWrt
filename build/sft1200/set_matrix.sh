# 要 json raw 字符串
echo '::set-output name=matrix::[{"name":"glnet-openwrt", "branch":"18.06", "addr":"https://github.com/gl-inet/openwrt.git"}]'
# 此步不重要，主要是 custom_pull.sh

# 这个name避免走进公共的 diy.sh里
