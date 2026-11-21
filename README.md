# lede-build

用 GitHub Actions 编译 **Lean's LEDE (x86-64)** 固件。仓库里**只有编译配置**，
不含任何业务代码，所以可以永久 public（public 仓库 Actions 分钟数免费无限）。

## 怎么用

1. `Actions` → 左侧 `Build LEDE x86-64` → 右侧 `Run workflow` → 绿色按钮
2. 等 2–4 小时（runner 只有 2 核）
3. 进那次 run，页面底部 `Artifacts` → 下载 `lede-x86-64-<n>.zip`

## 文件

| 文件 | 作用 |
|---|---|
| `.github/workflows/build.yml` | 腾磁盘 → 装依赖 → clone LEDE → feeds → 配置 → 编译 → 上传产物 |
| `diy.sh` | 在 `make defconfig` 之前追加配置（锁 x86-64、加常用包） |

## 产物怎么用

一般是 `...squashfs-combined-efi.img.gz`：

- **PVE 建 VM**：解压得到 `.img`，`qm importdisk <vmid> xxx.img local-lvm`，挂 scsi0，机型 q35
- **写 U 盘**：`dd if=xxx.img of=/dev/sdX bs=4M status=progress`

## 注意

- 2 核很慢，包越多越容易撞 6 小时上限；先跑精简配置，通了再加包
- runner 只有 14GB 空间，workflow 第一步专门删了 Android SDK / .NET，别去掉那步
- `dl/` 有缓存，同配置重跑会快很多
- 私有仓库每月 2000 分钟；本仓库设为 **public** 才免费无限