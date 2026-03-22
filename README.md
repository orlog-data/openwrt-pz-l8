# CMCC PZ-L8 OpenWrt 编译快速指南

## 快速开始

### 方法一：使用自动构建脚本

```bash
# 进入项目目录
cd /workspace/openwrt-pz-l8

# 执行完整构建
./build.sh --all
```

### 方法二：手动执行步骤

```bash
# 1. 克隆 OpenWrt 源码
git clone https://github.com/openwrt/openwrt.git /workspace/openwrt
cd /workspace/openwrt

# 2. 应用 PR 补丁
curl -L "https://github.com/openwrt/openwrt/pull/21495.patch" | git apply
curl -L "https://github.com/openwrt/openwrt/pull/21496.patch" | git apply

# 3. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 4. 复制配置文件
cp /workspace/openwrt-pz-l8/config-pz-l8 .config
make defconfig

# 5. 下载源码
make download -j$(nproc)

# 6. 编译
make -j$(nproc) V=s
```

## PR 说明

### PR #21495: ath11k smallbuffers

**目的**：为 256MB 内存的 IPQ50xx 设备优化 WiFi 内存占用

**效果**：
- 内存占用从 ~138MB 降至 ~71MB
- 可在 256MB 设备上正常使用 WiFi

**修改内容**：
- 添加 `kmod-ath11k-smallbuffers` 包
- 添加相关内核补丁

### PR #21496: PZ-L8 双 CPU 链接

**目的**：启用 PHY-to-PHY CPU 链接，实现 2Gbps 聚合带宽

**网络拓扑**：
```
IPQ5018 MAC0 (GE Phy) ←→ QCA8337 Phy4 (MDI)
IPQ5018 MAC1 (Uniphy) ←→ QCA8337 SerDes (SGMII)
```

**修改内容**：
- 设备树更新
- DSA 驱动补丁
- 网络配置更新

## 软件包说明

### 保留组件

| 类别 | 组件 | 说明 |
|------|------|------|
| 核心 | base-files, procd-ujail, netifd, uci | 基础系统 |
| 网络 | dropbear, uclient-fetch | SSH 和下载工具 |
| 无线 | kmod-ath11k-smallbuffers, wpad-mesh-mbedtls | WiFi 驱动和认证 |
| Mesh | wpad-mesh-mbedtls, usteer | Mesh 网络支持 |
| LuCI | luci-base, luci-mod-admin-full | Web 管理界面 |
| 语言 | luci-i18n-*-zh-cn | 中文界面 |

### 移除组件

| 类别 | 组件 | 说明 |
|------|------|------|
| DNS | dnsmasq, dnsmasq-full | DNS 服务器 |
| DHCP | odhcpd-ipv6only | DHCP 服务器 |
| 防火墙 | firewall4, kmod-nft-*, nftables | 防火墙组件 |

## 输出文件

编译完成后，固件位于：

```
/workspace/openwrt/bin/targets/qualcommax/ipq50xx/
├── openwrt-qualcommax-ipq50xx-cmcc_pz-l8-squashfs-sysupgrade.bin  # 刷写固件
└── openwrt-qualcommax-ipq50xx-cmcc_pz-l8-initramfs-uImage.itb     # 救援固件
```

## 常见问题

### Q: 编译失败提示补丁冲突？

```bash
# 尝试使用 --3way 合并
git apply --3way /tmp/pr21495.patch
git apply --3way /tmp/pr21496.patch
```

### Q: 如何检查 smallbuffers 是否生效？

```bash
# 在设备上运行
free -h
# 查看内存占用是否明显降低

# 检查加载的模块
lsmod | grep ath11k
```

### Q: 如何配置 Mesh 网络？

```bash
# /etc/config/wireless
config wifi-iface 'mesh0'
    option device 'radio0'
    option mode 'mesh'
    option mesh_id 'MyMesh'
    option encryption 'sae'
    option key 'password123'
    option network 'lan'
```

### Q: 如何配置 Usteer？

```bash
# /etc/config/usteer
config usteer
    option enabled '1'
    option network 'lan'
    option local_mode '1'
```
