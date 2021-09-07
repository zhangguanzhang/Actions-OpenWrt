function download_ipk(){
    local mirror_url=https://mirrors.cloud.tencent.com/lede/snapshots/packages/x86_64/packages/
    local ipk_name=$1 dir=files/
    local i=0
    while [ "$i" -le 5 ];do
        ipk_name=$(curl -s ${mirror_url} | grep -Po  'href="\K'$ipk_name'_\d[^"]+')
        [ -n "$ipk_name" ] && break
        let i++
    done
    wget ${mirror_url}${ipk_name} -O ${dir}${ipk_name}
}

# such as: download_ipk grep
