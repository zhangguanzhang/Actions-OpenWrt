# https://docs.github.com/cn/actions/using-jobs/defining-outputs-for-jobs
# 设置一些 condition 给后续步骤作为判断条件和执行的值


# action 内置 env
# https://docs.github.com/cn/actions/learn-github-actions/environment-variables

# github action 和本地设置是不同的函数实现
if [ -n "${GITHUB_ENV}" ];then
function SET_ENV(){
    echo "$1=$2" >> $GITHUB_ENV
}
else
function SET_ENV(){
    export $1="$2"
}
fi

if [ -f env.sh ];then
# 主目录 source 设备的 env.sh
    if [ -n "${GITHUB_ENV}" ];then
        grep -Ev '^\s*$|^\s*#' env.sh >> $GITHUB_ENV
    else
        source env.sh
    fi
fi

if [ -n "${envOverride}" ];then
    for env_ins in `tr ',' ' ' <<< $envOverride `;do
        SET_ENV `tr '=' ' ' <<< $env_ins`
    done
fi

SET_ENV GOPROXY https://goproxy.cn,https://mirrors.aliyun.com/goproxy/,https://goproxy.io,direct
