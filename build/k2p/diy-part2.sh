
mkdir package/community

if [ -d feeds/others/luci-app-adguardhome ];then
    pushd feeds/others/
    sed -i '/configpath/s#/etc/AdGuardHome.yaml#/etc/config/AdGuardHome.yaml#' luci-app-adguardhome/root/etc/config/AdGuardHome
    # https://github.com/rufengsuixing/luci-app-adguardhome/issues/130
    SED_NUM=$(awk '/^start_service/,/configpath/{a=NR}END{print a}' luci-app-adguardhome/root/etc/init.d/AdGuardHome)
    sed -i "$SED_NUM"'a [ ! -f "${configpath}" ] && cp /usr/share/AdGuardHome/AdGuardHome_template.yaml ${configpath}' luci-app-adguardhome/root/etc/init.d/AdGuardHome
    # 依赖问题，固件自带了 wget ca-bundle ca-certificates
    sed -ri '/^LUCI_DEPENDS:=/s#\+(ca-certs|wget-ssl)##g' luci-app-adguardhome/Makefile
    popd
fi
if [ -d feeds/others/adguardhome -a ! -f 'feeds/others/adguardhome/files/AdGuardHome' ];then
    pushd feeds/others/
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
  popd
fi


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

chmod a+x ${GITHUB_WORKSPACE}/build/scripts/*.sh
\cp -a ${GITHUB_WORKSPACE}/build/scripts/update.sh files/

# 修改banner
echo -e " built on "$(TZ=Asia/Shanghai date '+%Y.%m.%d %H:%M') - ${GITHUB_RUN_NUMBER}"\n -----------------------------------------------------" >> package/base-files/files/etc/banner
