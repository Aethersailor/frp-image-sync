# FRP Image Sync

将 [fatedier/frp](https://github.com/fatedier/frp) 的官方构建镜像原样搬运到 GHCR，并维护 `latest`。**本仓库只负责搬运和发布别名，完全信任官方镜像，不编译、不重新打包、不修改镜像，也不测试镜像内容或运行行为。**

| 官方来源 | 本仓库发布 |
| --- | --- |
| `ghcr.io/fatedier/frpc:vX.Y.Z` | `ghcr.io/aethersailor/frpc:vX.Y.Z`、`:latest` |
| `ghcr.io/fatedier/frps:vX.Y.Z` | `ghcr.io/aethersailor/frps:vX.Y.Z`、`:latest` |

镜像由上游官方构建；这里的 `latest` 别名由本仓库维护，不是上游官方发布的 `latest`。

## 拉取

```sh
docker pull ghcr.io/aethersailor/frpc:latest
docker pull ghcr.io/aethersailor/frps:latest
```

需要固定版本时使用 `:vX.Y.Z`，需要固定镜像内容时使用 `@sha256:...`。已有 Watchtower 可跟随这里的 `latest`；本仓库不管理 Watchtower 配置或任何服务器迁移。

## 同步方式

[工作流](.github/workflows/sync.yml) 每 6 小时检查 GitHub 最新正式 Release，也支持手动运行。

1. 确认两个官方版本镜像均已发布，记录各自 index digest。
2. 使用 `regctl image copy --force-recursive` 按 digest 复制完整多架构镜像，保留版本标签。不选择单独平台，不修改 manifest、层、配置或内部 labels。
3. 确认两个版本副本的 manifest digest 均与官方来源一致后，更新两个 `latest`，并回读 digest。

digest 比较只用于确认搬运前后内容一致，不评价或测试官方镜像。源镜像未就绪、复制失败或 digest 不一致时，不会把未确认一致的副本提升为 `latest`。两个标签是独立写入，末尾写入中断可能使两个 `latest` 暂时处于不同版本，重跑即可继续同步。官方若重新发布同一版本标签，本仓库在下次同步时跟随官方内容。

两个 GHCR 包均为 Public，并关联到本仓库，可匿名拉取。每次同步的 Actions Summary 和 `digest-evidence-*` artifact 记录来源、版本及 digest，artifact 保留 90 天。

工作流使用 `GITHUB_TOKEN`，仅申请 `contents: read`、`packages: write`，无须额外凭据或常驻服务。`regctl` 固定版本及下载校验和，Actions 固定提交 SHA。

GitHub 定时任务可能延迟；公开仓库连续 60 天无活动时，GitHub 会自动禁用定时工作流，届时需在 Actions 页面重新启用。

## 来源依据

- [官方镜像发布流程](https://github.com/fatedier/frp/blob/v0.71.1/.github/workflows/build-and-push-image.yml)
- [regctl image copy 文档](https://regclient.org/cli/regctl/image/copy/)
- [GitHub 定时任务规则](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)

镜像内软件沿用上游许可证。本仓库不改动任何服务器部署。
