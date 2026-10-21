# FRP Image Sync

为 [FRP](https://github.com/fatedier/frp) 官方的 `frpc`、`frps` Docker 镜像提供 `latest` 标签，方便使用 Watchtower 等工具自动更新。

镜像从官方 GHCR 原样同步，保留完整多架构支持，不重新构建或修改内容。

## 镜像地址

| 镜像 | 地址 |
| --- | --- |
| 客户端 frpc | `ghcr.io/aethersailor/frpc` |
| 服务端 frps | `ghcr.io/aethersailor/frps` |

支持以下标签：

- `latest`：跟随官方最新正式版，每 6 小时检查更新。
- `vX.Y.Z`：使用指定版本，例如 `v0.71.1`。保留本仓库已同步的版本。

## 使用

```sh
docker pull ghcr.io/aethersailor/frpc:latest
docker pull ghcr.io/aethersailor/frps:latest
```

镜像公开，无需登录即可拉取。需要固定版本时，将 `latest` 替换为具体版本标签。

本项目由社区维护，`latest` 标签由本仓库提供。FRP 的配置和使用方法请参考[官方文档](https://gofrp.org/zh-cn/docs/)。
