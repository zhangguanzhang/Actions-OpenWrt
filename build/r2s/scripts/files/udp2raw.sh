if [ 1 -eq 1 ];then
    udp_raw_file=udp2raw_arm
    svn export https://github.com/sensec/luci-app-udp2raw/trunk package/custom/luci-app-udp2raw
    VERSION=latest url=$( curl -sL https://api.github.com/repos/wangyu-/udp2raw-tunnel/releases/${VERSION} | \
        jq -r '.assets[]| select(.name=="udp2raw_binaries.tar.gz") | .browser_download_url' )
    if [ -n "$url" ];then
      wget $url -O - | \
        tar -zxvf - -C . ${udp_raw_file}
      upx -9 ${udp_raw_file}
      mkdir -p package/custom/luci-app-udp2raw/files/root/usr/bin/
      sed -ri 's#\s隧道##' package/custom/luci-app-udp2raw/files/luci/i18n/udp2raw.zh-cn.po
      mv ${udp_raw_file} package/custom/luci-app-udp2raw/files/root/usr/bin/udp2raw
      if ! grep -qw 'files/root/usr/bin/udp2raw' package/custom/luci-app-udp2raw/Makefile;then
          sed -i "/\/root\/etc\/init.d\/udp2raw/r "<(
cat <<'EOF' | sed -r 's#^\s+#\t#'
    $(INSTALL_DIR) $(1)/usr/bin
    $(INSTALL_DATA) ./files/root/usr/bin/udp2raw $(1)/usr/bin/udp2raw
    chmod 0755 $(1)/usr/bin/udp2raw
EOF
)   package/custom/luci-app-udp2raw/Makefile
      fi
    fi
fi