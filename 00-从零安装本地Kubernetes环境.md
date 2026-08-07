# 第 0 篇：从零安装本地 Kubernetes 环境

这一篇从一台尚未安装 Kubernetes 工具的 Mac 开始。最终目标是在 Docker Desktop 中创建一个可用的单节点 Kind 集群。

## 本篇概述

- **为什么要学**：Kubernetes 的所有概念都需要一个真实集群才能理解。直接购买服务器成本高、清理麻烦；Kind 可以在 Mac 上提供可反复创建和删除的完整练习环境。
- **会完成什么**：安装 Homebrew、Docker Desktop、kubectl、Kind 和 Helm，并创建 `study` 集群。
- **开始前需要**：一台可以安装软件并访问互联网的 Mac，以及管理员权限。
- **完成标志**：`kubectl get nodes` 显示 `study-control-plane Ready`。

> 操作方式：打开 macOS 的“终端”应用，每次只复制一个命令块。命令没有报错并且符合“成功标准”后，再执行下一节。

## 1. 最终会安装什么

```text
Docker Desktop → 提供容器运行环境
Kind           → 在 Docker 容器中创建 Kubernetes 集群
kubectl        → 操作 Kubernetes 集群
Helm           → 安装复杂 Kubernetes 应用
```

本地结构：

```text
Mac
├── kubectl
├── kind
├── helm
└── Docker Desktop
    └── study-control-plane
        └── Kubernetes
```

Kubernetes 不是直接安装成一个普通 Mac 应用，而是由 Kind 创建在 Docker 容器中。

## 2. 检查 Mac 架构

```bash
uname -m
```

可能输出：

```text
arm64   # Apple Silicon
x86_64  # Intel Mac
```

Homebrew 会自动安装适合当前架构的软件包。

## 3. 安装 Homebrew

先检查是否已安装：

```bash
brew --version
```

如果能显示版本，跳到下一节。若提示 `command not found`，执行 Homebrew 官方安装命令：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

安装程序结束时会打印环境变量配置命令。Apple Silicon Mac 通常需要：

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

再次验证：

```bash
brew --version
```

成功标准：终端显示 Homebrew 版本号。

## 4. 安装 Docker Desktop

使用 Homebrew 安装：

```bash
brew install --cask docker
```

安装完成后启动：

```bash
open -a Docker
```

第一次启动需要在图形界面接受许可并授权。等待菜单栏中的 Docker 图标显示运行正常。

验证客户端和服务端：

```bash
docker version
```

成功标准：输出中同时存在 `Client` 和 `Server`。

如果出现：

```text
Cannot connect to the Docker daemon
```

说明 Docker Desktop 尚未启动完成。打开 Docker Desktop 并等待后重试。

建议给 Docker Desktop 至少保留约 4 个 CPU 和 6 GB 内存，以便同时运行 Kind、Traefik 和 Argo CD。

## 5. 安装 kubectl

```bash
brew install kubectl
```

验证：

```bash
kubectl version --client
```

`kubectl` 只是 Kubernetes 客户端。此时还没有集群，运行 `kubectl get nodes` 可能失败，这是正常的。

## 6. 安装 Kind

```bash
brew install kind
```

验证：

```bash
kind version
```

Kind 的作用是使用 Docker 容器模拟 Kubernetes 节点，适合本地学习和自动化测试。

## 7. 安装 Helm

```bash
brew install helm
```

验证：

```bash
helm version
```

Helm 不是创建集群的工具，而是 Kubernetes 集群创建后用于安装 Traefik 等应用的包管理器。

## 8. 一次性检查所有工具

```bash
docker version
kubectl version --client
kind version
helm version
```

本次教程实际使用的版本：

| 工具 | 版本 |
|---|---|
| Docker | 29.6.2 |
| kubectl | v1.36.3 |
| Kind | v0.32.0 |
| Helm | v4.2.3 |

版本不必完全一致，只要相近并且各命令可以正常执行即可。

## 9. 创建第一个 Kubernetes 集群

```bash
kind create cluster --name study
```

这条命令会：

1. 下载 Kind Kubernetes 节点镜像。
2. 创建名为 `study-control-plane` 的 Docker 容器。
3. 在容器中启动 Kubernetes 控制平面和节点组件。
4. 自动把 kubectl context 切换到 `kind-study`。

第一次创建需要下载镜像，速度取决于网络。

## 10. 验证 Docker 节点容器

```bash
docker ps
```

应能看到：

```text
study-control-plane
```

它既是 Docker 容器，也是当前单节点 Kubernetes 集群的节点。

## 11. 验证 kubectl 上下文

```bash
kubectl config current-context
```

预期：

```text
kind-study
```

如果电脑上有多个 Kubernetes 集群，context 决定 kubectl 当前操作哪个集群。

## 12. 验证 Kubernetes 节点

```bash
kubectl get nodes
```

刚创建时可能看到：

```text
study-control-plane   NotReady
```

等待几十秒后再次执行：

```bash
kubectl get nodes
```

成功标准：

```text
study-control-plane   Ready
```

查看更详细信息：

```bash
kubectl get nodes -o wide
```

## 13. 验证系统 Pod

```bash
kubectl get pods -n kube-system
```

你会看到 DNS、网络代理、API 相关组件。大部分 Pod 应为 `Running`。

这些是 Kubernetes 自己的系统组件，不需要手动修改。

## 14. 创建学习目录

```bash
mkdir -p ~/k8s-study
cd ~/k8s-study
```

后续所有 Kubernetes YAML、Dockerfile 和 Git 配置都保存在这里。

检查当前位置：

```bash
pwd
```

预期类似：

```text
/Users/你的用户名/k8s-study
```

## 15. 常见安装问题

### Homebrew 下载失败

通常是访问 GitHub 的网络问题。先确认：

```bash
curl -I https://github.com
```

不要随意执行来源不明的 Homebrew 镜像脚本。

### Docker 已安装但命令不可用

先启动 Docker Desktop：

```bash
open -a Docker
```

等待启动完成后重新打开终端。

### Kind 创建集群时拉取镜像失败

检查 Docker 是否正常：

```bash
docker info
```

然后查看本地已有 Kind 镜像：

```bash
docker images | grep kindest
```

镜像下载失败通常是网络问题，不是 kubectl 配置错误。

### kubectl 无法连接集群

检查集群和 context：

```bash
kind get clusters
kubectl config get-contexts
kubectl config use-context kind-study
```

## 16. 本篇完成标准

- `docker version` 同时显示 Client 和 Server。
- kubectl、Kind、Helm 均能显示版本。
- `kind get clusters` 能看到 `study`。
- `kubectl config current-context` 输出 `kind-study`。
- `kubectl get nodes` 显示 `study-control-plane Ready`。

达到这些标准后，本地 Kubernetes 环境已经安装完成，不需要购买服务器，也不需要先安装 Rancher。

[返回目录](./README.md) | [下一篇：学习地图与环境准备](./01-学习地图与环境准备.md)
