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

SET_ENV UdateFeeds true
SET_ENV InstallFeeds true

SET_ENV UseCache true
# 自动获取时间差，在缓存开启下，action的剩余6小时的最后半小时失败，保证后续上传缓存步骤运行
SET_ENV AutoBuildTimeOut false

SET_ENV MakeDownload true
SET_ENV ClearPkg false


# CONFIG_IB=y .config 里开启
#echo 'UseImagebuilder=false'  >> $GITHUB_ENV

> ${GITHUB_WORKSPACE}/common.buildinfo

if [ -n "${envOverride}" ];then
    echo 'envOverride: ' $envOverride
    for env_ins in `tr ',' ' ' <<< "${envOverride}" `;do
        SET_ENV `tr '=' ' ' <<< $env_ins`
    done
fi
