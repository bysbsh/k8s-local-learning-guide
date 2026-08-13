# 从零学 Kubernetes：macOS 本地实战（Kind + Helm + Traefik + Argo CD）

> 本文记录我在 Mac 上从零搭建 Kubernetes 学习环境的过程，适合第一次接触 Kubernetes 的开发者。
>
> 完整分篇教程、YAML、Helm Chart、Dockerfile 和截图：
>
> [https://github.com/bysbsh/k8s-local-learning-guide](https://github.com/bysbsh/k8s-local-learning-guide)

## 一、为什么在 Mac 上学习 Kubernetes

入门 Kubernetes 不必先购买服务器，也不必一开始安装 Rancher。使用 Docker Desktop + Kind，可以在 Mac 上创建一个真实的单节点 Kubernetes 集群，成本低、创建快、容易删除和重建。

本地环境的关系如下：

```text
Mac
└── Docker Desktop
    └── Kind 节点容器
        └── Kubernetes 集群
            ├── Deployment / Pod / Service
            ├── Ingress / Traefik
            ├── Argo CD
            └── PVC / PV
```

本文最终完成这条发布链路：

```text
网页代码 → Docker 镜像 → Kind 节点 → Deployment → Service
                                      ↓
                             Traefik Ingress
                                      ↓
                                Argo CD + Git
```

> 这是学习环境，不是生产环境。Kind 节点运行在 Docker Desktop 中，Docker 或 Mac 停止后集群也会停止。

## 二、安装本地 Kubernetes

### 1. 安装 Homebrew 和 Docker Desktop

如果没有 Homebrew，执行：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Apple Silicon Mac 通常需要加载 Homebrew：

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

安装并启动 Docker Desktop：

```bash
brew install --cask docker
open -a Docker
docker version
```

输出中同时有 `Client` 和 `Server`，说明 Docker 已经准备好。

### 2. 安装 kubectl、Kind 和 Helm

```bash
brew install kubectl kind helm
kubectl version --client
kind version
helm version
```

三个工具的作用：

| 工具 | 作用 |
|---|---|
| `kubectl` | 操作 Kubernetes 资源 |
| `kind` | 在 Docker 容器中创建 Kubernetes |
| `helm` | 安装和管理 Kubernetes 应用包 |

### 3. 创建集群

```bash
kind create cluster --name study
kubectl config current-context
kubectl get nodes
```

当前上下文应为 `kind-study`。节点刚创建时可能是 `NotReady`，等待几十秒后再次检查，直到出现：

```text
study-control-plane   Ready
```

![Kind 节点和 Deployment 状态](https://raw.githubusercontent.com/bysbsh/k8s-local-learning-guide/main/assets/screenshots/01-cluster-ready.png)

## 三、Deployment、Pod 和 Service

### 1. 创建命名空间和 Deployment

```bash
kubectl create namespace k8s-study
kubectl config set-context --current --namespace=k8s-study
kubectl create deployment web --image=nginx:1.29.8-alpine
kubectl get deployments,pods
```

对象关系是：

```text
Deployment → ReplicaSet → Pod → Container
```

Pod 名称类似 `web-7fbc579fd4-t8fbv`，`nginx` 是镜像或容器名，`web` 才是 Deployment 名。Pod 是可替换实例，名称和 IP 都可能变化。

### 2. 扩容和创建 Service

```bash
kubectl scale deployment web --replicas=3
kubectl get pods
kubectl expose deployment web \
  --name=web-service \
  --port=80 \
  --target-port=80
kubectl get service web-service
```

Service 默认是 `ClusterIP`，提供集群内部的稳定虚拟 IP。它通过标签选择器找到 Pod，而不是依赖固定 Pod 名。

从 Mac 临时访问：

```bash
kubectl port-forward service/web-service 8080:80
```

浏览器打开 `http://localhost:8080`。按 `Ctrl+C` 只会停止端口转发，不会删除 Deployment、Service 或 Pod。

集群内部测试：

```bash
kubectl run test-client \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl:8.12.1 \
  --command -- curl -I http://web-service
```

看到 `HTTP/1.1 200 OK`，说明 Service 已成功转发到 Nginx Pod。

## 四、YAML、ConfigMap 和 Secret

命令式创建适合快速实验，长期维护应使用 YAML。YAML 可以进入 Git、审查、回滚，也能交给 Argo CD 自动同步。

Deployment 的最小结构：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: k8s-study
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.29.8-alpine
          ports:
            - containerPort: 80
```

`selector.matchLabels` 必须和 `template.metadata.labels` 对应。应用前先检查：

```bash
kubectl apply --dry-run=client -f web.yaml
kubectl apply -f web.yaml
```

ConfigMap 用来保存普通配置或网页内容；Secret 用来保存密码、Token 等敏感配置。Secret 默认是 Base64 编码，不等于自动加密，真实凭据不要提交到 GitHub。

## 五、Helm、Traefik 和 Ingress

### 1. Helm 是什么

Helm 是 Kubernetes 的包管理器：

```text
Chart   → 可参数化的 YAML 模板
Release → Chart 在集群中的一次安装实例
Values  → 安装时使用的配置参数
```

### 2. 用 Helm 安装 Traefik

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set service.spec.type=ClusterIP
kubectl get pods,services -n traefik
```

Ingress 只是路由规则，Traefik 是真正执行规则的 Ingress Controller：

```text
浏览器 → Traefik Controller → Ingress 规则 → Service → Pod
```

Traefik 和 ingress-nginx 都是 Controller，学习环境选择一个即可。

### 3. 创建 Ingress

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

```bash
kubectl apply -f ingress.yaml
kubectl port-forward service/traefik -n traefik 8090:80
```

打开 `http://web.localhost:8090`。`.localhost` 通常会解析到 `127.0.0.1`，不需要修改 `/etc/hosts`。

## 六、Argo CD 与 GitOps

### 1. GitOps 的核心思想

```text
修改 YAML → git commit → git push → Argo CD 读取 Git → 同步 Kubernetes
```

Git 是期望状态的来源，Argo CD 负责让集群实际状态追上 Git。

### 2. 安装和访问 Argo CD

```bash
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd
```

访问 Argo CD：

```bash
kubectl port-forward service/argocd-server -n argocd 8082:443
```

打开 `https://localhost:8082`。本地自签名证书引起的安全提示是正常的。读取初始密码：

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

用户名固定为 `admin`，密码不要写入文章、截图或 Git。

### 3. Application 和同步状态

本文示例使用公开仓库的 `examples/01-basic-web` 目录。创建 Application 前，先确保已经安装 Traefik，并准备 Namespace 和演示 Secret：

```bash
kubectl apply -f https://raw.githubusercontent.com/bysbsh/k8s-local-learning-guide/main/examples/00-namespace/namespace.yaml
kubectl create secret generic web-credentials \
  -n k8s-study \
  --from-literal=username=demo \
  --from-literal=password='replace-me'
```

`web-credentials` 只用于演示 Secret 挂载，不能替换成真实生产密码。Secret 不在公开仓库中，避免把凭据提交到 Git。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8s-study
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/bysbsh/k8s-local-learning-guide.git
    targetRevision: main
    path: examples/01-basic-web
  destination:
    server: https://kubernetes.default.svc
    namespace: k8s-study
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
```

```bash
kubectl apply -f application.yaml
kubectl get application k8s-study -n argocd
```

| 状态 | 含义 |
|---|---|
| `Synced` | Git 和集群状态一致 |
| `OutOfSync` | Git 和集群有差异 |
| `Progressing` | 资源正在启动或健康状态尚未汇总 |
| `Healthy` | 资源达到健康判断标准 |

![Argo CD 资源树](https://raw.githubusercontent.com/bysbsh/k8s-local-learning-guide/main/assets/screenshots/05-argocd-resource-tree.jpg)

同步较慢时可以主动刷新：

```bash
kubectl annotate application k8s-study \
  -n argocd \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

### 4. Argo CD 为什么关掉终端还在运行

Argo CD Pod 运行在 Kind 集群中，不依赖当前终端。`port-forward` 只是 Mac 的临时访问入口：

```text
Kubernetes → argocd-server Service → kubectl port-forward → localhost:8082
```

如果希望关闭终端后入口仍然存在：

```bash
nohup kubectl port-forward \
  -n argocd \
  service/argocd-server 8082:443 \
  > /tmp/argocd-port-forward.log 2>&1 &
```

停止后台进程：

```bash
lsof -nP -iTCP:8082 -sTCP:LISTEN
kill PID
```

生产环境通常使用正式域名、HTTPS、Ingress 或 LoadBalancer，不依赖 `port-forward`。

## 七、PVC、PV 和持久化存储

容器和 Pod 都可能被重建，数据不能只写在容器临时文件系统中：

```text
Pod → PVC（存储申请） → PV（实际存储） → StorageClass（动态供给规则）
```

PVC 示例：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storage-demo
  namespace: k8s-study
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
```

```bash
kubectl apply -f pvc.yaml
kubectl get pvc storage-demo -n k8s-study
kubectl get pv
```

使用 `WaitForFirstConsumer` 的 StorageClass 在没有 Pod 引用时显示 `Pending` 是正常的；Pod 引用后通常会变成 `Bound`。

Namespace 下的所有 Pod 不会自动共享 PVC，必须在 Pod YAML 中明确声明：

```yaml
spec:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: storage-demo
  containers:
    - name: web
      volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
```

## 八、自建镜像和滚动发布

Dockerfile 示例：

```dockerfile
FROM nginx:1.29.8-alpine
COPY index.html /usr/share/nginx/html/index.html
```

构建并加载到 Kind：

```bash
docker build -t study-web:v1 .
kind load docker-image study-web:v1 --name study
docker exec study-control-plane crictl images | grep study-web
```

Kind 节点是独立容器，Mac 本地镜像不会自动出现在节点中。使用本地镜像时：

```yaml
image: study-web:v1
imagePullPolicy: Never
```

发布 v2：

```bash
docker build -t study-web:v2 .
kind load docker-image study-web:v2 --name study
```

更新 Deployment 中的镜像版本后，观察滚动更新：

```bash
kubectl get pods -n k8s-study -l app=my-app --watch
kubectl rollout status deployment/my-app -n k8s-study
kubectl rollout history deployment/my-app -n k8s-study
kubectl rollout undo deployment/my-app -n k8s-study
```

Deployment 会逐步创建新 Pod，等待新 Pod 就绪后再删除旧 Pod。

## 九、常见故障排查

遇到问题时按固定顺序检查：

```bash
kubectl get pods -n k8s-study -o wide
kubectl describe pod POD_NAME -n k8s-study
kubectl logs POD_NAME -n k8s-study
kubectl get events -n k8s-study --sort-by=.lastTimestamp
kubectl rollout status deployment/DEPLOYMENT_NAME -n k8s-study
```

| 错误 | 常见原因 | 处理方向 |
|---|---|---|
| `apiVersion not set` | YAML 顶层字段缺失或缩进错误 | 检查 `apiVersion`、`kind`、`metadata` |
| `ImagePullBackOff` | 镜像不存在、网络失败或 Kind 没有本地镜像 | 检查 Events，必要时 `kind load docker-image` |
| `mountPath must be unique` | 同一容器重复挂载相同目录 | 删除重复 `volumeMounts` |
| PVC `Pending` | 没有 Pod 引用或 StorageClass 尚未供给 | 查看 PVC、Pod 和 Events |
| Argo CD `OutOfSync` | Git 与集群存在差异 | 检查 revision，执行 refresh |
| zsh `no matches found` | 方括号被 zsh 当成通配符 | 给参数加单引号 |

zsh 中查看容器镜像时，给 `custom-columns` 加单引号：

```bash
kubectl get pods -n k8s-study \
  -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image'
```

Argo CD 页面使用 `https://localhost:8082`。如果入口已退出，重新执行：

```bash
kubectl port-forward service/argocd-server -n argocd 8082:443
```

## 十、清理学习环境

停止 `port-forward`：在对应终端按 `Ctrl+C`。删除整个 Kind 学习集群：

```bash
kind delete cluster --name study
```

这会删除 Kind 节点、Kubernetes 资源、Argo CD、Helm Release、PVC/PV 和加载到 Kind 节点的镜像副本，但不会删除 Mac 上安装的软件或 Git 仓库。

## 十一、总结

1. Docker Desktop + Kind 创建本地集群。
2. Deployment 管理 Pod 副本。
3. Service 提供稳定的集群内部入口。
4. ConfigMap 和 Secret 管理配置。
5. Helm 安装 Traefik，Ingress 将域名路由到 Service。
6. PVC/PV 保存 Pod 重建后的数据。
7. Dockerfile 构建镜像并完成 v1 到 v2 的滚动发布。
8. Argo CD 根据 Git 自动同步 Kubernetes。

```text
Pod 会变，Service 提供稳定入口。
Ingress 只描述路由，Controller 才真正转发流量。
Helm 管理应用包，Argo CD 管理 Git 与集群的一致性。
容器会重建，PVC 保存持久数据。
Kind 适合学习，生产环境还需要正式入口、HTTPS、备份、监控和高可用。
```

## 完整教程和源码

本文对应的完整分篇教程、示例 YAML、Helm Chart、Dockerfile、截图和故障排查手册：

[https://github.com/bysbsh/k8s-local-learning-guide](https://github.com/bysbsh/k8s-local-learning-guide)
