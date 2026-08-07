# 第 4 篇：Helm、Traefik 与 Ingress

## 本篇概述

- **为什么要学**：ClusterIP Service 只能在集群内部访问，给每个服务单独开端口也难以管理。Ingress 提供统一的 HTTP 路由，Traefik 负责真正转发流量；Helm 则让复杂组件的安装和升级可重复。
- **会完成什么**：用 Helm 安装 Traefik，创建 Ingress，并用 `web.localhost` 和 `whoami.localhost` 验证路由。
- **开始前需要**：Helm 可用，`web-service` 已在 `k8s-study` 中正常运行。
- **完成标志**：浏览器能通过 `localhost:8090` 的不同域名访问不同 Service。

## 0. 开始前检查

```bash
helm version
kubectl get nodes
kubectl get service web-service -n k8s-study
```

继续本篇前应满足：Helm 能显示版本、节点是 `Ready`、`web-service` 存在。

## 1. Helm 是什么

Helm 是 Kubernetes 的包管理器：

```text
Chart   → 一套可参数化的 Kubernetes YAML 模板
Release → 某个 Chart 在集群中的一次安装实例
Values  → 安装时使用的配置参数
```

Helm 适合安装 Traefik、Prometheus、Argo CD 等复杂第三方组件。自己的简单应用可以继续使用原始 YAML，不必先学会编写 Chart。

## 2. 添加 Traefik Chart 仓库

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm search repo traefik/traefik
```

- `repo add`：保存 Chart 仓库地址。
- `repo update`：刷新本地 Chart 索引。
- `search repo`：搜索可安装的 Chart 和版本。

## 3. 安装 Traefik

```bash
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --version 41.1.1 \
  --set service.spec.type=ClusterIP
```

参数说明：

- 第一个 `traefik`：Release 名称。
- `traefik/traefik`：仓库名/Chart 名。
- `--namespace traefik`：安装到独立命名空间。
- `--create-namespace`：命名空间不存在时自动创建。
- `--set service.spec.type=ClusterIP`：使用本地集群内部 Service。

检查：

```bash
helm list -n traefik
kubectl get pods,services -n traefik
```

本次安装版本：Chart `41.1.1`，Traefik `v3.7.9`。

## 4. Ingress 和 Ingress Controller

Ingress 是 Kubernetes 资源，只描述路由规则；它本身不会接收流量。

Ingress Controller 是真正处理请求的程序。本次由 Traefik 实现。

```text
浏览器请求
  ↓
Traefik Ingress Controller
  ↓ 读取 Ingress 规则
Service
  ↓
Pod
```

因此：

- `kind: Ingress` 是规则。
- Traefik 是执行规则的 Controller。
- 安装 Controller 后，Ingress 才会真正生效。

Traefik 和 ingress-nginx 都是 Ingress Controller，但由不同项目实现：

```text
Ingress          → Kubernetes 标准路由资源
Traefik          → 一种 Controller 实现
ingress-nginx    → 另一种 Controller 实现
```

学习环境选择其中一个即可。本教程使用 Traefik，不需要同时安装 ingress-nginx。

## 5. 创建 Ingress

创建文件：

```bash
cd ~/k8s-study
nano ingress.yaml
```

粘贴下面内容：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: k8s-study
spec:
  ingressClassName: traefik
  rules:
    - host: web.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

应用：

```bash
kubectl apply -f ingress.yaml
```

关键字段：

- `ingressClassName: traefik`：指定由 Traefik 处理。
- `host`：匹配请求域名。
- `path: /`：匹配 URL 路径。
- `service.name`：转发目标 Service。

## 6. 从 Mac 访问

```bash
kubectl port-forward service/traefik -n traefik 8090:80
```

访问：

```text
http://web.localhost:8090
```

`.localhost` 通常自动解析到 `127.0.0.1`，不需要修改 `/etc/hosts`。

这条 port-forward 的含义：

```text
Mac 8090 → Traefik Service 80 → Ingress 规则 → 业务 Service → Pod
```

终端关闭或按 `Ctrl+C` 后入口停止，但集群中的 Traefik 和业务 Pod 仍在运行。

这条命令执行后终端不返回提示符是正常的。保持该终端打开，再新开一个终端或浏览器继续操作。

## 7. 用 whoami 验证第二条路由

`whoami` 是一个测试用 HTTP 服务。它会把收到的请求信息返回给浏览器，不是终端里的同名系统命令。

创建文件：

```bash
cd ~/k8s-study
nano whoami.yaml
```

粘贴完整内容：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: k8s-study
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.11.0
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: k8s-study
spec:
  selector:
    app: whoami
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: whoami
  namespace: k8s-study
spec:
  ingressClassName: traefik
  rules:
    - host: whoami.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: whoami
                port:
                  number: 80
```

保存后应用：

```bash
kubectl apply -f whoami.yaml
kubectl get deployment,pods,service,ingress -n k8s-study
```

保持 Traefik port-forward 运行，访问：

```text
http://whoami.localhost:8090
```

如果页面返回 Pod 名、IP 和请求 Header，说明同一个 Traefik 已能根据不同域名转发到不同 Service。

## 8. Helm 常用命令

```bash
# 查看所有 Release
helm list -A

# 查看历史
helm history traefik -n traefik

# 查看状态
helm status traefik -n traefik

# 升级
helm upgrade traefik traefik/traefik -n traefik --reuse-values

# 卸载
helm uninstall traefik -n traefik
```

`helm template` 需要 Release 名和 Chart：

```bash
helm template demo traefik/traefik
```

它只在终端渲染 YAML，不安装资源。

## 9. 可选实验：理解 Chart 和 Release

生成示例 Chart：

```bash
cd ~/k8s-study
helm create web-chart
```

`web-chart` 是 Helm 自动生成的教学模板目录，不是固定名称，可以改成其他名字。

先渲染 YAML，不安装：

```bash
helm template helm-web ./web-chart \
  --set replicaCount=2 \
  --set image.repository=nginx \
  --set image.tag=1.29.8-alpine
```

确认没有报错后安装：

```bash
helm install helm-web ./web-chart \
  -n k8s-study \
  --set replicaCount=2 \
  --set image.repository=nginx \
  --set image.tag=1.29.8-alpine
```

这里 `web-chart` 是 Chart，`helm-web` 是 Release。

查看和升级：

```bash
helm list -n k8s-study
helm history helm-web -n k8s-study
helm upgrade helm-web ./web-chart -n k8s-study --reuse-values --set replicaCount=3
helm history helm-web -n k8s-study
```

回滚到上一个 Release Revision：

```bash
helm rollback helm-web 1 -n k8s-study
```

这个实验只用于理解 Helm。觉得 Chart 模板复杂时可以跳过，不影响后面的 Argo CD 原始 YAML 流程。

为了避免示例 Chart 被 Argo CD 当作应用配置，后续初始化 Git 前把它加入 `.gitignore`：

```text
web-chart/
```

## 10. Helm 和自己的应用

自己的 Web 应用也能交给 Helm 管理，但入门阶段可以跳过 Chart 编写。先掌握：

```text
原始 YAML → Git → Argo CD
```

等遇到多环境参数、重复部署或应用分发需求时，再把 YAML 模板化成 Chart。

## 11. 本篇完成标准

- 能解释 Chart、Release 和 Values。
- 知道 Ingress 是规则、Controller 才执行规则。
- 能通过 Traefik 把域名请求转发到 Service。
- 知道 port-forward 是临时 Mac 入口。

[上一篇：YAML、配置与资源治理](./03-YAML配置与资源治理.md) | [下一篇：Argo CD 与 GitOps](./05-ArgoCD与GitOps.md)
