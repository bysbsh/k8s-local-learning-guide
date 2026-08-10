# 第 3 篇：YAML、配置与资源治理

## 本篇概述

- **为什么要学**：只靠终端命令部署，过几天就很难还原当时做过什么，团队也无法审查。YAML 把期望状态保存成文件，是环境重建、版本管理和后续 GitOps 的基础。
- **会完成什么**：编写 Namespace、Deployment、Service、ConfigMap 和 Secret，并加入健康检查与资源限制。
- **开始前需要**：已理解 Deployment、Pod 和 Service，并准备好 `~/k8s-study` 目录。
- **完成标志**：完整 `web.yaml` 能通过 dry-run，两个 Nginx Pod 正常运行并读取 ConfigMap 页面。

## 0. 本篇操作约定

所有文件放在同一个目录：

```bash
mkdir -p ~/k8s-study
cd ~/k8s-study
pwd
```

预期最后一行类似：

```text
/Users/你的用户名/k8s-study
```

本篇使用 `nano` 编辑文件。保存方法固定为：

```text
Ctrl+O  → 保存
Enter   → 确认文件名
Ctrl+X  → 退出 nano
```

YAML 对空格非常敏感。复制示例时保留原缩进，不要使用 Tab。

## 1. 为什么要使用 YAML

命令式创建适合快速实验；长期维护应使用 YAML，因为它可以：

- 进入 Git 保存历史。
- 在团队中审查。
- 重建相同环境。
- 交给 Argo CD 自动同步。

## 2. Namespace

创建文件：

```bash
cd ~/k8s-study
nano namespace.yaml
```

粘贴下面内容：

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: k8s-study
```

应用：

```bash
kubectl apply -f namespace.yaml
```

查看：

```bash
kubectl get namespaces
kubectl get pods -n k8s-study
kubectl get pods -A
```

切换默认命名空间：

```bash
kubectl config set-context --current --namespace=k8s-study
```

如果当前是 `default`，执行 `kubectl describe deployment web` 可能得到 `NotFound`，因为资源实际在 `k8s-study`。

## 3. Deployment YAML

创建文件：

```bash
cd ~/k8s-study
nano web.yaml
```

粘贴下面内容：

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

`selector.matchLabels` 必须与 Pod 模板的 `labels` 对应。

应用前检查结构：

```bash
kubectl apply --dry-run=client -f web.yaml
```

正式应用：

```bash
kubectl apply -f web.yaml
```

## 4. Service YAML

创建文件：

```bash
cd ~/k8s-study
nano service.yaml
```

粘贴下面内容：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: k8s-study
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

- `port`：Service 对集群内部提供的端口。
- `targetPort`：后端容器实际监听的端口。
- `selector`：选择标签为 `app=web` 的 Pod。

保存后应用：

```bash
kubectl apply -f service.yaml
kubectl get deployment,pods,service -n k8s-study
```

成功标准：Deployment 为 `2/2`，两个 Pod 为 `Running`，`web-service` 类型为 `ClusterIP`。

## 5. ConfigMap

ConfigMap 是 Kubernetes 资源，用于保存非敏感配置。

创建文件：

```bash
cd ~/k8s-study
nano configmap.yaml
```

粘贴下面内容：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-content
  namespace: k8s-study
data:
  index.html: |
    <h1>Hello from Kubernetes</h1>
```

在 Deployment 中挂载：

```yaml
volumeMounts:
  - name: web-content
    mountPath: /usr/share/nginx/html
    readOnly: true
volumes:
  - name: web-content
    configMap:
      name: web-content
```

保存 ConfigMap 后应用：

```bash
kubectl apply -f configmap.yaml
```

这里先理解挂载关系，不要自己把片段拼进 `web.yaml`。继续完成 Secret、健康检查和资源限制后，直接使用第 9 节提供的完整 `web.yaml`，这样最不容易出现缩进错误。

绑定规则：

```text
volumeMounts.name = volumes.name
volumes.configMap.name = ConfigMap metadata.name
```

## 6. Secret

Secret 用于保存密码、令牌、证书和私钥。

```bash
kubectl create secret generic web-credentials \
  -n k8s-study \
  --from-literal=username=demo \
  --from-literal=password='replace-me'
```

`kind: Secret` 和 `apiVersion: v1` 是固定协议；资源名称、键和值由使用者决定。

不要把真实密码、令牌或 SSH 私钥直接提交到 Git。

## 7. 健康检查

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 2
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10
```

- readinessProbe：判断 Pod 是否可以接收流量。失败时 Service 暂时停止向它转发。
- livenessProbe：判断容器是否失去响应。持续失败时 Kubernetes 会重启容器。

## 8. 资源请求与上限

```yaml
resources:
  requests:
    cpu: 50m
    memory: 32Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

- `requests`：调度时声明的最低资源需求。
- `limits`：容器允许使用的最大资源。
- `50m` CPU 表示 0.05 个 CPU 核心。
- 内存超过 limit 时，容器可能被 OOMKilled。

## 9. 最终完整 web.yaml

为了避免自己拼接 YAML 时缩进错误，直接用下面的完整内容替换 `web.yaml`。

打开文件：

```bash
cd ~/k8s-study
nano web.yaml
```

删除原内容并粘贴：

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
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 128Mi
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html
              readOnly: true
            - name: web-credentials
              mountPath: /etc/web-credentials
              readOnly: true
      volumes:
        - name: web-content
          configMap:
            name: web-content
        - name: web-credentials
          secret:
            secretName: web-credentials
```

保存后先检查，不直接应用：

```bash
kubectl apply --dry-run=client -f web.yaml
```

没有报错后再执行：

```bash
kubectl apply -f configmap.yaml
kubectl apply -f web.yaml
kubectl apply -f service.yaml
kubectl get deployment,pods,service -n k8s-study
```

成功标准：Deployment 为 `2/2`，两个 `web` Pod 都是 `1/1 Running`，`web-service` 类型为 `ClusterIP`。

验证网页：

```bash
kubectl port-forward service/web-service -n k8s-study 8080:80
```

浏览器打开 `http://localhost:8080`。看到 `Hello from Kubernetes` 后，回到终端按 `Ctrl+C`。

![ConfigMap 提供的 Nginx 页面](./assets/screenshots/03-configmap-page.jpg)

> 成功页面：Nginx 从 `web-content` ConfigMap 挂载并返回自定义 `index.html`。

## 10. 目录与挂载常见误区

- Namespace 只负责资源隔离，不会自动共享目录。
- ConfigMap、Secret、PVC 必须由 Pod 明确引用。
- `mountPath` 是容器内路径，写在 `volumeMounts` 中。
- 同一容器内的两个 Volume 不能使用完全相同的 `mountPath`。

## 11. 本篇完成标准

- 能读懂 YAML 的核心层级。
- 能解释 ConfigMap、Secret 和 Pod 的绑定关系。
- 能区分 readinessProbe 与 livenessProbe。
- 能解释 requests 与 limits。

[上一篇：Deployment、Pod 与 Service](./02-Deployment-Pod与Service.md) | [下一篇：Helm、Traefik 与 Ingress](./04-Helm-Traefik与Ingress.md)
