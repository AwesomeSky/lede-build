# lede-build

Lean's LEDE (x86-64) 的**编译配置仓库**。不含 LEDE 源码，也不含业务代码。

编译有两种方式，**当前用第一种**：

| 方式 | 状态 | 适合 |
|---|---|---|
| **`build.sh` 在服务器上编** | ✅ 现在用这个 | 16 核 30–60 分钟；可反复迭代、改包、调 config |
| GitHub Actions（`workflow`） | ⏸ 暂不启用 | 出成品发布；2 核要 3–4 小时，且可能撞 6 小时上限 |

---

## 一、服务器编译（推荐）

把仓库 clone 到任意 Debian/Ubuntu 机器：

```bash
git clone https://github.com/AwesomeSky/lede-build.git
cd lede-build

chmod +x build.sh
./build.sh            # slim：约 30 个包
./build.sh full       # full：572 个包（你之前的完整配置）
```

可选参数：

```bash
JOBS=12 ./build.sh slim          # 指定并行度（默认 nproc）
LEDE_DIR=/data/lede ./build.sh   # 指定源码目录（默认 ./lede，可复用已有源码）
```

**资源要求**

| 变体 | 磁盘 | 内存 | 16 核耗时 |
|---|---|---|---|
| slim | ≥ 30GB | ≥ 4GB | 约 30–45 分钟 |
| full | ≥ 50GB | ≥ 8GB | 约 60–90 分钟 |

**脚本会做的事**：装依赖 → clone/复用 LEDE 源码 → `feeds update/install -a`
（含 `helloworld` 源）→ 应用配置 → `make download` → `make -jN` → 列产物。
并行编译没出镜像时会自动回退 `-j1 V=s` 把真实报错打出来。

**以 root 运行时**脚本会自动建一个 `builder` 用户来编（OpenWrt buildroot 拒绝 root）。

**产物**：`lede/bin/targets/x86/64/*combined*.img.gz`

---

## 二、GitHub Actions（暂不启用）

`.github/workflows/build.yml` 已就绪，触发时选 `slim` / `full`。
公开仓库 Actions 免费无限，但 runner 只有 2 核：

- `slim` 约 3–4 小时，通常能完成
- `full` 6 小时+，**大概率超时**（含 docker / rustdesk / openclash / adguardhome 等重件）

---

## 配置说明

| 文件 | 内容 |
|---|---|
| `diy.sh` | **slim** 配置：锁 x86-64 目标 + 追加约 30 个 `CONFIG_PACKAGE_*=y` |
| `configs/full.config` | **full** 配置：你之前的完整 572 包配置，原样保存（2026-07-25 那份） |
| `configs/full-packages.txt` | 从 full.config 提取的包名清单，便于 diff/review |
| `configs/slim-packages.txt` | slim 的包名清单 |

### slim 保留了哪些

`luci` + `luci-app-firewall/package-manager/ttyd`、`passwall`(+Xray/Geodata)、
`turboacc`、`upnp`+`miniupnpd-iptables`、`sqm`、`ddns`(+aliyun/dnspod)、`wol`、
`arpbind`、`autoreboot`、`nlbwmon`、`wifihistory`、`ksmbd`、`minidlna`、
`udpxy`(IPTV)、`frpc`/`frps`、`zerotier`、`dnsmasq-full`(+dhcpv6/ipset)。

### slim 砍掉了哪些（都是编译时间杀手）

`docker`/`dockerd`/`docker-compose`/`luci-app-dockerman`、`rustdesk-server`（Rust）、
`openclash`、`adguardhome`、`tailscale`、`sing-box`、`xray-core`、`mihomo`、
`ssr-plus` 整套（与 passwall 重复）、`rclone`、`n2n`、`openvpn`、`vsftpd`、
各种 `*gamebooster`、`vlmcsd`、`dufs`、`xlnetacc`。

需要哪个就加到 `diy.sh` 的 `CONFIG_PACKAGE_xxx=y` 里，或者直接用 `full`。

---

## 关键注意点

**feeds 必须用上游原始的那份。** 本地 `lean-lede/lede-src/feeds.conf.default`
被改成了本地路径（`src-link ... /mnt/g/Projects/...`），那是绕 WSL 慢的 hack，
拿到任何 CI/服务器上都会直接失败。本仓库不含 `feeds.conf`，
`build.sh` 用的是全新 clone 的上游默认值。

---

## 产物怎么用

**PVE 建 VM**

```bash
gunzip -k lede/bin/targets/x86/64/*combined-efi.img.gz
qm importdisk 100 lede/bin/targets/x86/64/*combined-efi.img local-lvm
qm set 100 --scsi0 local-lvm:vm-100-disk-0 --boot order=scsi0 --machine q35 --ostype l26
qm set 100 --net0 virtio,bridge=vmbr1
qm start 100
```

**写 U 盘**

```bash
gunzip -c xxx.img.gz | dd of=/dev/sdX bs=4M status=progress conv=fsync
```
