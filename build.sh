#!/usr/bin/env bash
# ============================================================================
#  build.sh —— 在任意 Debian/Ubuntu 服务器上编译 Lean's LEDE (x86-64)
#
#  用法：
#     ./build.sh              # 默认 slim（约 30 个包）
#     ./build.sh full         # 完整 572 包（configs/full.config）
#     JOBS=8 ./build.sh slim  # 指定并行度
#     LEDE_DIR=/data/lede ./build.sh   # 指定源码目录（默认 ./lede）
#
#  要求：
#     - Debian 12/13 或 Ubuntu 22.04/24.04，x86-64
#     - 磁盘 ≥ 30GB（full 建议 ≥ 50GB）
#     - 内存 ≥ 4GB（full 建议 ≥ 8GB）
#     - 非 root 也能跑（会自己 sudo 装依赖）；但别用 root 直接跑 make，
#       OpenWrt 的 buildroot 会拒绝 root 构建，脚本会自动处理。
#
#  产物：lede/bin/targets/x86/64/*combined*.img.gz
# ============================================================================
set -euo pipefail

VARIANT="${1:-slim}"
LEDE_DIR="${LEDE_DIR:-$PWD/lede}"
JOBS="${JOBS:-$(nproc)}"
LOG="$PWD/build-$(date +%Y%m%d-%H%M%S).log"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    OK: %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    WARN: %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m    FAIL: %s\033[0m\n' "$*" >&2; exit 1; }

case "$VARIANT" in
  slim|full) ;;
  *) die "variant 只能是 slim 或 full，收到: $VARIANT" ;;
esac

say "0. 环境检查"
echo "  variant : $VARIANT"
echo "  源码目录: $LEDE_DIR"
echo "  并行度  : $JOBS"
echo "  磁盘    : $(df -h "$PWD" | tail -1)"
echo "  内存    : $(free -h | awk '/Mem:/{print $2" 总 / "$7" 可用"}')"
echo "  系统    : $(. /etc/os-release && echo "$PRETTY_NAME")"
[ "$(uname -m)" = "x86_64" ] || warn "非 x86_64，产物可能不对"

# ---------------------------------------------------------------------------
say "1. 安装编译依赖"
SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"
# Debian 13 已移除 python3-distutils，所以逐个装、失败的跳过
PKGS="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
gettext git libncurses-dev libssl-dev python3 python3-setuptools rsync unzip \
zlib1g-dev file wget subversion libelf-dev autoconf automake libtool pkg-config \
bc cpio ccache libncurses5-dev"
for p in $PKGS; do
  dpkg -s "$p" >/dev/null 2>&1 || $SUDO apt-get install -y -qq "$p" >/dev/null 2>&1 || warn "跳过 $p"
done
ok "依赖就绪"

# ---------------------------------------------------------------------------
say "2. 拉取 LEDE 源码"
if [ -d "$LEDE_DIR/.git" ]; then
  ok "已存在，复用 $LEDE_DIR"
  git -C "$LEDE_DIR" log -1 --pretty='  HEAD: %h %ci %s'
else
  git clone --depth 1 https://github.com/coolsnowwolf/lede "$LEDE_DIR"
  git -C "$LEDE_DIR" log -1 --pretty='  HEAD: %h %ci %s'
fi

# OpenWrt buildroot 拒绝 root 构建；如果是 root，切到一个普通用户再编
RUN=""
if [ "$(id -u)" -eq 0 ]; then
  warn "当前是 root，OpenWrt 不允许 root 构建，改用普通用户编译"
  BUILDER="${BUILDER:-builder}"
  if ! id "$BUILDER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$BUILDER"
  fi
  chown -R "$BUILDER":"$BUILDER" "$LEDE_DIR" "$PWD"
  RUN="sudo -u $BUILDER -H"
fi

# ---------------------------------------------------------------------------
say "3. feeds update / install（含 helloworld 源）"
cd "$LEDE_DIR"
$RUN ./scripts/feeds update -a
$RUN ./scripts/feeds install -a
ok "feeds 完成"

# ---------------------------------------------------------------------------
say "4. 应用配置（$VARIANT）"
if [ "$VARIANT" = "full" ]; then
  [ -f "$REPO_ROOT/configs/full.config" ] || die "找不到 configs/full.config"
  cp "$REPO_ROOT/configs/full.config" .config
  ok "已使用 configs/full.config"
else
  [ -f "$REPO_ROOT/diy.sh" ] || die "找不到 diy.sh"
  bash "$REPO_ROOT/diy.sh"
  ok "已应用 diy.sh（slim）"
fi
$RUN make defconfig
echo "  目标    : $(grep -E '^CONFIG_TARGET_(x86|ARCH_PACKAGES)' .config | tr '\n' ' ')"
echo "  包数量  : $(grep -c '^CONFIG_PACKAGE_.*=y$' .config)"

# ---------------------------------------------------------------------------
say "5. 下载源码包（失败会自动重试一次）"
$RUN make download -j8 || { warn "部分包下载失败，重试 -j1"; $RUN make download -j1 V=s; }
ok "下载完成"

# ---------------------------------------------------------------------------
say "6. 编译（$JOBS 线程，日志 $LOG）"
START=$(date +%s)
if ! $RUN make -j"$JOBS" 2>&1 | tee -a "$LOG" | tail -3; then :; fi
# 上面用了 tee，真实状态看是否生成了镜像；失败则单线程重编定位错误
if ! ls bin/targets/x86/64/*combined*.img* >/dev/null 2>&1; then
  warn "并行编译未产出镜像，改用 -j1 V=s 定位错误"
  $RUN make -j1 V=s 2>&1 | tee -a "$LOG" | tail -40
fi
END=$(date +%s)
ok "编译耗时 $(( (END-START)/60 )) 分 $(( (END-START)%60 )) 秒"

# ---------------------------------------------------------------------------
say "7. 产物"
ls -lh bin/targets/x86/64/*combined*.img* 2>/dev/null || die "没有找到镜像，看 $LOG"
cat <<EOF

下一步：
  PVE 建 VM：
    gunzip -k bin/targets/x86/64/*combined-efi.img.gz
    qm importdisk <vmid> xxx.img local-lvm
    qm set <vmid> --scsi0 local-lvm:vm-<vmid>-disk-0 --boot order=scsi0 --machine q35
  写 U 盘：
    gunzip -c xxx.img.gz | dd of=/dev/sdX bs=4M status=progress
EOF
