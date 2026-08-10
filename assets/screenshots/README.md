# 关键截图说明

本目录只保留能够证明关键学习结果的截图，不为每条命令重复截图。命令、错误文字和
预期输出仍以 Markdown 正文为准，方便复制和搜索。

## 截图清单

| 文件 | 内容 | 状态 | 使用位置 |
|---|---|---|---|
| `01-cluster-ready.png` | Kind 节点与 Deployment 正常 | 已完成 | 第 2 篇 |
| `02-gitops-storage.png` | Argo CD Synced 与 PVC Bound | 已完成 | 第 5、6 篇 |
| `03-configmap-page.jpg` | ConfigMap 提供的 Nginx 页面 | 已完成 | 第 3 篇 |
| `04-custom-image-v2.jpg` | 自建镜像 v2 页面 | 已完成 | 第 7 篇 |
| `05-argocd-resource-tree.jpg` | Argo CD Application 分组资源树 | 已完成 | 第 5 篇 |

## 截图统一要求

- 终端统一使用 iTerm2。
- 截图前新开一个窗口，避免包含历史命令和无关标签页。
- 建议窗口内容区域约为 `1280 × 720`，字体保持清晰可读。
- 只截终端内容，不包含桌面、Dock、其他应用或通知。
- 不显示密码、Token、私钥、kubeconfig、私人仓库地址和真实生产 IP。
- 终端用户名和本机主机名只在本人明确同意时保留；本仓库的截图已获得同意。
- 终端截图优先保存 PNG，网页截图可以保存 JPEG。
- Argo CD 等管理界面截图不应包含 Git 提交者的真实邮箱。
- 动态 Pod 名、IP、年龄和提交哈希可以保留，它们用于说明真实环境，但正文不能依赖这些固定值。

## 01：集群与 Deployment

在新的 iTerm2 窗口执行：

```bash
export PS1='$ '
clear
kubectl get nodes
printf '\n'
kubectl get deployments -n k8s-study
```

成功截图必须同时看到：

- `study-control-plane` 为 `Ready`。
- 主要 Deployment 的 `READY` 与期望副本数一致。
- 不包含密码、Token、私钥等敏感信息。

使用 macOS `Shift + Command + 4` 框选终端内容，保存为：

```text
01-cluster-ready.png
```

## 02：GitOps 与持久化

继续在干净的 iTerm2 窗口执行：

```bash
clear
kubectl get application k8s-study -n argocd \
  -o 'custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,REVISION:.status.sync.revision'
printf '\n'
kubectl get pvc storage-demo -n k8s-study
```

成功截图必须同时看到：

- Application 的 `SYNC` 为 `Synced`。
- `storage-demo` 的 `STATUS` 为 `Bound`。
- 提交哈希可以显示，但不能出现仓库凭据。

保存为：

```text
02-gitops-storage.png
```

截图已由维护者检查并嵌入对应篇章。更新截图时，仍需重新检查敏感信息。

[返回教程目录](../../README.md)
