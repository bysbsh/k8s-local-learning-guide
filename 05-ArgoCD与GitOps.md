# 第 5 篇：Argo CD 与 GitOps

## 本篇概述

- **为什么要学**：多人手动修改集群会造成配置漂移，而且很难追踪谁在什么时候改了什么。GitOps 把 Git 设为唯一真实来源，让发布可审查、可追踪、可恢复，并由 Argo CD 自动保持集群一致。
- **会完成什么**：建立私有 Git 仓库、配置只读 Deploy Key、安装 Argo CD，并验证自动同步、自愈和删除策略。
- **开始前需要**：本地 YAML 已能正常部署，并拥有可登录的 GitHub 账号。
- **完成标志**：`git push` 后 Argo CD 自动同步，Application 显示最新提交为 `Synced`。

## 0. 开始前检查

```bash
cd ~/k8s-study
git status
kubectl get nodes
```

如果 `git status` 提示“不是 Git 仓库”，先执行：

```bash
cd ~/k8s-study
git init
git branch -M main
```

本篇涉及私有仓库和 SSH Key。任何时候都不要把私钥内容粘贴到文档、Git 或聊天中。

## 1. GitOps 的核心思想

```text
Git 中的 YAML = 期望状态（真实来源）
Kubernetes 集群 = 实际状态
Argo CD = 持续比较并同步两者
```

应用发布从手工执行：

```text
修改 YAML → kubectl apply
```

变成：

```text
修改 YAML → git commit → git push → Argo CD 自动同步
```

## 2. 准备 GitHub 私有仓库

安装 Git 和 GitHub CLI：

```bash
brew install git gh
```

检查：

```bash
git --version
gh --version
```

登录：

```bash
gh auth login
```

按终端提示选择 `GitHub.com`、`HTTPS` 和通过浏览器登录。授权完成后检查：

```bash
gh auth status
```

读取当前登录的 GitHub 用户名：

```bash
GITHUB_USER="$(gh api user --jq .login)"
echo "$GITHUB_USER"
```

后续命令使用 `$GITHUB_USER`，因此不需要把教程作者的用户名改成自己的。如果重新打开了终端，请再次执行上面两行。

准备本地 Git 仓库：

```bash
cd ~/k8s-study
git init
git branch -M main
```

创建忽略文件：

```bash
nano .gitignore
```

写入并保存：

```text
.DS_Store
web-chart/
*.tar
```

然后提交：

```bash
git add .
git commit -m "Add Kubernetes study manifests"
```

如果提示缺少 Git 用户信息，只需执行一次：

```bash
git config --global user.name "你的GitHub用户名"
git config --global user.email "你的GitHub邮箱"
```

然后重新执行 `git commit`。

在当前 GitHub 账号下创建名为 `k8s-study` 的私有仓库。仓库尚不存在时执行：

```bash
gh repo create "$GITHUB_USER/k8s-study" \
  --private \
  --source=. \
  --remote=origin \
  --push
```

仓库已经存在时不要重复创建。检查远程地址：

```bash
git remote -v
```

成功标准：看到名为 `origin` 的 GitHub 地址，并且 GitHub 网页中能看到 YAML 文件。

## 3. 安装 Argo CD

Argo CD 不一定要从 Helm 仓库安装。官方清单和 Helm Chart 都可以；本教程使用官方 YAML，步骤更直接，也方便观察它创建了哪些 Kubernetes 资源。

```bash
kubectl create namespace argocd
```

使用官方稳定清单：

```bash
kubectl apply --server-side --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

使用服务端应用的原因：Argo CD 的部分 CRD 很大，客户端 apply 可能写入超过 256 KiB 的 `last-applied-configuration` 注解。

检查：

```bash
kubectl get pods -n argocd
```

成功标准：所有 Argo CD Pod 均为 `Running` 且 `Ready`。

本次版本：Argo CD `v3.5.0`。

## 4. 访问 Argo CD 页面

```bash
kubectl port-forward service/argocd-server -n argocd 8082:443
```

访问：

```text
https://localhost:8082
```

本地使用自签名证书，浏览器可能显示安全提示。终端关闭后只会失去页面入口，不会卸载 Argo CD。

登录用户名固定为：

```text
admin
```

新开一个终端，读取初始密码：

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

把输出作为密码登录。密码属于敏感信息，不要提交到 Git 或粘贴到公开文档。

## 5. 让 Argo CD 读取私有 Git 仓库

```text
GitHub 私有仓库
  ↑ 只读 Deploy Key
Argo CD Repository Secret
  ↓
repo-server 拉取 YAML
```

Repository Secret 的标签是 Argo CD 固定协议：

```yaml
argocd.argoproj.io/secret-type: repository
```

先生成只供 Argo CD 使用的 SSH Key：

先检查是否已经存在：

```bash
ls -l "$HOME/.ssh/argocd-k8s-study" "$HOME/.ssh/argocd-k8s-study.pub"
```

如果两个文件都存在，跳过下面的 `ssh-keygen`，避免覆盖现有私钥。如果显示 `No such file or directory`，再执行：

```bash
ssh-keygen \
  -t ed25519 \
  -C "argocd-k8s-study" \
  -f "$HOME/.ssh/argocd-k8s-study" \
  -N ""
```

会生成两个文件：

```text
~/.ssh/argocd-k8s-study      私钥，不能公开
~/.ssh/argocd-k8s-study.pub  公钥，可以添加到 GitHub
```

把公钥添加为仓库的只读 Deploy Key：

先检查 GitHub 是否已经有同名 Key：

```bash
gh repo deploy-key list --repo "$GITHUB_USER/k8s-study"
```

如果已经看到 `Argo CD k8s-study`，跳过添加命令；否则执行：

```bash
gh repo deploy-key add "$HOME/.ssh/argocd-k8s-study.pub" \
  --repo "$GITHUB_USER/k8s-study" \
  --title "Argo CD k8s-study"
```

没有添加 `--allow-write`，默认就是只读。检查：

```bash
gh repo deploy-key list --repo "$GITHUB_USER/k8s-study"
```

然后创建 Argo CD Repository Secret：

```bash
kubectl create secret generic argocd-repo-k8s-study \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url="git@github.com:${GITHUB_USER}/k8s-study.git" \
  --from-file=sshPrivateKey="$HOME/.ssh/argocd-k8s-study"

kubectl label secret argocd-repo-k8s-study \
  -n argocd \
  argocd.argoproj.io/secret-type=repository
```

安全要求：

- Deploy Key 使用只读权限。
- 不在聊天、文档或 Git 中粘贴私钥内容。
- Secret YAML 中即使使用 base64，也不等于加密。

检查 Argo CD 标签：

```bash
kubectl get secret argocd-repo-k8s-study -n argocd --show-labels
```

必须看到：

```text
argocd.argoproj.io/secret-type=repository
```

## 6. Application 配置

创建 Application 文件：

```bash
nano ~/k8s-study-application.yaml
```

粘贴下面完整内容：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: k8s-study
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:YOUR_GITHUB_USERNAME/k8s-study.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: k8s-study
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
```

- `targetRevision: main`：跟踪 main 分支。
- `path: .`：读取仓库根目录。
- `destination.server`：部署到当前集群。
- `selfHeal: true`：手动修改集群后自动恢复 Git 配置。
- `prune: false`：Git 删除资源后不自动删除集群对象。

保存前，把 `YOUR_GITHUB_USERNAME` 替换为前面 `echo "$GITHUB_USER"` 输出的真实用户名。不要保留占位符。

保存后应用：

```bash
kubectl apply -f ~/k8s-study-application.yaml
```

查看状态：

```bash
kubectl get application k8s-study -n argocd
```

第一次可能先看到 `OutOfSync`，然后自动变成 `Synced`。如果两三分钟没有变化，使用第 8 节的主动刷新命令。

## 7. 理解同步状态

- `Synced`：Argo CD 当前读取的 Git 版本与集群一致。
- `OutOfSync`：Git 期望状态与集群实际状态不同。
- `Progressing`：工作负载正在启动，或健康状态尚未汇总。
- `Healthy`：资源达到健康判断标准。

`Synced` 可能只是与缓存中的旧提交一致。对比版本：

```bash
git rev-parse --short HEAD
git ls-remote origin refs/heads/main
kubectl get application k8s-study -n argocd \
  -o jsonpath='{.status.sync.revision}{"\n"}'
```

## 8. Argo CD 为什么有时同步较慢

本地 Argo CD 没有 GitHub Webhook，通常每 2～3 分钟轮询仓库一次。

立即刷新：

```bash
kubectl annotate application k8s-study \
  -n argocd \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

这只要求 Argo CD 重新读取 Git；真正部署仍由自动同步完成。

观察：

```bash
kubectl get application k8s-study -n argocd --watch
```

退出 watch 只需按 `Ctrl+C`，不会停止资源。

## 9. 完成第一次 GitOps 自动发布

编辑 ConfigMap：

```bash
cd ~/k8s-study
nano configmap.yaml
```

把页面标题改成：

```html
<h1>Updated automatically by Argo CD</h1>
```

保存后先检查修改：

```bash
git diff
```

提交并推送：

```bash
git add configmap.yaml
git commit -m "Update web content through GitOps"
git push
```

这里不要运行 `kubectl apply`。让 Argo CD 刷新：

```bash
kubectl annotate application k8s-study \
  -n argocd \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

观察：

```bash
kubectl get application k8s-study -n argocd --watch
```

看到 `Synced` 后按 `Ctrl+C`。ConfigMap Volume 更新到 Pod 可能再需要约 1～2 分钟，之后刷新网页验证内容。

再核对 Argo CD 使用的提交确实是最新版本：

```bash
git rev-parse HEAD
kubectl get application k8s-study -n argocd \
  -o jsonpath='{.status.sync.revision}{"\n"}'
```

两行提交哈希应相同。

## 10. selfHeal 自愈

当 Git 中写着：

```yaml
replicas: 2
```

手动绕过 Git 修改：

```bash
kubectl scale deployment web -n k8s-study --replicas=5
```

立即观察：

```bash
kubectl get deployment web -n k8s-study --watch
```

Argo CD 可能在 watch 启动前就已经恢复完成，因此直接看到 `2/2` 也代表自愈成功。看到最终为两个副本后按 `Ctrl+C`。

Argo CD 会检测偏差并恢复为两个副本：

```text
Git：2
  ↓
手动修改集群：5
  ↓
Argo CD selfHeal
  ↓
集群恢复：2
```

## 11. prune 删除策略

`prune: false` 时，从 Git 删除 YAML 后，Kubernetes 中的旧资源仍会保留。下面用无业务影响的 ConfigMap 验证。

创建测试文件：

```bash
cd ~/k8s-study
nano prune-demo.yaml
```

粘贴：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prune-demo
  namespace: k8s-study
data:
  message: "This resource is used to learn Argo CD prune."
```

提交并推送：

```bash
git add prune-demo.yaml
git commit -m "Add prune demo ConfigMap"
git push
```

刷新 Argo CD 后确认资源出现：

```bash
kubectl annotate application k8s-study -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
kubectl get configmaps -n k8s-study --watch
```

等待列表中出现 `prune-demo` 后按 `Ctrl+C`。如果开始时没有看到它，不是失败，表示 Argo CD 仍在同步。

然后从 Git 删除：

```bash
git rm prune-demo.yaml
git commit -m "Remove prune demo ConfigMap"
git push
kubectl annotate application k8s-study -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

等待 Argo CD 发现变化，再检查：

```bash
kubectl get application k8s-study -n argocd
kubectl get configmap prune-demo -n k8s-study
```

Application 会显示差异，但 ConfigMap 仍然存在，这就是 `prune: false`。

手动清理测试资源：

```bash
kubectl delete configmap prune-demo -n k8s-study
```

开启 `prune: true` 后，Git 中的删除可能直接删除集群资源。生产环境应结合代码审查和资源保护谨慎使用。

## 12. Argo CD 学到什么程度就够用

入门阶段掌握以下内容已经足够：

- Repository 连接。
- Application 配置。
- 自动同步。
- `Synced` / `OutOfSync`。
- `selfHeal` 和 `prune`。
- Git 版本与集群版本核对。

ApplicationSet、SSO、复杂 RBAC、Sync Wave、通知和高可用可以等真实需求出现后再学。

## 13. 本篇完成标准

- 能用 Git 代替手动 apply 发布配置。
- 能解释 Argo CD 同步状态。
- 能判断 Argo CD 是否读取了最新 Git 提交。
- 理解 selfHeal 和 prune 的风险边界。

[上一篇：Helm、Traefik 与 Ingress](./04-Helm-Traefik与Ingress.md) | [下一篇：PVC、PV 与持久化存储](./06-PVC-PV与持久化存储.md)
