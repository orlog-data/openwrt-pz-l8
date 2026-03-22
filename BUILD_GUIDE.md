# CMCC PZ-L8 OpenWrt 固件编译指南

## 概述

本文档详细说明如何为 CMCC PZ-L8（IPQ5018 平台）编译自定义 OpenWrt 固件，包含以下特性：

1. **引入 PR #21495**：`mac80211: ath11k: provide smallbuffers variant` - 为 256MB 内存设备优化 WiFi 内存占用
2. **引入 PR #21496**：`qualcommax: ipq5018: pz-l8: enable PHY-to-PHY CPU link` - 启用双 CPU 链接支持 2Gbps
3. **移除组件**：DNS、DHCP、Firewall（适用于纯 AP 模式）
4. **增加组件**：Mesh 网络、Usteer 无线漫游管理

## 目标设备信息

| 属性 | 值 |
|------|-----|
| 设备型号 | CMCC PZ-L8 |
| SoC | Qualcomm IPQ5018 |
| 内存 | 256MB |
| 交换机 | QCA8337 |
| 无线 | IPQ5018 + QCN6122 |
| 目标平台 | qualcommax/ipq50xx |

---

## 第一步：准备编译环境

### 1.1 系统要求

推荐使用 Ubuntu 22.04 LTS 或 Debian 12，确保有足够的磁盘空间（至少 30GB）。

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装编译依赖
sudo apt install -y build-essential clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev \
  rsync swig unzip zlib1g-dev file wget python3 python3-dev \
  python3-pyelftools python3-setuptools python3-distutils-extra
```

### 1.2 克隆 OpenWrt 源码

```bash
cd /workspace
git clone https://github.com/openwrt/openwrt.git
cd openwrt
```

---

## 第二步：应用补丁

### 2.1 应用 PR #21495（ath11k smallbuffers）

此 PR 为 256MB 内存设备优化 WiFi 内存占用，可将 ath11k 内存使用从约 138MB 降至约 71MB。

```bash
cd /workspace/openwrt

# 获取 PR #21495 的 patch
curl -L "https://github.com/openwrt/openwrt/pull/21495.patch" -o /tmp/pr21495.patch

# 应用补丁
git apply /tmp/pr21495.patch
```

**修改的文件**：
- `package/firmware/ipq-wifi/Makefile`
- `package/kernel/mac80211/Makefile`
- `package/kernel/mac80211/ath.mk`
- `package/kernel/mac80211/patches/ath11k/951-wifi-ath11k-introduct-CONFIG_ATH11K_SMALLBUFFERS.patch`
- `target/linux/qualcommax/dts/ipq5018-pz-l8.dts`
- `target/linux/qualcommax/image/ipq50xx.mk`
- `target/linux/qualcommax/ipq50xx/base-files/etc/hotplug.d/firmware/11-ath11k-caldata`

### 2.2 应用 PR #21496（PZ-L8 双 CPU 链接）

此 PR 为 PZ-L8 启用 PHY-to-PHY CPU 链接，实现 2Gbps 聚合带宽。

网络拓扑：
```
 _______________________         _______________________
|        IPQ5018        |       |        QCA8337        |
| +------+   +--------+ |       | +--------+   +------+ |
| | MAC0 |---| GE Phy |-+--MDI--+-|  Phy4  |---| MAC5 | |
| +------+   +--------+ |       | +--------+   +------+ |
| +------+   +--------+ |       | +--------+   +------+ |
| | MAC1 |---| Uniphy |-+-SGMII-+-| SerDes |---| MAC0 | |
| +------+   +--------+ |       | +--------+   +------+ |
|_______________________|       |_______________________|
```

```bash
cd /workspace/openwrt

# 获取 PR #21496 的 patch
curl -L "https://github.com/openwrt/openwrt/pull/21496.patch" -o /tmp/pr21496.patch

# 应用补丁
git apply /tmp/pr21496.patch
```

**修改的文件**：
- `target/linux/qualcommax/dts/ipq5018-pz-l8.dts`
- `target/linux/qualcommax/ipq50xx/base-files/etc/board.d/02_network`
- `target/linux/qualcommax/patches-6.12/0752-net-dsa-qca8k-support-PHY-to-PHY-CPU-link.patch`
- `target/linux/qualcommax/patches-6.12/0754-net-dsa-qca8k-use-correct-CPU-port-when-having-multi.patch`
- `target/linux/qualcommax/patches-6.12/0755-net-dsa-qca8k-implement-ds-ops-preferred_default_loc.patch`

---

## 第三步：配置软件包

### 3.1 初始化配置

```bash
cd /workspace/openwrt

# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 加载目标设备配置
make defconfig
```

### 3.2 配置目标设备

```bash
# 选择目标设备
make menuconfig
```

在菜单中配置：

**Target System** → `Qualcomm Atheros`
**Subtarget** → `IPQ50xx (ARMv8)`
**Target Profile** → `CMCC PZ-L8`

或者直接使用 `.config` 配置：

```bash
cat >> .config << 'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_cmcc_pz-l8=y
EOF
```

### 3.3 配置软件包列表

根据您的需求，创建自定义配置：

```bash
cat >> .config << 'EOF'
# 基础系统组件
CONFIG_PACKAGE_apk-mbedtls=y
CONFIG_PACKAGE_base-files=y
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_dropbear=y
CONFIG_PACKAGE_fstools=y
CONFIG_PACKAGE_kmod-gpio-button-hotplug=y
CONFIG_PACKAGE_kmod-leds-gpio=y
CONFIG_PACKAGE_libc=y
CONFIG_PACKAGE_libgcc=y
CONFIG_PACKAGE_libustream-mbedtls=y
CONFIG_PACKAGE_logd=y
CONFIG_PACKAGE_mtd=y
CONFIG_PACKAGE_netifd=y
CONFIG_PACKAGE_procd-ujail=y
CONFIG_PACKAGE_uboot-envtools=y
CONFIG_PACKAGE_uci=y
CONFIG_PACKAGE_uclient-fetch=y
CONFIG_PACKAGE_urandom-seed=y
CONFIG_PACKAGE_urngd=y
CONFIG_PACKAGE_zram-swap=y

# 无线驱动
CONFIG_PACKAGE_kmod-ath11k-ahb=y
CONFIG_PACKAGE_kmod-ath11k-smallbuffers=y
CONFIG_PACKAGE_ath11k-firmware-ipq5018-qcn6122=y
CONFIG_PACKAGE_ipq-wifi-cmcc_pz-l8=y

# 交换机驱动
CONFIG_PACKAGE_kmod-qca-nss-dp=y

# 无线 Mesh 支持
CONFIG_PACKAGE_wpad-mesh-mbedtls=y

# LuCI Web 界面
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_uhttpd=y
CONFIG_PACKAGE_uhttpd-mod-ubus=y

# LuCI 中文翻译
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y
CONFIG_PACKAGE_luci-i18n-usteer-zh-cn=y

# Usteer 无线漫游
CONFIG_PACKAGE_usteer=y

# 移除 DNS 相关组件
CONFIG_PACKAGE_dnsmasq=n
CONFIG_PACKAGE_dnsmasq-full=n

# 移除 DHCP 相关组件
CONFIG_PACKAGE_odhcpd-ipv6only=n
CONFIG_PACKAGE_dhpcd=n

# 移除 Firewall 相关组件
CONFIG_PACKAGE_firewall4=n
CONFIG_PACKAGE_firewall=n
CONFIG_PACKAGE_kmod-nft-core=n
CONFIG_PACKAGE_kmod-nft-fib=n
CONFIG_PACKAGE_kmod-nft-nat=n
CONFIG_PACKAGE_kmod-nft-offload=n
CONFIG_PACKAGE_kmod-nf-conntrack=n
CONFIG_PACKAGE_kmod-nf-conntrack6=n
CONFIG_PACKAGE_kmod-nf-flow=n
CONFIG_PACKAGE_kmod-nf-iptables=n
CONFIG_PACKAGE_kmod-nf-ipt6=n
CONFIG_PACKAGE_kmod-nf-nat=n
CONFIG_PACKAGE_kmod-nf-reject=n
CONFIG_PACKAGE_kmod-nf-reject6=n
CONFIG_PACKAGE_iptables-legacy=n
CONFIG_PACKAGE_iptables-nft=n
CONFIG_PACKAGE_nftables=n
EOF
```

### 3.4 禁用不需要的默认组件

```bash
cat >> .config << 'EOF'
# 禁用 PPP 相关
CONFIG_PACKAGE_ppp=n
CONFIG_PACKAGE_ppp-mod-pppoe=n
CONFIG_PACKAGE_kmod-ppp=n
CONFIG_PACKAGE_kmod-pppoe=n

# 禁用 IPv6 相关（可选）
CONFIG_PACKAGE_kmod-ipv6=n
CONFIG_PACKAGE_kmod-ip6tables=n
CONFIG_PACKAGE_libip6tc=n

# 禁用不必要的无线加密方式（保留 mesh 需要的）
CONFIG_PACKAGE_wpad-basic-mbedtls=n
CONFIG_PACKAGE_wpad-basic-wolfssl=n
CONFIG_PACKAGE_wpad-mesh-wolfssl=n
EOF
```

---

## 第四步：编译固件

### 4.1 下载依赖

```bash
# 下载所有需要的源码包
make download -j$(nproc)
```

### 4.2 开始编译

```bash
# 使用多核编译
make -j$(nproc) V=s
```

编译过程可能需要 1-3 小时，取决于您的硬件性能。

### 4.3 编译输出

编译完成后，固件文件位于：
```
bin/targets/qualcommax/ipq50xx/
├── openwrt-qualcommax-ipq50xx-cmcc_pz-l8-squashfs-sysupgrade.bin
└── openwrt-qualcommax-ipq50xx-cmcc_pz-l8-initramfs-uImage.itb
```

---

## 第五步：后编译配置

### 5.1 配置网络（纯 AP 模式）

刷入固件后，配置网络为纯 AP 模式：

```bash
# /etc/config/network
config interface 'lan'
    option type 'bridge'
    option ifname 'eth0'
    option proto 'static'
    option ipaddr '192.168.1.2'  # 根据您的主网络调整
    option netmask '255.255.255.0'
    option gateway '192.168.1.1'
    option dns '192.168.1.1'
```

### 5.2 配置无线 Mesh

```bash
# /etc/config/wireless
config wifi-iface 'mesh'
    option device 'radio0'
    option mode 'mesh'
    option mesh_id 'YourMeshID'
    option encryption 'sae'
    option key 'YourMeshPassword'
    option network 'lan'
```

### 5.3 配置 Usteer

```bash
# /etc/config/usteer
config usteer
    option network 'lan'
    option ssid 'YourSSID'
    option local_mode '1'
    option load_balancing '1'
    option min_snr '15'
```

---

## 完整软件包列表

### 保留组件

| 软件包 | 说明 |
|--------|------|
| apk-mbedtls | APK 包管理器（mbedtls 版本） |
| base-files | 基础文件系统 |
| ca-bundle | CA 证书 |
| dropbear | SSH 服务器 |
| fstools | 文件系统工具 |
| kmod-ath11k-ahb | IPQ5018 无线驱动 |
| kmod-ath11k-smallbuffers | 内存优化版 ath11k |
| kmod-gpio-button-hotplug | 按键支持 |
| kmod-leds-gpio | LED 支持 |
| kmod-qca-nss-dp | NSS 数据路径驱动 |
| libc | C 标准库 |
| libgcc | GCC 运行时库 |
| libustream-mbedtls | TLS 流库 |
| logd | 日志守护进程 |
| luci-base | LuCI 基础组件 |
| luci-mod-admin-full | LuCI 管理模块 |
| luci-theme-bootstrap | LuCI 主题 |
| luci-i18n-base-zh-cn | LuCI 中文翻译 |
| luci-i18n-package-manager-zh-cn | 包管理器中文翻译 |
| luci-i18n-usteer-zh-cn | Usteer 中文翻译 |
| mtd | MTD 工具 |
| netifd | 网络接口守护进程 |
| procd-ujail | 进程管理（带 jail 支持） |
| uboot-envtools | U-Boot 环境工具 |
| uci | 统一配置接口 |
| uclient-fetch | HTTP 客户端 |
| urandom-seed | 随机数种子 |
| urngd | 随机数生成器 |
| usteer | 无线漫游管理 |
| uhttpd | HTTP 服务器 |
| uhttpd-mod-ubus | uBus 模块 |
| wpad-mesh-mbedtls | 无线认证（Mesh 支持） |
| zram-swap | ZRAM 交换 |
| ath11k-firmware-ipq5018-qcn6122 | WiFi 固件 |
| ipq-wifi-cmcc_pz-l8 | 设备 WiFi 校准数据 |

### 移除组件

| 软件包 | 说明 |
|--------|------|
| dnsmasq / dnsmasq-full | DNS/DHCP 服务器 |
| odhcpd-ipv6only | IPv6 DHCP |
| firewall4 | 防火墙 |
| kmod-nft-* | nftables 内核模块 |
| iptables-* | iptables 工具 |
| nftables | nftables 工具 |

---

## 常见问题

### Q1: 编译失败怎么办？

1. 检查是否所有依赖都已安装
2. 尝试单线程编译获取详细错误信息：`make V=s`
3. 清理后重新编译：`make clean && make -j$(nproc) V=s`

### Q2: 固件太大怎么办？

1. 移除不需要的语言包
2. 使用 strip 优化二进制文件
3. 考虑使用 squashfs 压缩

### Q3: WiFi 无法启动？

确保选择了正确的无线驱动：
- `CONFIG_PACKAGE_kmod-ath11k-smallbuffers=y` 而非 `CONFIG_PACKAGE_kmod-ath11k-ahb=y`

### Q4: 如何验证双 CPU 链接生效？

```bash
# 查看网络接口
ip link show

# 查看 DSA 交换机状态
ls -la /sys/class/net/

# 测试吞吐量
ethtool -i eth0
```

---

## 参考链接

- [OpenWrt 官方文档](https://openwrt.org/docs/start)
- [PR #21495: ath11k smallbuffers](https://github.com/openwrt/openwrt/pull/21495)
- [PR #21496: PZ-L8 双 CPU 链接](https://github.com/openwrt/openwrt/pull/21496)
- [IPQ50xx 设备支持](https://openwrt.org/toh/cmcc/pz-l8)

---

*文档生成日期：2026-03-21*
