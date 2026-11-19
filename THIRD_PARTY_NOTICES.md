# Third-Party Notices

本仓库的 App 本体与 OpenQQ 是**两个独立分发/运行的组件**。App 本体采用 BSD-3-Clause；OpenQQ 采用 AGPL-3.0。

## 1. 本 App

- 许可证：BSD-3-Clause
- 全文：`LICENSES/BSD-3-Clause.txt`
- 根目录 `LICENSE` 为 App 本体许可证

## 2. OpenQQ（独立组件）

- 上游：https://github.com/feijx3/OpenQQ
- 版本：`v0.4.0`，commit `1f86aa3`
- 许可证：GNU Affero General Public License v3.0
- 全文：`LICENSES/AGPL-3.0.txt`
- 分发方式：App 不把 OpenQQ 源码或二进制打包进 APK；用户安装时由安装脚本从上游仓库获取
- App 对 OpenQQ 的构建修改：
  - 修改 `package.json` 的 `allowScripts`，允许 `@parcel/watcher` / `esbuild` 安装脚本
  - 生成 `config/openqq.json`（端口、反向 WebSocket、token 等配置，不包含 OpenQQ 源码）
  - 使用 `npm ci`、`npm run build`、`npm prune --omit=dev` 构建
- 对应源码：上游 `v0.4.0` / `1f86aa3` 源码，加上本仓库 `assets/openqq-install.sh` 中的构建步骤。若后续加入 OpenQQ 源码补丁，补丁本身也按 AGPL-3.0 提供。
- AGPL §13：如果用户通过网络与修改后的 OpenQQ 交互，源码获取方式见上述上游地址与本仓库安装脚本。

## 3. AstrBot

- 上游：https://github.com/AstrBotDevs/AstrBot
- 分发方式：安装脚本在运行时从上游获取，不打包进 APK
- 许可证：以 AstrBot 上游仓库的 `LICENSE` 为准

## 4. NapCatQQ（旧版兼容，入口已隐藏）

- 上游：https://github.com/NapNeko/NapCatQQ
- 当前 `kEnableNapCat = false`，App 不再安装或启动 NapCat；历史数据和兼容代码保留
- 许可证：以 NapCatQQ 上游仓库的 `LICENSE` 为准

## 5. Node.js

- 上游：https://nodejs.org
- 安装方式：官方 `node-v26.13.1-linux-arm64.tar.xz` 压缩包（失败时回退 npmmirror）
- 许可证：以 Node.js 上游仓库的 `LICENSE` 为准（MIT）

## 6. Code LFA / Ubuntu 容器

- Code LFA：BSD-3-Clause，https://github.com/nightmare-space/code_lfa
- Ubuntu 镜像及其软件包遵循各自上游许可证

## 7. 合规说明

- 不要删除 OpenQQ 的 LICENSE、版权声明和源码获取入口
- 不要给 OpenQQ 增加额外限制
- 如果未来把 OpenQQ 源码/二进制直接打进 APK，必须同时提供完整对应源码，并重新评估整体分发方式
- 本文件不是法律意见；正式商业发布前建议由律师复核
