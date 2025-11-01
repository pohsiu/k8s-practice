# Nginx Reverse Proxy for Multi-PR Routing

自建 nginx 反向代理，實現基於 HTTP header 的多 PR 部署流量路由。

## 📖 目錄

- [快速開始](#快速開始)
- [架構說明](#架構說明)
- [配置文件](#配置文件)
- [使用方式](#使用方式)
- [添加新 PR](#添加新-pr)
- [維護管理](#維護管理)
- [故障排除](#故障排除)
- [相關文檔](#相關文檔)

## 🚀 快速開始

> ⚠️ **重要**: 必須先部署後端服務，再部署 Nginx Proxy！詳見 [部署順序指南](./DEPLOYMENT-ORDER.md)

### 1. 部署後端服務（如果還未部署）

```bash
# 部署 default 服務
./scripts/deploy-default-to-minikube.sh

# 部署 PR 服務
./scripts/deploy-to-minikube.sh pr-dev-1
./scripts/deploy-to-minikube.sh pr-dev-2
```

### 2. 部署 Nginx Proxy

```bash
./scripts/deploy-nginx-proxy.sh
```

腳本會自動檢查前置條件，如果後端服務不存在會給出警告。

### 3. 測試

```bash
# 測試 pr-dev-1
curl -H "x-multi-env: pr-dev-1" http://192.168.49.2.nip.io/

# 測試 pr-dev-2
curl -H "x-multi-env: pr-dev-2" http://192.168.49.2.nip.io/

# 測試 default (無 header)
curl http://192.168.49.2.nip.io/
```

## 🏗️ 架構說明

### 請求流程

```
Client Request (with x-multi-env header)
    ↓
Nginx Ingress Controller
    ↓
Custom Nginx Proxy Service
    ↓ (根據 header 路由)
    ├─ pr-dev-1 → express-app-pr-dev-1
    ├─ pr-dev-2 → express-app-pr-dev-2
    └─ default  → express-app-default
```

### 配置結構

```
nginx.conf (主配置)
├── include /etc/nginx/conf.d/upstreams/*.conf
│   ├── pr-dev-1.conf (upstream 定義)
│   └── pr-dev-2.conf (upstream 定義)
│
└── include /etc/nginx/conf.d/routes/*.conf
    ├── pr-dev-1.conf (路由規則)
    └── pr-dev-2.conf (路由規則)
```

**核心概念**：使用 nginx `include` 指令 + Kubernetes ConfigMap Volume Mount 實現動態配置載入。

## 📁 配置文件

### 核心配置

| 文件 | 說明 |
|------|------|
| `configmap.yml` | Nginx 主配置（含 include 指令）|
| `deployment.yml` | Nginx Proxy 部署配置 |
| `service.yml` | Service 定義 (NodePort) |
| `ingress.yml` | Ingress 路由配置 |

### PR 配置

| 文件 | 說明 |
|------|------|
| `pr-template.yml` | PR ConfigMap 模板 |
| `pr-dev-1-config.yml` | PR 1 配置示例 |
| `pr-dev-2-config.yml` | PR 2 配置示例 |

### 文檔

| 文件 | 說明 |
|------|------|
| `README.md` | 本文件 |
| `USAGE.md` | 詳細使用指南 |

## 🔧 使用方式

### PR ConfigMap 結構

每個 PR 需要創建一個 ConfigMap，包含兩個配置文件：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-proxy-{{PR_BRANCH}}-config
  labels:
    app: nginx-proxy
    pr-branch: {{PR_BRANCH}}
data:
  # Upstream 定義
  upstream.conf: |
    upstream {{PR_BRANCH}} {
      server express-app-{{PR_BRANCH}}:80;
    }
  
  # 路由規則
  route.conf: |
    if ($http_x_multi_env = "{{PR_BRANCH}}") {
      set $upstream "{{PR_BRANCH}}";
    }
```

### Volume Mount 配置

在 `deployment.yml` 中需要添加：

```yaml
volumes:
- name: pr-dev-X-config
  configMap:
    name: nginx-proxy-pr-dev-X-config
    optional: true

volumeMounts:
- name: pr-dev-X-config
  mountPath: /etc/nginx/conf.d/upstreams/pr-dev-X.conf
  subPath: upstream.conf
- name: pr-dev-X-config
  mountPath: /etc/nginx/conf.d/routes/pr-dev-X.conf
  subPath: route.conf
```

## ➕ 添加新 PR

### 方法 1：使用模板（推薦）

```bash
# 1. 生成 ConfigMap
PR_BRANCH="pr-dev-3"
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/nginx-proxy/pr-template.yml > k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 2. 應用 ConfigMap
kubectl apply -f k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 3. 編輯 deployment.yml 添加 volume 和 volumeMount
# （參考上面的配置示例）

# 4. 應用更新
kubectl apply -f k8s/nginx-proxy/deployment.yml
```

### 方法 2：使用腳本

```bash
# 注意：此腳本會創建 ConfigMap，但仍需手動更新 deployment
./scripts/add-pr-to-nginx-proxy.sh pr-dev-3
```

### 前置條件

⚠️ **重要**：添加新 PR 前，請確保：
1. 後端 Service 已存在：`kubectl get svc express-app-pr-dev-X`
2. Service 健康且可訪問
3. 使用正確的 branch 命名

## 🛠️ 維護管理

### 查看配置

```bash
# 查看所有 PR ConfigMaps
kubectl get configmap -l app=nginx-proxy

# 查看特定 ConfigMap
kubectl get configmap nginx-proxy-pr-dev-1-config -o yaml

# 進入 Pod 查看掛載的配置
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- sh
ls /etc/nginx/conf.d/upstreams/
ls /etc/nginx/conf.d/routes/

# 測試 nginx 配置
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- nginx -t
```

### 更新配置

```bash
# 修改 ConfigMap
kubectl edit configmap nginx-proxy-pr-dev-1-config

# 重啟 nginx proxy 重新載入配置
kubectl rollout restart deployment/nginx-proxy
```

### 刪除 PR

```bash
PR_BRANCH="pr-dev-3"

# 1. 刪除 ConfigMap
kubectl delete configmap nginx-proxy-$PR_BRANCH-config

# 2. 從 deployment.yml 移除對應的 volume 和 volumeMount
# 3. 應用更新
kubectl apply -f k8s/nginx-proxy/deployment.yml

# 4. 刪除配置文件
rm k8s/nginx-proxy/pr-$PR_BRANCH-config.yml
```

### 查看日誌

```bash
# 查看實時日誌
kubectl logs -f -l app=nginx-proxy

# 查看最近的錯誤
kubectl logs -l app=nginx-proxy --tail=50 | grep error
```

## 🔍 故障排除

### 問題：404 Not Found

**可能原因**：
1. 後端 Service 不存在
2. Header 值不正確
3. ConfigMap 未正確掛載

**解決方法**：
```bash
# 檢查 Service
kubectl get svc | grep express-app

# 檢查 ConfigMap
kubectl get configmap -l app=nginx-proxy

# 進入 Pod 驗證配置
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- cat /etc/nginx/conf.d/upstreams/pr-dev-1.conf
```

### 問題：Nginx 啟動失敗

**可能原因**：
- Upstream service 不存在（DNS 解析失敗）
- 配置語法錯誤

**解決方法**：
```bash
# 查看 Pod 日誌
kubectl logs -l app=nginx-proxy --tail=50

# 檢查配置語法
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- nginx -t
```

### 問題：ConfigMap 更新未生效

**解決方法**：
```bash
# ConfigMap 更新後需要重啟 Pod
kubectl rollout restart deployment/nginx-proxy
kubectl rollout status deployment/nginx-proxy
```

## 🎯 優勢

✅ **完全控制** - 不受 nginx ingress controller 的 snippet 限制  
✅ **動態配置** - 使用 ConfigMap + include 指令  
✅ **獨立管理** - 每個 PR 有獨立的 ConfigMap  
✅ **易於擴展** - 使用模板快速生成新 PR 配置  
✅ **標準化** - 純 nginx 配置，無特殊依賴  
✅ **可追蹤** - 所有配置都是 Kubernetes 資源  

## 📚 相關文檔

- **[DEPLOYMENT-ORDER.md](./DEPLOYMENT-ORDER.md)** - 部署順序指南（必讀！）⭐
- **[QUICKSTART.md](./QUICKSTART.md)** - 快速參考指令
- **[USAGE.md](./USAGE.md)** - 詳細使用指南和進階配置
- **[FILES.md](./FILES.md)** - 文件結構說明
- [Nginx Include 指令文檔](http://nginx.org/en/docs/ngx_core_module.html#include)
- [Kubernetes ConfigMap 文檔](https://kubernetes.io/docs/concepts/configuration/configmap/)

## 🤝 貢獻

如需改進或有建議，請：
1. 遵循現有的命名規範
2. 更新相關文檔
3. 測試配置變更

---

**維護者**: DevOps Team  
**更新時間**: 2025-11-01  
**版本**: 1.0

