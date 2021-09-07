# kodexplorer 提前下载
# 会和 apcupsd 冲突
if grep -Eq '^CONFIG_PACKAGE_luci-app-kodexplorer=y' .config;then
    mkdir -p files/opt/kodexplorer
    # curl -s https://api.kodcloud.com/?app/version
    wget --no-check-certificate https://static.kodcloud.com/update/download/kodbox.$(
        curl -s  https://api.github.com/repos/kalcaddle/kodbox/releases/latest | jq -r .name | cut -d " " -f 1

    ).zip -O /tmp/kodbox.zip
    unzip -q  /tmp/kodbox.zip  -d files/opt/kodexplorer
    rm -f /tmp/kodbox.zip
fi