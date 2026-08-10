# 第 11 篇：从 Kind 走向生产环境

## 本篇概述

- **为什么要学**：本地 Kind 能验证 Kubernetes YAML，但不能自动提供公网入口、高可用、备份和生产安全。理解差距后，才不会把 `port-forward` 或本地镜像配置误当成正式部署方案。
- **会学到什么**：Kind、K3s 和托管 Kubernetes 的定位，ClusterIP、NodePort、LoadBalancer 与 Ingress 的关系，以及一个 Web 应用进入生产前需要补齐的能力。
- **开始前需要**：已经理解 Deployment、Service、Ingress、Secret、PVC 和 Argo CD。
- **完成标志**：能画出生产访问链路，知道单服务器的故障边界，并能列出从本地迁移到服务器的检查清单。

本篇用于建立生产环境地图，不要求现在购买服务器，也不会让你直接操作真实生产集群。

## 1. 本地学习环境与生产环境

当前本地环境：

```text
Mac 浏览器
  ↓ localhost:8090
kubectl port-forward
  ↓
Traefik Service
  ↓
Ingress
  ↓
业务 Service
  ↓
Pod
```

典型生产环境：

```text
用户访问 https://app.example.com
  ↓
DNS
  ↓
云 LoadBalancer 或外部负载均衡器
  ↓
Ingress Controller（Traefik / Nginx）
  ↓
Ingress 路由
  ↓
业务 Service
  ↓
多个 Pod
```

两者使用的 Deployment、Service 和 Ingress 概念相同，差别主要在集群运行位置、外部入口、镜像来源、存储和运维保障。

| 对比 | 本地 Kind | 生产环境 |
|---|---|---|
| 节点 | Docker 容器 | 云服务器、虚拟机或物理机 |
| 入口 | port-forward 或本地端口映射 | LoadBalancer + Ingress + 正式域名 |
| 镜像 | 可以直接加载到 Kind | 必须从镜像仓库拉取 |
| 存储 | 本机 Docker 数据 | 云盘、分布式存储或托管存储 |
| 可用性 | 单节点，电脑关闭即停止 | 多节点、健康检查、故障迁移 |
| 运维 | 手工观察即可 | 监控、日志、告警、备份和升级计划 |

## 2. 三种 Service 类型

### ClusterIP

```text
集群内 Pod → ClusterIP Service → 后端 Pod
```

这是默认类型，只提供集群内部入口。普通业务 Service 通常保持为 ClusterIP，再由 Ingress Controller 访问它。

### NodePort

```text
外部请求 → 节点 IP:固定端口 → Service → Pod
```

NodePort 会在节点开放一个端口，常用于实验、裸机集群的底层接入或外部负载均衡器的后端。它能提供入口，但不负责域名、证书和复杂 HTTP 路由。

### LoadBalancer

```text
公网或内网 IP → LoadBalancer → Kubernetes 节点 → Service / Pod
```

`type: LoadBalancer` 是向基础设施提出请求。云 Kubernetes 通常会调用云平台 API 创建负载均衡器；Kind 没有云控制器，因此 `EXTERNAL-IP` 可能一直是 `<pending>`。

本地或裸机集群需要 MetalLB、cloud-provider-kind 或其他实现，才能为 LoadBalancer Service 提供实际入口。

## 3. LoadBalancer、Nginx 和 Traefik

LoadBalancer 是一种职责，Nginx 和 Traefik 是可以承担部分流量职责的软件。

Nginx 可以是：

```text
Web 服务器
反向代理
负载均衡器
Nginx Ingress Controller
```

Traefik 常作为 Ingress Controller，根据 Ingress 中的域名和路径规则转发请求。

生产环境中经常同时存在两层：

```text
云 LoadBalancer：把 80/443 流量送进集群
Ingress Controller：根据域名和路径送到不同 Service
```

它们不是重复组件，而是处理不同范围的问题。

## 4. Kind、K3s 和托管 Kubernetes

| 方案 | 适合场景 | 主要特点 |
|---|---|---|
| Kind | Mac 本地学习、CI 测试 | 创建删除方便，节点运行在 Docker 中 |
| K3s | Linux 单机、边缘设备、小型集群 | 轻量安装，作为系统服务长期运行，默认集成常用组件 |
| 托管 Kubernetes | 企业云环境、需要扩缩容和高可用 | 云厂商管理控制平面，并集成负载均衡和云存储 |

K3s 是 Kubernetes 发行版，不是 Kubernetes 内部组件。它仍然使用相同的 kubectl、Deployment、Service、Ingress、Helm 和 Argo CD。

Rancher 是更上层的集群管理平台，可以管理 K3s 和其他 Kubernetes 集群，但不是安装 K3s 的必需条件。

## 5. 为什么生产服务不依赖终端

在 Linux 服务器上，Kubernetes 节点组件和容器运行时通常由系统服务管理：

```text
Linux 启动
  ↓
systemd 启动 containerd / kubelet / K3s
  ↓
Kubernetes 控制器恢复期望的 Pod
  ↓
LoadBalancer 或 Ingress 持续接收请求
```

`kubectl` 只是操作 Kubernetes API 的客户端。关闭管理员终端不会停止集群，也不会停止已经创建的 Service、Ingress 或 Pod。

`kubectl port-forward` 是例外：它本身就是终端中的临时进程，所以只适合调试。

## 6. 一台服务器是否能作为生产环境

一台 Linux 服务器安装 K3s，可以长期运行真实应用，也适合个人项目、内部工具和低风险业务。但它仍然有单点故障：

```text
唯一服务器宕机
  ↓
控制平面、Pod、Ingress 和本地存储一起不可用
```

真正要求高可用时，通常需要：

- 多个控制平面节点，常见为 3 个。
- 多个工作节点，并把 Pod 副本分散到不同节点。
- 控制平面或入口前的负载均衡器。
- 不依赖单节点目录的持久化存储。
- 数据库和 PV 的备份、恢复演练。
- 节点、应用、证书和容量监控。

Kubernetes 能在其他健康节点重建 Pod，但不能凭空恢复已经丢失的单机数据。

## 7. 从本地镜像迁移到镜像仓库

本地 Kind 可以使用：

```yaml
image: study-web:v2
imagePullPolicy: Never
```

生产节点无法读取 Mac Docker 中的镜像。生产发布需要：

```text
源代码
  ↓ CI 构建
Docker 镜像
  ↓ push
Docker Hub / GHCR / Harbor
  ↓ pull
Kubernetes Pod
```

生产清单应引用不可混淆的版本，例如：

```yaml
image: ghcr.io/example/study-web:1.0.0
imagePullPolicy: IfNotPresent
```

私有仓库需要 `imagePullSecrets` 或云平台提供的工作负载身份。不要把仓库密码直接写入 Deployment YAML。

## 8. 域名和 HTTPS

生产入口一般需要完成：

1. LoadBalancer 获得公网或内网 IP。
2. DNS 把 `app.example.com` 指向该入口。
3. Ingress 使用相同域名匹配请求。
4. TLS 证书为 HTTPS 提供加密和身份验证。
5. cert-manager 等工具负责申请和续期证书。

`app.localhost` 只在本机解析，不是可以给其他用户访问的正式域名。

## 9. 配置、密码和权限

从学习环境迁移时，需要重新检查：

- ConfigMap 只保存非敏感配置。
- 密码和 Token 使用 Secret 或外部密钥管理系统。
- 不提交明文私钥、kubeconfig 和生产凭据。
- Pod 使用最小权限的 ServiceAccount。
- RBAC 限制用户和组件能操作的资源。
- NetworkPolicy 限制不必要的 Pod 间通信。
- `dev` Profile、演示账号和 `replace-me` 必须替换。

Kubernetes Secret 默认只是以 base64 保存，不等于加密。生产环境还要考虑静态加密、访问审计和密钥轮换。

## 10. 存储、备份和恢复

PVC 只能表达应用需要怎样的存储，不会自动保证数据永不丢失。

生产环境必须确认：

- StorageClass 实际由什么存储系统提供。
- 节点故障后卷能否在其他节点重新挂载。
- 删除 PVC 时 ReclaimPolicy 会怎样处理数据。
- 数据库应该怎样做一致性备份。
- 备份文件保存在哪里、保留多久。
- 是否真正执行过恢复演练。

没有验证过恢复流程的备份，不能视为可靠备份。

## 11. 监控、日志和发布保护

生产环境至少需要观察：

- 节点、Pod 和 Deployment 是否健康。
- CPU、内存、磁盘和网络是否接近上限。
- HTTP 错误率、请求延迟和业务指标。
- 容器日志和 Kubernetes Events。
- 证书过期、备份失败和镜像拉取失败告警。

GitOps 中启用 `prune`、自动同步或生产发布前，还应增加代码审查、分环境配置和回滚方案。

## 12. 推荐迁移顺序

不要一次安装所有平台。按照实际应用逐层补齐：

```text
1. 应用在本地 Kind 正常运行
2. 镜像推送到正式 Registry
3. 在隔离的 Linux 测试服务器或云测试集群部署
4. 配置 Service、Ingress 和测试域名
5. 配置 HTTPS 和 Secret
6. 验证日志、监控、备份和恢复
7. 接入 Git 和 Argo CD
8. 经过代码审查后再进入生产环境
```

个人学习的下一步可以选择一台可随时删除的 Linux 测试服务器安装 K3s；企业项目优先了解所在云平台的托管 Kubernetes 服务和团队现有规范。

## 13. 不要直接复制到生产的配置

以下内容只适合本教程：

```text
*.localhost
kubectl port-forward
imagePullPolicy: Never
study-web:v1 / study-web:v2 本地镜像
replace-me 演示密码
单节点 local-path PVC
未经限制的 dev 配置
```

生产环境不是把本地 YAML 原样上传到服务器，而是在保留 Kubernetes 核心对象关系的基础上，替换入口、镜像、存储、凭据和运维保障。

## 14. 本篇完成标准

- 能解释 ClusterIP、NodePort 和 LoadBalancer 的区别。
- 能解释 LoadBalancer 与 Ingress Controller 为什么可以同时存在。
- 知道 Kind 适合本地、K3s 适合轻量 Linux 场景、托管 Kubernetes 适合云上团队环境。
- 知道单服务器仍有单点故障。
- 能列出镜像仓库、域名、HTTPS、Secret、监控和备份等迁移事项。
- 不再把 `port-forward` 当作生产服务入口。

## 官方资料

- [Kubernetes：Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes：Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Kubernetes：生产环境](https://kubernetes.io/docs/setup/production-environment/)
- [K3s 官方文档](https://docs.k3s.io/)

[上一篇：Kubernetes 术语索引](./10-术语索引.md) | [返回目录](./README.md)
