# FRP Image Sync

将 [fatedier/frp](https://github.com/fatedier/frp) 发布的官方 `frpc`、`frps` 容器镜像原样同步到 GHCR，并维护 `latest` 别名。**镜像由上游官方构建；本仓库维护镜像副本及 `latest`，不是上游官方发布的 `latest`。**

| 用途 | 官方来源 | 本仓库维护的镜像 |
| --- | --- | --- |
| FRP 客户端 | `ghcr.io/fatedier/frpc:vX.Y.Z` | `ghcr.io/aethersailor/frpc:latest` |
| FRP 服务端 | `ghcr.io/fatedier/frps:vX.Y.Z` | `ghcr.io/aethersailor/frps:latest` |

两个目标镜像同时保留 `vX.Y.Z` 标签。同步不执行 Docker build、不重新编译、不重新打包，也不修改镜像内部的 labels、配置、层和 manifest。镜像内部的上游来源元数据保持原样；本仓库与 GHCR 包的关联在 GitHub 包设置中管理。

## 使用镜像

```sh
docker pull ghcr.io/aethersailor/frpc:latest
docker pull ghcr.io/aethersailor/frps:latest

# 只检查版本，不连接 FRP 服务。
docker run --rm --network none ghcr.io/aethersailor/frpc:latest --version
docker run --rm --network none ghcr.io/aethersailor/frps:latest --version
```

需要固定版本时使用 `:vX.Y.Z`；需要固定镜像内容时使用 `@sha256:...`。`latest` 可用于已配置跟踪该标签的 Watchtower 容器。这里的拉取命令不会配置 Watchtower，也不会将现有 systemd、mise 或 Compose 部署迁移为容器。

## 同步与校验

[同步工作流](.github/workflows/sync.yml) 在每 6 小时的第 17 分钟检查一次，也支持在 Actions 页面手动运行。GitHub 定时任务可能延迟，不提供准点保证。

1. 查询 GitHub 的 `releases/latest`，仅接受非草稿、非预发布的 `vX.Y.Z` 正式版本。
2. 先解析两个官方版本标签的多架构 index digest。任一镜像缺失、不可访问或不是多架构镜像，任务立即失败，保留已有 `latest`，等待下次定时运行或手动重试。
3. 按 digest 使用 `regctl image copy --force-recursive` 复制全部架构，包括 index 引用的证明清单。不指定 `--platform`，不转换 manifest 格式。先写入目标 digest，不移动任何标签。
4. 比较源、目标 index 原始字节及 digest；递归获取全部子 manifest，验证 SHA-256，并检查每个配置 blob 和层的可访问性。随后拉取两个目标 amd64 镜像，在无网络、只读文件系统、无额外 capabilities 的临时容器中执行 `--version`，与 Release 版本比较。
5. 两个镜像均通过上述检查后，保留对应版本标签；已有版本标签的 digest 若不一致则停止，拒绝覆盖。再次检查两个上游版本标签仍指向已验证 digest，然后更新两个 `latest` 并回读校验。

两个 `latest` 属于独立的注册表写入，注册表不提供跨镜像原子事务。若最后的标签写入发生网络或权限错误，可能出现一个 `latest` 已更新、另一个仍为旧版；已更新的镜像也必须事先通过双镜像校验。任务会失败，可重跑以收敛到同一版本。并发控制禁止同时执行同步，重复运行不会产生新镜像内容。

每次运行在 Actions Summary 中记录版本、两个 digest 和上游 Release，在 `digest-evidence-*` artifact 中保留 Release 元数据、index、子 manifest 及版本检查结果，保留 90 天。版本镜像标签保留用于追溯。`latest` 是可变别名，不意味着自动更新一定适合所有配置；本仓库不测试具体 FRP 隧道或服务器配置的升级兼容性。

工作流还会在无包权限、无注册表登录的独立任务中拉取两个镜像的版本标签和 `latest`，检查 digest 并执行版本检查。匿名访问失败会使整个工作流失败。

## 权限与维护

工作流仅申请 `contents: read` 和 `packages: write`，使用自动生成的 `GITHUB_TOKEN`。不需要 PAT、Docker Hub 凭据或常驻服务。`regctl` 固定为 `v0.11.7` 并检查 SHA-256，使用的 Actions 固定到提交 SHA。更新工具时同时核对官方 Release 的二进制校验和。

GHCR 新包默认是私有包，与公开 GitHub 仓库的可见性分别管理。首次发布后，在每个包的 Package settings 中连接 `Aethersailor/frp-image-sync`，确认该仓库的 Actions 有写入权限，并将包设为 Public。镜像公开后支持匿名拉取，无需在服务器保存 GitHub 凭据。关联包时不要为修改来源标签而重建镜像。

GitHub 会在公开仓库连续 60 天没有活动时自动禁用定时工作流。若 Actions 页面显示定时任务已禁用，需要重新启用；工作流失败也应在 Actions 页面查看日志并处理。这里不通过额外写入权限、空提交或外部定时服务保持活动。

## 依据

- [上游镜像发布流程（v0.71.1）](https://github.com/fatedier/frp/blob/v0.71.1/.github/workflows/build-and-push-image.yml)：正式 Release 触发，发布 `frpc`、`frps` 的版本标签，架构为 `linux/amd64`、`linux/arm/v7`、`linux/arm64`、`linux/ppc64le`。后续同步保留新版本实际发布的完整 index。
- [regctl image copy](https://regclient.org/cli/regctl/image/copy/)：支持跨注册表复制及同仓库添加标签，未指定平台时复制完整镜像。
- [GitHub 包权限和可见性](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility)：包的权限、可见性及匿名访问。
- [GitHub 定时工作流](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)：定时运行限制及不活跃仓库的禁用规则。

本仓库仅同步镜像；不管理服务器、业务配置或部署迁移。镜像内部软件继续适用各自上游许可证。
