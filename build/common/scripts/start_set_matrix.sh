#!/bin/bash

if [ ! -f /usr/local/bin/yq ];then
    #curl -sLo /usr/local/bin/yq  https://github.com/$( curl -sL https://github.com/mikefarah/yq/releases/latest | grep -Pom1 'href="/\K.+?yq_linux_amd64' )
    curl -sLo /usr/local/bin/yq  $(curl -L https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.assets[]|select(.name|match("linux_amd64$"))|.browser_download_url')
    sudo chmod a+x /usr/local/bin/yq
fi

if [ "$1" = set ];then
    repository_dispatch_file=$(grep -P '^\s+repository_dispatch:' .github/workflows/*.yml | awk -F: '{print $1}')
    tr -cd '\11\12\15\40-\176' < ${repository_dispatch_file}  > ${repository_dispatch_file}.new
    #yq '.on.workflow_dispatch.inputs' ${repository_dispatch_file}.new > input.yml
    yq '.on.workflow_dispatch.inputs|to_entries|.[]|{.key: .value.default}' ${repository_dispatch_file}.new > /tmp/var.yml


    # 不为空则是 input 触发
    if [ -n "$(yq '.event.inputs //""' /tmp/github)" ];then
        yq -P '.event.inputs' /tmp/github >> /tmp/var.yml
    fi

    # 不为空则是 dispatch 触发
    if [ -n "$(yq '.event.client_payload //""' /tmp/github)" ];then
        yq -P '.event.client_payload' /tmp/github | sed -r 's#^device:#target:#' >> /tmp/var.yml
    fi

    sed -r 's#: #=#' /tmp/var.yml > /tmp/var.sh

    tac /tmp/var.yml | awk '!a[$1]++' | yq -o=json -I=0 > /tmp/var.json

    source /tmp/var.sh

    if [ ! -d "${GITHUB_WORKSPACE}/build/${target}" ];then
        echo "no such target: ${target}"
        exit 2
    fi

    echo config: ${config}
    if [ -z "${repo_json}" ] ;then
        bash ${GITHUB_WORKSPACE}/build/${target}/set_matrix.sh
    else # [{"name":"openwrt","branch":"master","addr":"https://github.com/openwrt/openwrt"}]
        echo "::set-output name=matrix::${repo_json}"
    fi

    echo "::set-output name=input::$(cat /tmp/var.json)"

    cat /tmp/var.json
fi

if [ ! -f /tmp/var.sh ];then
    yq -P /tmp/github.json | sed -r 's#: #=#' > /tmp/var.sh
    cat /tmp/var.sh
    source /tmp/var.sh
    cat /tmp/var.sh >>  $GITHUB_ENV
fi