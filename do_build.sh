#!/bin/bash
# OpenWrt 编译脚本 - CMCC PZ-L8
# 此脚本使用 nohup 在后台运行，不受终端超时限制

set -e

# 必须设置此变量以允许 root 编译
export FORCE_UNSAFE_CONFIGURE=1

# 进入源码目录
cd /workspace/openwrt

# 记录开始时间
echo "========================================" >> /tmp/openwrt_build.log
echo "编译开始: $(date)" >> /tmp/openwrt_build.log
echo "========================================" >> /tmp/openwrt_build.log

# 开始编译 - 使用所有 CPU 核心
make -j$(nproc) V=s

# 记录结束时间
echo "========================================" >> /tmp/openwrt_build.log
echo "编译完成: $(date)" >> /tmp/openwrt_build.log
echo "========================================" >> /tmp/openwrt_build.log
