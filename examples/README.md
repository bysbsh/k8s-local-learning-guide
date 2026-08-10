# 配套实践示例

这里保存各篇教程对应的完整示例文件。它们是个人 GitOps 实验仓库的脱敏版本，不包含
Token、密码、SSH 私钥或真实生产配置。

## 目录

| 目录 | 内容 | 对应教程 |
|---|---|---|
| `00-namespace` | 学习命名空间 | 第 3 篇 |
| `01-basic-web` | ConfigMap、Secret 挂载、Deployment、Service 和 Ingress | 第 3、4 篇 |
| `02-whoami` | 使用第二个域名验证 Traefik 路由 | 第 4 篇 |
| `03-storage` | PVC 与使用该 PVC 的 Pod | 第 6 篇 |
| `04-helm-web` | 最小可读的 Helm Chart | 第 4 篇 |
| `05-custom-image` | Dockerfile、自建镜像和滚动发布资源 | 第 7 篇 |

## 使用原则

不要直接执行以下命令：

```bash
kubectl apply -R -f examples
```

不同示例具有不同前置条件，例如 Secret、Traefik、PVC 或已经加载到 Kind 的本地镜像。
请按照对应教程逐个执行。

## 基础 Web 示例

先创建 Namespace：

```bash
kubectl apply -f examples/00-namespace/namespace.yaml
```

创建不会提交到 Git 的演示 Secret：

```bash
kubectl create secret generic web-credentials \
  -n k8s-study \
  --from-literal=username=demo \
  --from-literal=password='replace-me'
```

再应用基础资源：

```bash
kubectl apply -f examples/01-basic-web/configmap.yaml
kubectl apply -f examples/01-basic-web/deployment.yaml
kubectl apply -f examples/01-basic-web/service.yaml
```

安装 Traefik 后才能应用并使用 Ingress：

```bash
kubectl apply -f examples/01-basic-web/ingress.yaml
```

## Helm 示例

先渲染检查，不修改集群：

```bash
helm template helm-web examples/04-helm-web \
  -n k8s-study
```

确认输出后再安装：

```bash
helm upgrade --install helm-web examples/04-helm-web \
  -n k8s-study \
  --create-namespace
```

## 自建镜像示例

先构建镜像并加载到 Kind：

```bash
docker build -t study-web:v2 examples/05-custom-image/app
kind load docker-image study-web:v2 --name study
kubectl apply -f examples/05-custom-image/app.yaml
```

详细原理、预期输出和故障处理请返回对应篇章阅读。

[返回教程目录](../README.md)
