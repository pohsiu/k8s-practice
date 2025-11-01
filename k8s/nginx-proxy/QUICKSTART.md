# 快速參考

## ⚡ 一鍵部署

```bash
./scripts/deploy-nginx-proxy.sh
```

## 🧪 測試命令

```bash
# PR 1
curl -H "x-multi-env: pr-dev-1" http://192.168.49.2.nip.io/

# PR 2
curl -H "x-multi-env: pr-dev-2" http://192.168.49.2.nip.io/

# Default
curl http://192.168.49.2.nip.io/
```

## ➕ 添加新 PR（3 步驟）

```bash
# 1. 生成配置
PR_BRANCH="pr-dev-3"
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/nginx-proxy/pr-template.yml > k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 2. 應用
kubectl apply -f k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 3. 更新 deployment.yml（手動編輯添加 volume 和 volumeMount）
kubectl apply -f k8s/nginx-proxy/deployment.yml
```

## 🗑️ 刪除 PR

```bash
PR_BRANCH="pr-dev-3"
kubectl delete configmap nginx-proxy-$PR_BRANCH-config
# 然後從 deployment.yml 移除對應條目並 apply
```

## 🔍 常用檢查命令

```bash
# 查看所有 PR ConfigMaps
kubectl get configmap -l app=nginx-proxy

# 查看 Pod 狀態
kubectl get pods -l app=nginx-proxy

# 查看日誌
kubectl logs -f -l app=nginx-proxy

# 進入 Pod
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- sh

# 查看掛載的配置
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- ls /etc/nginx/conf.d/upstreams/
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- ls /etc/nginx/conf.d/routes/

# 測試 nginx 配置
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- nginx -t
```

## 🔄 更新配置

```bash
# 修改 ConfigMap
kubectl edit configmap nginx-proxy-pr-dev-1-config

# 重啟生效
kubectl rollout restart deployment/nginx-proxy
```

## 📚 文檔導航

- 📖 [README.md](./README.md) - 完整說明
- 📘 [USAGE.md](./USAGE.md) - 詳細指南
- 📄 [FILES.md](./FILES.md) - 文件說明
- ⚡ [QUICKSTART.md](./QUICKSTART.md) - 本文件

## ❓ 故障排除

**404 錯誤**:
```bash
# 檢查 Service
kubectl get svc | grep express-app
# 檢查 ConfigMap
kubectl get configmap -l app=nginx-proxy
```

**Nginx 無法啟動**:
```bash
# 查看日誌
kubectl logs -l app=nginx-proxy --tail=50
```

**配置未生效**:
```bash
# 重啟 Pod
kubectl rollout restart deployment/nginx-proxy
```

