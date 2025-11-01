# 部署順序指南

## 📋 正確的部署順序

### ⚠️ 重要提醒

**必須先部署後端服務，再部署 Nginx Proxy！**

Nginx 在啟動時會驗證所有 upstream 的主機名。如果後端服務不存在，Nginx 將無法啟動。

## 🚀 完整部署流程

### 步驟 1: 確認 Minikube 運行

```bash
# 檢查 minikube 狀態
minikube status

# 如果未運行，啟動它
minikube start

# 獲取 minikube IP
minikube ip
```

### 步驟 2: 部署後端服務

#### 2.1 部署 Default 服務

```bash
# 使用腳本部署
./scripts/deploy-default-to-minikube.sh

# 驗證
kubectl get deployment express-app-default
kubectl get svc express-app-default
```

#### 2.2 部署 PR 服務

```bash
# 部署 PR 1
./scripts/deploy-to-minikube.sh pr-dev-1

# 部署 PR 2
./scripts/deploy-to-minikube.sh pr-dev-2

# 驗證所有服務
kubectl get svc | grep express-app
```

**預期輸出**:
```
express-app-default         NodePort    10.101.42.204    <none>        80:31963/TCP
express-app-pr-dev-1        ClusterIP   10.103.211.142   <none>        80/TCP
express-app-pr-dev-2        ClusterIP   10.99.40.175     <none>        80/TCP
```

### 步驟 3: 部署 Nginx Proxy

```bash
# 使用腳本部署（會自動檢查前置條件）
./scripts/deploy-nginx-proxy.sh

# 如果想跳過檢查（不推薦）
./scripts/deploy-nginx-proxy.sh --skip-checks
```

### 步驟 4: 驗證部署

```bash
# 檢查 nginx proxy 狀態
kubectl get pods -l app=nginx-proxy
kubectl get svc nginx-proxy
kubectl get ingress nginx-proxy-ingress

# 測試健康檢查
MINIKUBE_IP=$(minikube ip)
curl http://$MINIKUBE_IP.nip.io/nginx-health

# 測試路由
curl -H "x-multi-env: pr-dev-1" http://$MINIKUBE_IP.nip.io/
curl -H "x-multi-env: pr-dev-2" http://$MINIKUBE_IP.nip.io/
curl http://$MINIKUBE_IP.nip.io/
```

## 🔄 添加新 PR 的流程

### 情境 1: 從零開始

```bash
# 1. 部署後端服務
./scripts/deploy-to-minikube.sh pr-dev-3

# 2. 生成 nginx proxy 配置
PR_BRANCH="pr-dev-3"
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/nginx-proxy/pr-template.yml > k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 3. 應用配置
kubectl apply -f k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 4. 更新 deployment.yml（手動編輯添加 volume 和 volumeMount）
# 編輯 k8s/nginx-proxy/deployment.yml

# 5. 應用更新
kubectl apply -f k8s/nginx-proxy/deployment.yml

# 6. 測試
curl -H "x-multi-env: pr-dev-3" http://$(minikube ip).nip.io/
```

### 情境 2: Nginx Proxy 已部署

如果 nginx proxy 已經在運行，添加新 PR：

```bash
# 1. 先部署後端服務
./scripts/deploy-to-minikube.sh pr-dev-3

# 2. 使用腳本添加配置
./scripts/add-pr-to-nginx-proxy.sh pr-dev-3

# 注意：腳本會創建 ConfigMap，但你仍需手動更新 deployment.yml
```

## 🔍 前置條件檢查清單

在部署 Nginx Proxy 之前，確保：

### ✅ 基礎設施
- [ ] Minikube 正在運行
- [ ] kubectl 可以連接到集群
- [ ] Nginx Ingress Controller 已安裝

```bash
# 檢查 minikube
minikube status

# 檢查 kubectl
kubectl cluster-info

# 檢查 ingress controller
kubectl get pods -n ingress-nginx
```

### ✅ 後端服務
- [ ] express-app-default 服務存在
- [ ] 所有需要的 PR 服務存在
- [ ] 服務有健康的 endpoints

```bash
# 檢查服務
kubectl get svc | grep express-app

# 檢查 endpoints
kubectl get endpoints | grep express-app

# 檢查 Pod 狀態
kubectl get pods | grep express-app
```

### ✅ ConfigMap 準備
- [ ] 主 ConfigMap (configmap.yml) 已準備
- [ ] PR ConfigMaps 已生成

```bash
# 檢查現有 ConfigMaps
kubectl get configmap -l app=nginx-proxy

# 列出本地 PR 配置文件
ls k8s/nginx-proxy/pr-dev-*-config.yml
```

## ❌ 常見錯誤與解決

### 錯誤 1: Nginx Pod CrashLoopBackOff

**原因**: Upstream service 不存在

**錯誤日誌**:
```
nginx: [emerg] host not found in upstream "express-app-pr-dev-3:80"
```

**解決**:
```bash
# 檢查服務是否存在
kubectl get svc express-app-pr-dev-3

# 如果不存在，先部署後端服務
./scripts/deploy-to-minikube.sh pr-dev-3

# 刪除失敗的 ConfigMap
kubectl delete configmap nginx-proxy-pr-dev-3-config

# 重新部署
kubectl rollout restart deployment/nginx-proxy
```

### 錯誤 2: ConfigMap 更新未生效

**原因**: ConfigMap 掛載需要 Pod 重啟

**解決**:
```bash
# 重啟 nginx proxy
kubectl rollout restart deployment/nginx-proxy

# 等待完成
kubectl rollout status deployment/nginx-proxy
```

### 錯誤 3: 404 Not Found

**原因**: 路由配置問題或服務未正確配置

**檢查**:
```bash
# 進入 Pod 檢查配置
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- sh

# 查看 upstreams
ls /etc/nginx/conf.d/upstreams/

# 查看 routes
ls /etc/nginx/conf.d/routes/

# 測試 nginx 配置
nginx -t

# 查看日誌
exit
kubectl logs -l app=nginx-proxy --tail=50
```

## 📊 部署後驗證清單

### ✅ 資源狀態
```bash
# 所有 Pod 應該是 Running
kubectl get pods -l app=nginx-proxy
kubectl get pods | grep express-app

# 所有 Service 應該有 CLUSTER-IP
kubectl get svc | grep -E "(nginx-proxy|express-app)"

# Ingress 應該有 ADDRESS
kubectl get ingress nginx-proxy-ingress
```

### ✅ 配置驗證
```bash
# ConfigMaps 已創建
kubectl get configmap -l app=nginx-proxy

# 配置文件已掛載
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- ls -la /etc/nginx/conf.d/upstreams/
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- ls -la /etc/nginx/conf.d/routes/
```

### ✅ 功能測試
```bash
MINIKUBE_IP=$(minikube ip)

# 健康檢查應返回 "healthy"
curl http://$MINIKUBE_IP.nip.io/nginx-health

# PR 路由應返回對應的服務響應
curl -H "x-multi-env: pr-dev-1" http://$MINIKUBE_IP.nip.io/
curl -H "x-multi-env: pr-dev-2" http://$MINIKUBE_IP.nip.io/

# Default 路由應返回 default 服務響應
curl http://$MINIKUBE_IP.nip.io/
```

## 🔄 重新部署流程

如果需要完全重新部署：

```bash
# 1. 刪除 nginx proxy
kubectl delete -f k8s/nginx-proxy/ingress.yml
kubectl delete -f k8s/nginx-proxy/service.yml
kubectl delete -f k8s/nginx-proxy/deployment.yml
kubectl delete -f k8s/nginx-proxy/configmap.yml

# 2. 刪除 PR ConfigMaps
kubectl delete configmap -l app=nginx-proxy

# 3. 確認後端服務仍在運行
kubectl get svc | grep express-app

# 4. 重新部署
./scripts/deploy-nginx-proxy.sh
```

## 💡 最佳實踐

1. **總是先部署後端服務**
2. **使用部署腳本**（包含前置檢查）
3. **逐步添加 PR**（不要一次添加太多）
4. **測試每個步驟**（確認每步成功再繼續）
5. **保留日誌**（出問題時方便追查）
6. **文檔化特殊配置**（記錄非標準配置）

---

**相關文檔**:
- [README.md](./README.md) - 主文檔
- [QUICKSTART.md](./QUICKSTART.md) - 快速參考
- [USAGE.md](./USAGE.md) - 詳細指南

