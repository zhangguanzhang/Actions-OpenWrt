#!/bin/bash
EnableDocker=true

UdateFeeds=true
InstallFeeds=true

UseCache=true
# 自动获取时间差，在缓存开启下，action的剩余6小时的最后半小时失败，保证后续上传缓存步骤运行
AutoBuildTimeOut=true

MakeDownload=true
ClearPkg=false

firmware_wildcard=r4s
