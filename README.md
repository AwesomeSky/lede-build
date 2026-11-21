# lede-build

用 GitHub Actions 编译 **Lean's LEDE (x86-64)** 固件。

仓库里**只有编译配置，没有一行业务代码**，所以可以永久 public —— public 仓库的
Actions 分钟数免费无限，私有仓库每月只有 2000 分钟（一次全量编译就吃掉 150–250）。

## 两套配置

触发时在 `Run workflow` 的下拉框里选：

| 变体 | 内容 | 2 核 runner 耗时 | 说明 |
|---|---|---|---|
| **slim**（默认） | 约 30 个包，保留 passwall + Xray 一个代理栈 | 3–4 小时 | 大概率能在 6 小时上限内编完 |
| **full** | `configs/full.config`，**572 个包**（你们之前的配置） | 6 小时+ | 含 docker / rustdesk(Rust) / openclash / adguardhome 等重件，**2 核基本会超时** |

`slim` 的包清单在 `diy.sh`，`full` 的完整配置在 `configs/full.config`，
两者都来自 `G:\Projects\lean-lede\lede-src\.config`（2026-07-25 那份）。

## 文件

| 文件 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 腾磁盘 → 装依赖 → clone LEDE → feeds → 配置 → 编译 → 收产物 |
| `diy.sh` | slim 配置：锁 x86-64 目标 + 追加约 30 个 `CONFIG_PACKAGE_*=y` |
| `configs/full.config` | 你们之前的完整 572 包配置（原样保存） |
| `configs/full-packages.txt` | 从 full.config 提取的包名清单（便于 review/diff） |
| `configs/slim-packages.txt` | slim 的包名清单 |

## 关键注意点

**feeds 必须用上游原始的那份。** 你本地 `lean-lede/lede-src/feeds.conf.default`
被改成了本地路径：

```
src-link packages /mnt/g/Projects/lean-lede/packages-feed
src-link luci     /mnt/g/Projects/lean-lede/luci-feed
src-link helloworld /mnt/g/Projects/lean-lede/helloworld
```

那是绕 WSL 慢的 hack，放到 CI 里会直接失败。本仓库**不包含** `feeds.conf`，
workflow 全新 clone LEDE 后用上游默认值，`helloworld` 源（含 `luci-app-ssr-plus`
等）会自动拉下来。

## 产物怎么用

一般是 `...squashfs-combined-efi.img.gz`：

- **PVE 建 VM**：解压得到 `.img`，`qm importdisk <vmid> xxx.img local-lvm`，
  挂 scsi0，机型 q35，BIOS 用 OVMF 或 SeaBIOS 都行（combined-efi 是双启动）
- **写 U 盘**：`dd if=xxx.img of=/dev/sdX bs=4M status=progress`

## 已知坑

| 现象 | 原因 | 处理 |
|---|---|---|
| `No space left on device` | runner 只有 14GB | workflow 第 1 步专门删 Android SDK/.NET，别去掉 |
| 跑到一半被杀 | 单 job 6 小时上限 | 选 slim，或精简 `diy.sh` 里的包 |
| `feeds update` 卡住 | GitHub 网络抖动 | 重跑；或换 `feeds.conf` 里的 gitee 镜像 |
| 产物为空 | 只编了 rootfs | 确认 `CONFIG_TARGET_x86_64` 与 Generic 目标打开 |
| `luci-ssl` 报错 | 该包名在新版 LEDE 中已并入 luci | 从 `diy.sh` 删掉它 |

## 更快的替代

这台 MS-03（16C/16T）上建 Debian 13 LXC 编固件，全量 30–60 分钟，
可反复迭代、不看额度。Actions 更适合"发版"，本地适合"调包"。
