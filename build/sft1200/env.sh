#!/bin/bash

UdateFeeds=false
InstallFeeds=false

UseCache=true
#=自动获取时间差，在缓存开启下，action的剩余6小时的最后半小时失败，保证后续上传缓存步骤运行
AutoBuildTimeOut=true

MakeDownload=false
ClearPkg=false
