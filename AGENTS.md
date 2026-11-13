# 维护约定

- 保留现有 Docker Hub 和 GHCR 镜像路径、标签含义、启动参数及配置挂载方式。
- 本仓库独立维护打包、发布和版本处理。仅修改文档时不触发发布。
- 保留发布工作流定义的上游来源、检查周期及发布方式。发布使用 GitHub 内置 `GITHUB_TOKEN` 和仓库的 `DOCKERHUB_USERNAME`、`DOCKERHUB_TOKEN` Secrets。
- Dependabot 的版本和安全更新自动合并。仓库不设置必需检查、人工审批或测试工作流。
