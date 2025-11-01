# Express App Helm Chart

這個 Helm chart 支持多 PR 環境部署，每個 PR branch 可以擁有自己的 deployment、service 和 ingress，並通過 header 路由進行流量分配。

## 功能特點

- ✅ 支持 default 環境部署
- ✅ 支持多個 PR branch 同時部署
- ✅ 每個 PR 擁有獨立的 ingress，通過 `x-multi-env` header 路由
- ✅ 使用 Nginx Ingress Controller 的 canary 功能進行 header-based routing
- ✅ 靈活的配置管理

## Chart 結構

```
helm/express-app/
├── Chart.yaml              # Chart 元數據
├── values.yaml             # 默認配置值
├── values-minikube.yaml    # Minikube 環境配置
└── templates/
    ├── _helpers.tpl        # 模板輔助函數
    ├── deployment.yaml     # Deployment 模板（支持 default 和多 PR）
    ├── service.yaml        # Service 模板（支持 default 和多 PR）
    └── ingress.yaml        # Ingress 模板（支持 default 和多 PR）
```

## 快速開始

### 1. 部署 Default 環境

```bash
# 使用默認配置
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  --create-namespace \
  -f helm/express-app/values-minikube.yaml

# 自定義 host
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  --set global.host=192.168.49.2.nip.io
```

### 2. 部署 PR Branch

#### 方法一：使用命令行參數

```bash
# 部署單個 PR branch
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  -f helm/express-app/values-minikube.yaml \
  --set prBranches.pr-dev-1.enabled=true \
  --set prBranches.pr-dev-1.image.tag=pr-dev-1 \
  --set global.host=$(minikube ip).nip.io
```

#### 方法二：使用 values 文件

編輯 `values-minikube.yaml` 或創建新的 values 文件：

```yaml
global:
  host: 192.168.49.2.nip.io

prBranches:
  pr-dev-1:
    enabled: true
    image:
      repository: express-app
      tag: pr-dev-1
    replicaCount: 1
    service:
      type: ClusterIP
  pr-dev-2:
    enabled: true
    image:
      repository: express-app
      tag: pr-dev-2
    replicaCount: 1
```

然後部署：

```bash
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  -f helm/express-app/values-minikube.yaml
```

#### 方法三：使用腳本

```bash
chmod +x scripts/deploy-pr-with-helm.sh
./scripts/deploy-pr-with-helm.sh pr-dev-1
```

### 3. 測試部署

```bash
# 測試 default 服務（無 header）
curl http://$(minikube ip).nip.io/

# 測試 PR branch（帶 header）
curl -H "x-multi-env: pr-dev-1" http://$(minikube ip).nip.io/

# 測試多個 PR
curl -H "x-multi-env: pr-dev-2" http://$(minikube ip).nip.io/
```

## 配置說明

### Default 環境配置

```yaml
default:
  enabled: true
  image:
    repository: express-app
    tag: latest
    pullPolicy: IfNotPresent
  replicaCount: 1
  service:
    type: NodePort  # 或 ClusterIP
    port: 80
    targetPort: 3000
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
```

### PR Branch 配置

```yaml
prBranches:
  pr-dev-1:
    enabled: true
    image:
      repository: express-app
      tag: pr-dev-1
    replicaCount: 1
    service:
      type: ClusterIP
    # 資源配置會繼承 default 的配置，除非明確覆蓋
```

## 工作原理

### Default Ingress
- 沒有使用 canary 註解
- 當沒有匹配的 PR header 時，流量會路由到 default service

### PR Ingress
- 使用 Nginx Ingress Controller 的 canary 功能
- 註解設置：
  - `nginx.ingress.kubernetes.io/canary: "true"`
  - `nginx.ingress.kubernetes.io/canary-by-header: "x-multi-env"`
  - `nginx.ingress.kubernetes.io/canary-by-header-value: "<pr-branch-name>"`
- 當請求帶有 `x-multi-env: <pr-branch-name>` header 時，流量路由到對應的 PR service

### 流量路由邏輯

1. 請求帶有 `x-multi-env: pr-dev-1` header
   - → 匹配 `pr-dev-1` ingress
   - → 路由到 `express-app-pr-dev-1` service
   - → 轉發到 `pr-dev-1` deployment 的 pods

2. 請求沒有 header 或不匹配任何 PR
   - → 路由到 default ingress
   - → 路由到 `express-app-default` service
   - → 轉發到 default deployment 的 pods

## 管理多個 PR

### 添加新 PR

```bash
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  -f helm/express-app/values-minikube.yaml \
  --set prBranches.pr-dev-3.enabled=true \
  --set prBranches.pr-dev-3.image.tag=pr-dev-3
```

### 禁用 PR

```bash
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  -f helm/express-app/values-minikube.yaml \
  --set prBranches.pr-dev-1.enabled=false
```

### 查看已部署的 PR

```bash
# 查看所有 ingress
kubectl get ingress -l app=express-app

# 查看所有 service
kubectl get svc -l app=express-app

# 查看所有 deployment
kubectl get deployment -l app=express-app

# 查看 PR pods
kubectl get pods -l branch
```

### 刪除特定 PR

```bash
# 禁用 PR
helm upgrade --install express-app ./helm/express-app \
  --namespace default \
  -f helm/express-app/values-minikube.yaml \
  --set prBranches.pr-dev-1.enabled=false

# 或者手動刪除資源
kubectl delete ingress express-app-pr-dev-1
kubectl delete service express-app-pr-dev-1
kubectl delete deployment express-app-pr-dev-1
```

## 常用命令

```bash
# 查看 Helm release
helm list

# 查看 release 的配置
helm get values express-app

# 查看生成的 manifests（不部署）
helm template express-app ./helm/express-app -f helm/express-app/values-minikube.yaml

# 卸載 release
helm uninstall express-app

# 升級 release
helm upgrade express-app ./helm/express-app \
  --namespace default \
  -f helm/express-app/values-minikube.yaml
```

## 與 GitHub Actions 集成

GitHub Actions workflow 已經更新為使用 Helm 進行部署。參考 `.github/workflows/deploy.yaml`。

## 注意事項

1. **Ingress Host**: 所有 ingress（default 和 PR）必須使用相同的 host，canary routing 才能正常工作
2. **Image Tags**: 確保 PR branch 的 Docker image 已構建並標記正確
3. **資源清理**: 當 PR 合併後，記得禁用或刪除對應的 PR branch 資源以節省資源

