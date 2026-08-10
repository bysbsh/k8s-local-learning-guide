# 从零学 Kubernetes：macOS 本地实战指南

这是一套按实际学习过程整理的分篇教程，适用于 macOS + Docker Desktop + Kind。每篇可以独立导入飞书，也可以从第 0 篇开始按编号照着做。

教程从一台尚未安装 Kubernetes 工具的 Mac 开始，最终完成自建 Docker 镜像、Traefik Ingress、Argo CD GitOps、PVC 持久化和 v1 → v2 滚动发布。

> 本教程于 2026 年 8 月在 macOS Apple Silicon 环境完成实测。工具更新后，界面或输出可能略有差异，但核心资源关系和排查方法不变。

## 跟做规则

1. 每次只执行一个代码块，确认成功后再继续。
2. 代码块中的命令可以整段复制，行末的 `\` 表示下一行仍属于同一条命令。
3. 不要复制终端提示符，例如 `ζ`、`$`、`# basil@...`。
4. 不要把教程中的“预期输出”重新输入终端，它只是用于核对结果。
5. `POD_NAME`、`你的用户名` 等大写或中文占位符，需要替换为自己的真实值。
6. `--watch` 和 `port-forward` 会持续运行；看到目标结果后按 `Ctrl+C` 退出。
7. Pod 名随机后缀、IP、资源年龄与教程不同是正常的，重点核对 `STATUS`、`READY` 和资源名称。
8. 如果某一步报错，先停止继续执行，前往第 8 篇按原始报错文字查找。

每篇开头的“本篇概述”会先回答为什么要学这一主题，再说明会完成什么、需要哪些前置条件以及什么状态算完成。

## 不知道从哪里开始

- 一台尚未安装工具的 Mac：从第 0 篇开始。
- Docker、kubectl、Kind、Helm 已安装，但没有集群：从第 0 篇第 9 节开始。
- `kubectl get nodes` 已显示 `Ready`：从第 1 篇开始。
- 已经会 Deployment 和 Service：从第 3 篇开始。
- 只想查报错或命令：直接看第 8、9 篇。

## 学习环境

- macOS（Apple Silicon）
- Docker 29.6.2
- kubectl v1.36.3
- Kind v0.32.0
- Kubernetes v1.36.1
- Helm v4.2.3
- Traefik v3.7.9
- Argo CD v3.5.0
- Kind 集群：`study`
- 学习命名空间：`k8s-study`

## 篇章目录

0. [从零安装本地 Kubernetes 环境](./00-从零安装本地Kubernetes环境.md)
1. [学习地图与环境准备](./01-学习地图与环境准备.md)
2. [Deployment、Pod 与 Service](./02-Deployment-Pod与Service.md)
3. [YAML、配置与资源治理](./03-YAML配置与资源治理.md)
4. [Helm、Traefik 与 Ingress](./04-Helm-Traefik与Ingress.md)
5. [Argo CD 与 GitOps](./05-ArgoCD与GitOps.md)
6. [PVC、PV 与持久化存储](./06-PVC-PV与持久化存储.md)
7. [自建镜像与滚动发布](./07-自建镜像与滚动发布.md)
8. [常见故障排查手册](./08-常见故障排查手册.md)
9. [命令速查、清理与下一步](./09-命令速查清理与下一步.md)
10. [Kubernetes 术语索引](./10-术语索引.md)

## 配套示例

教程中的脱敏版 Kubernetes YAML、Helm Chart、Dockerfile 和静态网页集中放在
[examples](./examples/README.md) 目录。可以先阅读教程理解每个字段，再使用示例核对
缩进和完整结构。

本仓库保存适合公开和复用的教材与示例；个人 Argo CD 实验仓库继续独立维护，避免
实验中的临时修改、凭据或环境配置进入公共教程。

## 学完后的完整链路

```text
应用代码
  ↓
Docker 构建镜像
  ↓
Kind 节点加载镜像
  ↓
Deployment 管理 Pod
  ↓
Service 提供内部入口
  ↓
Ingress + Traefik 提供 HTTP 路由
  ↓
Git 保存声明式配置
  ↓
Argo CD 自动同步到 Kubernetes
```

## 阅读建议

- 第 0 篇从一台尚未安装 Kubernetes 工具的 Mac 开始。
- 第 1～3 篇是 Kubernetes 核心基础。
- 第 4 篇解决 HTTP 入口和第三方组件安装。
- 第 5 篇建立 GitOps 发布流程。
- 第 6 篇理解 Pod 重建后如何保留数据。
- 第 7 篇完成自己的镜像从 v1 到 v2 的发布。
- 第 8、9 篇适合保留为日常参考手册。
- 第 10 篇用于随时查询术语，并快速返回对应的详细篇章。

> 学习原则：先理解 YAML 和 Kubernetes 对象，再使用 Rancher 等管理平台。这样才能知道界面操作实际修改了什么。

## 安全提醒

- 不要向 Issue、截图或 Git 提交真实 Token、密码和 SSH 私钥。
- 教程中的 `replace-me`、`YOUR_GITHUB_USERNAME` 都是占位符。
- 用于学习的 GitOps 仓库与真实生产配置应分开管理。

## License

本项目使用 [MIT License](./LICENSE)。
