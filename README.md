# WorkBuddy for Linux

[WorkBuddy](https://www.workbuddy.cn/) 官网的下载页只列了 macOS / Windows / iOS / Android / 鸿蒙，Linux 一栏写着「统信 UOS/银河麒麟：请到系统应用商店下载」——Ubuntu、Debian、Fedora 用户没有入口。

但这个软件其实**有官方构建的 deb 和 rpm**，只是没挂在下载页上：腾讯的更新接口会直接返回最新 Linux 构建的下载地址。

本仓库提供的就是围绕这个接口的一键安装脚本和版本索引：

```bash
./install.sh          # 查最新版 → 下载 → 校验 → 交给 apt/dnf 安装
```

## 这不是什么

- **不是 WorkBuddy 的官方项目**，与腾讯无关。
- **不托管、不打包、不修改 WorkBuddy 的二进制**。安装包始终从腾讯官方 CDN（`download.codebuddy.cn`）实时下载，本仓库里只有脚本、文档和一份元数据索引。
- **MIT 许可证只覆盖本仓库的脚本与索引**，不覆盖 WorkBuddy 本体（专有软件，版权归腾讯）。

## 快速开始

最简单的方式是先把脚本下载下来看一眼再运行：

```bash
curl -fsSL https://raw.githubusercontent.com/ziyue67/workbuddy-linux/main/install.sh -o install.sh
less install.sh          # 建议看一眼
bash install.sh
```

或者克隆仓库（国内网络可以走代理）：

```bash
git clone https://github.com/ziyue67/workbuddy-linux.git
cd workbuddy-linux && ./install.sh
```

国内直连 `raw.githubusercontent.com` 不通时，在地址前拼一个代理前缀即可（任选其一）：

```bash
curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/ziyue67/workbuddy-linux/main/install.sh | bash
```

## 用法

```
./install.sh [选项]

  -c, --channel deb|rpm    指定包类型（默认按系统自动判断）
  -a, --arch x64|arm64     指定架构（默认按 uname -m 自动判断）
  -d, --dir DIR            下载目录（默认 ~/Downloads）
  -n, --check              只查询最新版本信息，不下载不安装
  -u, --url-only           只打印最新版的下载地址
  -t, --table              列出四个通道各自的最新版本
      --json               配合 --check 输出 JSON
  -r, --redownload         本地已有同样大小的文件也重新下载
      --dry-run            只下载并校验，不安装
      --rm                 安装成功后删除安装包
      --recommends         一并安装 deb 的推荐依赖（imagemagick、托盘库等）
      --expect-sha256 H    强制校验 SHA256，不匹配则中止
      --mirror URL         替换下载域名，用于自建/第三方镜像
  -f, --force              已是最新版本也重新安装
  -h, --help               帮助
```

常用组合：

```bash
./install.sh --check                 # 最新版是哪个？我装的是哪个？
./install.sh --table                 # 四个通道一览
./install.sh --url-only              # 只要下载地址，自己 curl
./install.sh --dry-run --rm          # 只下载校验，先不装
./install.sh --rm                    # 装完不留下 400MB 安装包
```

脚本会在本机已是最新版本时直接退出，所以可以放进定时任务或更新脚本里重复执行。

## 支持矩阵

更新接口认这四个通道，本仓库的 `index.json` 会每天自动刷新：

| platform | 包类型 | 适用 |
| --- | --- | --- |
| `workbuddy-linux-x64-deb` | x86_64 deb | Ubuntu / Debian / 深度 / openKylin |
| `workbuddy-linux-x64-rpm` | x86_64 rpm | Fedora / RHEL / openSUSE |
| `workbuddy-linux-arm64-deb` | arm64 deb | ARM 上的 Debian 系 |
| `workbuddy-linux-arm64-rpm` | arm64 rpm | ARM 上的 Fedora 系 |

官方包依赖的都是发行版标准库（deb 侧：`libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils libatspi2.0-0 libuuid1 libsecret-1-0`；rpm 侧：`gtk3 nss alsa-lib at-spi2-core libXScrnSaver libnotify mesa-libgbm` 等），不依赖任何麒麟/UOS 专有组件。`postinst` 里连 Ubuntu 24+ 的 AppArmor 分支都写好了。

**龙架构（LoongArch）没有官方版**：Electron 与部分 node 模块不支持该架构，deepin 龙芯商店里的是社区移植包。

## 版本索引

`index.json` 由 GitHub Action 每天自动刷新，结构如下：

```json
{
  "channels": {
    "workbuddy-linux-x64-deb": {
      "version": "5.5.6.38337834",
      "url": "https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/...",
      "api_sha256": "03d756b2...",
      "released": "2026-09-10T17:23:54Z"
    }
  }
}
```

只想拿版本号的话：

```bash
curl -fsSL https://raw.githubusercontent.com/ziyue67/workbuddy-linux/main/index.json | jq -r '.channels["workbuddy-linux-x64-deb"].version'
```

## 常见问题

**接口给的 `sha256hash` 和实际文件对不上？**
这是官方接口的已知现象，不是下载损坏：`api_sha256` 字段与真实文件的内容哈希不一致，但同一版本多次下载的结果稳定一致。脚本默认只警告不拦截，需要强校验就自己算一遍，再用 `--expect-sha256` 固定下来。

**装完之后应用内更新不了？**
接口返回 `supportsFastUpdate: false`，应用里点更新会提示「前往官网下载」，而官网没有 Linux 入口，等于死循环。更新方式就是重新跑一遍 `./install.sh`。

**下载速度慢 / 想用自建镜像？**
`./install.sh --mirror https://your.mirror` 会把下载域名从 `download.codebuddy.cn` 换成你的地址，路径部分保持不变。这对内网缓存、离线分发很有用——镜像由你自己搭建和承担相应责任，本仓库不分发二进制。

**Arch 系怎么办？**
官方没有 Arch 包，脚本会在检测到 `pacman` 时直接报错退出，请走 AUR 或自行转换官方 deb。

## 贡献

欢迎 PR：改进脚本兼容性、补充发行版适配、修正文档，或者提交你实测的校验值。自动化索引在 `.github/workflows/update-index.yml`，本地可用 `./scripts/update-index.sh` 重新生成。

## 许可与出处

- 本仓库的脚本、文档与索引数据：MIT，见 [LICENSE](LICENSE)。
- WorkBuddy 本体：腾讯科技（深圳）有限公司的专有软件，版权归腾讯所有，不在本许可证覆盖范围内，本仓库也不分发其安装包。

发现这个安装方法的原始文章：[《WorkBuddy 没给 Ubuntu/Fedora 留下载入口？官方的 deb 和 rpm 都找到了》](https://xingwangzhe.fun/posts/workbuddy-linux-deb-rpm/)（作者 xingwangzhe，CC-BY-NC-SA-4.0）。本仓库的脚本是在该思路基础上实现的，接口地址与拆包结论均来自该文。
