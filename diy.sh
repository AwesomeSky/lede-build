#!/bin/bash
# 在 make defconfig 之前执行。只锁目标平台 + 加少量必要包，
# 其余交给 make defconfig 补全，避免手写几千行 .config 出错。
# 注意：runner 只有 2 核，包越多越容易超过 6 小时 job 上限。

cat >> .config <<'EOF'
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
CONFIG_TARGET_x86_64_Generic_Default=y

CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-opkg=y
CONFIG_PACKAGE_luci-app-ttyd=y

CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget-ssl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_lsof=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_ethtool=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_kmod-tun=y
EOF