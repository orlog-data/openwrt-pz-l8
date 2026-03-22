#!/bin/bash
#
# CMCC PZ-L8 OpenWrt 固件自动构建脚本
#
# 功能：
# - 自动应用 PR #21495 (ath11k smallbuffers)
# - 自动应用 PR #21496 (PZ-L8 双 CPU 链接)
# - 配置自定义软件包列表
# - 移除 DNS/DHCP/Firewall 组件
# - 添加 Mesh/Usteer 支持
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 工作目录
WORK_DIR="${WORK_DIR:-/workspace/openwrt}"
BUILD_DIR="${BUILD_DIR:-/workspace/openwrt-pz-l8}"

# PR 信息
PR21495_URL="https://github.com/openwrt/openwrt/pull/21495.patch"
PR21496_URL="https://github.com/openwrt/openwrt/pull/21496.patch"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_step "检查编译依赖..."

    local deps=(
        build-essential clang flex bison g++ gawk gcc-multilib
        g++-multilib gettext git libncurses-dev libssl-dev
        rsync swig unzip zlib1g-dev file wget python3 python3-dev
        python3-pyelftools python3-setuptools curl
    )

    local missing=()
    for dep in "${deps[@]}"; do
        if ! dpkg -l "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        log_warn "缺少依赖: ${missing[*]}"
        log_info "正在安装依赖..."
        sudo apt update
        sudo apt install -y "${missing[@]}"
    else
        log_info "所有依赖已安装"
    fi
}

# 克隆 OpenWrt 源码
clone_openwrt() {
    log_step "克隆 OpenWrt 源码..."

    if [ -d "$WORK_DIR" ]; then
        log_warn "OpenWrt 目录已存在: $WORK_DIR"
        read -p "是否删除并重新克隆？(y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$WORK_DIR"
        else
            log_info "使用现有目录"
            cd "$WORK_DIR"
            return
        fi
    fi

    git clone https://github.com/openwrt/openwrt.git "$WORK_DIR"
    cd "$WORK_DIR"
}

# 应用 PR 补丁
apply_patches() {
    log_step "应用 PR 补丁..."

    cd "$WORK_DIR"

    # 应用 PR #21495 (ath11k smallbuffers)
    log_info "应用 PR #21495 (ath11k smallbuffers)..."
    curl -L "$PR21495_URL" -o /tmp/pr21495.patch
    if git apply --check /tmp/pr21495.patch 2>/dev/null; then
        git apply /tmp/pr21495.patch
        log_info "PR #21495 应用成功"
    else
        log_warn "PR #21495 应用失败，可能已合并或存在冲突"
        git apply --reject --whitespace=fix /tmp/pr21495.patch 2>/dev/null || true
    fi

    # 应用 PR #21496 (PZ-L8 双 CPU 链接)
    log_info "应用 PR #21496 (PZ-L8 双 CPU 链接)..."
    curl -L "$PR21496_URL" -o /tmp/pr21496.patch
    if git apply --check /tmp/pr21496.patch 2>/dev/null; then
        git apply /tmp/pr21496.patch
        log_info "PR #21496 应用成功"
    else
        log_warn "PR #21496 应用失败，可能已合并或存在冲突"
        git apply --reject --whitespace=fix /tmp/pr21496.patch 2>/dev/null || true
    fi
}

# 配置软件包
configure_packages() {
    log_step "配置软件包..."

    cd "$WORK_DIR"

    # 更新 feeds
    log_info "更新 feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a

    # 基础配置
    log_info "生成基础配置..."
    cat > .config << 'BASECONFIG'
# 目标设备配置
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_cmcc_pz-l8=y

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
BASECONFIG

    # 禁用不需要的组件
    log_info "禁用不需要的组件..."
    cat >> .config << 'DISABLECONFIG'
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

# 禁用 PPP 相关
CONFIG_PACKAGE_ppp=n
CONFIG_PACKAGE_ppp-mod-pppoe=n
CONFIG_PACKAGE_kmod-ppp=n
CONFIG_PACKAGE_kmod-pppoe=n

# 禁用其他无线认证方式
CONFIG_PACKAGE_wpad-basic-mbedtls=n
CONFIG_PACKAGE_wpad-basic-wolfssl=n
CONFIG_PACKAGE_wpad-mesh-wolfssl=n
DISABLECONFIG

    # 使配置生效
    make defconfig
}

# 下载源码包
download_sources() {
    log_step "下载源码包..."

    cd "$WORK_DIR"

    log_info "下载中... 这可能需要一些时间"
    make download -j"$(nproc)"
}

# 编译固件
build_firmware() {
    log_step "编译固件..."

    cd "$WORK_DIR"

    local cores=$(nproc)
    log_info "使用 $cores 个核心编译..."

    if make -j"$cores" V=s; then
        log_info "编译成功！"
        show_output_files
    else
        log_error "编译失败！"
        log_info "请检查错误信息并重试"
        exit 1
    fi
}

# 显示输出文件
show_output_files() {
    log_step "编译输出文件："

    local output_dir="$WORK_DIR/bin/targets/qualcommax/ipq50xx"

    if [ -d "$output_dir" ]; then
        find "$output_dir" -name "*pz-l8*" -type f -exec ls -lh {} \;

        log_info "固件文件位置：$output_dir"

        # 复制到构建目录
        mkdir -p "$BUILD_DIR/firmware"
        cp -v "$output_dir"/*pz-l8* "$BUILD_DIR/firmware/"
        log_info "固件已复制到: $BUILD_DIR/firmware/"
    else
        log_error "未找到输出目录"
    fi
}

# 清理
clean_build() {
    log_step "清理编译文件..."

    cd "$WORK_DIR"
    make clean
    log_info "清理完成"
}

# 显示帮助
show_help() {
    cat << EOF
CMCC PZ-L8 OpenWrt 固件构建脚本

用法: $0 [选项]

选项:
    --check         检查并安装依赖
    --clone         克隆 OpenWrt 源码
    --patch         应用 PR 补丁
    --config        配置软件包
    --download      下载源码包
    --build         编译固件
    --clean         清理编译文件
    --all           执行完整构建流程
    --help          显示帮助信息

环境变量:
    WORK_DIR        OpenWrt 源码目录 (默认: /workspace/openwrt)
    BUILD_DIR       输出目录 (默认: /workspace/openwrt-pz-l8)

示例:
    $0 --all                    # 执行完整构建
    $0 --patch --config --build # 应用补丁、配置、编译
    WORK_DIR=/opt/openwrt $0 --build  # 指定源码目录

EOF
}

# 主函数
main() {
    local action="${1:---help}"

    case "$action" in
        --check)
            check_dependencies
            ;;
        --clone)
            clone_openwrt
            ;;
        --patch)
            apply_patches
            ;;
        --config)
            configure_packages
            ;;
        --download)
            download_sources
            ;;
        --build)
            build_firmware
            ;;
        --clean)
            clean_build
            ;;
        --all)
            check_dependencies
            clone_openwrt
            apply_patches
            configure_packages
            download_sources
            build_firmware
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log_error "未知选项: $action"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
