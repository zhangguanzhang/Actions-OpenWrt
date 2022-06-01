# 手动步骤参 clone.sh.old
# 但是要适配我的缓存步骤，所以改造成下面的

# wget https://raw.githubusercontent.com/gl-inet/gl-infra-builder/main/config-siflower-18.x.yml
# revision=$(grep -Po 'revision:\s*\K\S+' config-siflower-18.x.yml )
# branch=$(grep -Po 'branch:\s*\K\S+' config-siflower-18.x.yml)
# reset_commit=$revision

# yml_file_path=$(readlink -f config-siflower-18.x.yml)

# if [ "$CACHE" = false ];then
#     git clone https://github.com/Siflower/1806_SDK.git
#     ( 
#         cd 1806_SDK
#         git checkout $branch
#         # 有 revision 就用 revision ，没就用 branch
#         [ -z "revision" ] && reset_commit=$branch
#         git fetch && git reset --hard origin/${reset_commit} && git clean -df
#         rm -rf profiles
#     )
    
#     rm -rf  1806_SDK/openwrt-18.06/profiles/*
#     # 只有一个文件 gen_config.py 内容还是一样的，不过跟着 setup.py 走吧
#     svn export --force https://github.com/gl-inet/gl-infra-builder/trunk/scripts/ scripts

#     if grep -Pq 'files_folders' $yml_file_path;then
#         # 脚本里有 files_folders 拷贝，如果未来加上了这里没更新就报错
#         echo "需要更新此处逻辑"
#         exit 2
#     fi
#     # 打补丁
#     # 创建软链

# fi


if [ -d 'openwrt/.git' ]; then
    cd openwrt && rm -f zerospace && git config --local user.email "action@github.com" && git config --local user.name "GitHub Action"
    git fetch && git reset --hard origin/main && git clean -df
else
    sudo chown $USER:$(id -gn) openwrt && git clone -b main --single-branch https://github.com/gl-inet/gl-infra-builder openwrt
    cd openwrt
fi


python3 setup.py -c config-siflower-18.x.yml
cd openwrt-18.06/siflower/openwrt-18.06/
./scripts/gen_config.py target_siflower_gl-sft1200
    

ln -sf  $PWD $GITHUB_WORKSPACE/openwrt


echo "BaseDir=${PWD}" >> $GITHUB_ENV
