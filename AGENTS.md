# 维护约定

- 保留现有 Docker Hub 和 GHCR 镜像路径、标签含义、启动参数及配置挂载方式。
- 本仓库独立维护打包、发布和版本处理。仅修改文档时不触发发布。
- 保留发布工作流定义的上游来源、检查周期及发布方式。发布使用 GitHub 内置 `GITHUB_TOKEN` 和仓库的 `DOCKERHUB_USERNAME`、`DOCKERHUB_TOKEN` Secrets。
- CodeQL 扫描和 Dependabot 自动合并不设发布门禁。目录迁移核对语法、路径，并用原有发布流程验证镜像。
