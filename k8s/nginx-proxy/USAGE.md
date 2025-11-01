# 詳細使用指南

## PR ConfigMap 詳細說明

### ConfigMap 結構

每個 PR 的 ConfigMap 包含兩個配置文件：

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

### 掛載方式

這些配置通過 Volume Mount 掛載到 nginx 容器：

```
ConfigMap: nginx-proxy-pr-dev-1-config
├── upstream.conf → /etc/nginx/conf.d/upstreams/pr-dev-1.conf
└── route.conf → /etc/nginx/conf.d/routes/pr-dev-1.conf
```

Nginx 主配置中使用 `include` 指令載入這些文件：

```nginx
http {
  # 載入所有 upstream 定義
  include /etc/nginx/conf.d/upstreams/*.conf;
  
  server {
    location / {
      # 載入所有路由規則
      include /etc/nginx/conf.d/routes/*.conf;
    }
  }
}
```

## 添加新 PR 的完整流程

### 步驟 1：確認前置條件

```bash
# 確認後端 Service 存在
kubectl get svc express-app-pr-dev-3

# 確認 Service endpoints 正常
kubectl get endpoints express-app-pr-dev-3
```

### 步驟 2：生成 ConfigMap

```bash
PR_BRANCH="pr-dev-3"

# 從模板生成
sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/nginx-proxy/pr-template.yml > k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 或手動創建
kubectl create configmap nginx-proxy-$PR_BRANCH-config \
  --from-literal=upstream.conf="upstream $PR_BRANCH {
  server express-app-$PR_BRANCH:80;
}" \
  --from-literal=route.conf="if (\$http_x_multi_env = \"$PR_BRANCH\") {
  set \$upstream \"$PR_BRANCH\";
}"
```

### 步驟 3：應用 ConfigMap

```bash
kubectl apply -f k8s/nginx-proxy/pr-$PR_BRANCH-config.yml

# 驗證
kubectl get configmap nginx-proxy-$PR_BRANCH-config -o yaml
```

### 步驟 4：更新 Deployment

編輯 `k8s/nginx-proxy/deployment.yml`：

```yaml
# 在 spec.template.spec.volumes 部分添加
- name: pr-dev-3-config
  configMap:
    name: nginx-proxy-pr-dev-3-config
    optional: true

# 在 spec.template.spec.containers[0].volumeMounts 部分添加
- name: pr-dev-3-config
  mountPath: /etc/nginx/conf.d/upstreams/pr-dev-3.conf
  subPath: upstream.conf
- name: pr-dev-3-config
  mountPath: /etc/nginx/conf.d/routes/pr-dev-3.conf
  subPath: route.conf
```

### 步驟 5：應用更新

```bash
kubectl apply -f k8s/nginx-proxy/deployment.yml

# 等待 rollout 完成
kubectl rollout status deployment/nginx-proxy
```

### 步驟 6：驗證

```bash
# 檢查 Pod 狀態
kubectl get pods -l app=nginx-proxy

# 驗證配置文件已掛載
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- ls -la /etc/nginx/conf.d/upstreams/
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- ls -la /etc/nginx/conf.d/routes/

# 檢查配置內容
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- cat /etc/nginx/conf.d/upstreams/pr-dev-3.conf

# 測試 nginx 配置
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- nginx -t
```

### 步驟 7：測試

```bash
# 測試路由
curl -H "x-multi-env: pr-dev-3" http://192.168.49.2.nip.io/

# 測試健康檢查
curl http://192.168.49.2.nip.io/nginx-health
```

## 刪除 PR 的完整流程

### 步驟 1：刪除 ConfigMap

```bash
PR_BRANCH="pr-dev-3"
kubectl delete configmap nginx-proxy-$PR_BRANCH-config
```

### 步驟 2：更新 Deployment

從 `k8s/nginx-proxy/deployment.yml` 中移除對應的：
- `volumes` 條目
- `volumeMounts` 條目

### 步驟 3：應用更新

```bash
kubectl apply -f k8s/nginx-proxy/deployment.yml
kubectl rollout status deployment/nginx-proxy
```

### 步驟 4：清理配置文件

```bash
rm k8s/nginx-proxy/pr-$PR_BRANCH-config.yml
```

## 進階配置

### 自定義 Upstream 配置

可以在 ConfigMap 的 `upstream.conf` 中添加更多配置：

```nginx
upstream pr-dev-3 {
  server express-app-pr-dev-3:80;
  
  # 健康檢查
  # keepalive 32;
  
  # 負載均衡（如果有多個實例）
  # server express-app-pr-dev-3-2:80;
  # least_conn;
}
```

### 自定義路由規則

可以添加更複雜的路由邏輯：

```nginx
# 基於多個條件路由
if ($http_x_multi_env = "pr-dev-3") {
  set $upstream "pr-dev-3";
}

# 也可以基於其他 header
# if ($http_x_custom_header = "value") {
#   set $upstream "pr-dev-3";
# }
```

### 添加更多 Location 塊

如果需要特定路徑的配置，可以在主配置中添加：

```nginx
location /api {
  # API 專用配置
  include /etc/nginx/conf.d/routes/*.conf;
  proxy_pass http://$upstream;
}

location /static {
  # 靜態文件配置
  root /var/www;
}
```

## CI/CD 整合

### GitHub Actions 示例

```yaml
name: Deploy PR Environment

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Generate PR ConfigMap
        run: |
          PR_BRANCH="pr-dev-${{ github.event.pull_request.number }}"
          sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/nginx-proxy/pr-template.yml > /tmp/pr-config.yml
          kubectl apply -f /tmp/pr-config.yml
      
      - name: Update Nginx Proxy
        run: |
          # 可以使用 kubectl patch 動態添加 volume
          kubectl rollout restart deployment/nginx-proxy
```

### GitLab CI 示例

```yaml
deploy_pr:
  stage: deploy
  script:
    - PR_BRANCH="pr-dev-${CI_MERGE_REQUEST_IID}"
    - sed "s/{{PR_BRANCH}}/$PR_BRANCH/g" k8s/nginx-proxy/pr-template.yml | kubectl apply -f -
    - kubectl rollout restart deployment/nginx-proxy
  only:
    - merge_requests
```

## 監控和日誌

### 查看訪問日誌

```bash
# 實時查看訪問日誌
kubectl logs -f -l app=nginx-proxy

# 過濾特定 PR 的請求
kubectl logs -l app=nginx-proxy | grep "pr-dev-1"
```

### 監控 Upstream 健康

```bash
# 進入 Pod 查看 nginx status
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- cat /var/log/nginx/access.log

# 檢查連接狀態
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- netstat -an | grep 80
```

## 性能優化

### 增加副本數

```bash
kubectl scale deployment nginx-proxy --replicas=3
```

### 資源限制調整

編輯 `deployment.yml`：

```yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 啟用連接保持

在 upstream 配置中：

```nginx
upstream pr-dev-3 {
  server express-app-pr-dev-3:80;
  keepalive 32;
  keepalive_requests 100;
  keepalive_timeout 60s;
}
```

## 故障排除技巧

### 調試模式

啟用 nginx 調試日誌：

```nginx
error_log /var/log/nginx/error.log debug;
```

### 配置驗證

```bash
# 進入容器
kubectl exec -it $(kubectl get pod -l app=nginx-proxy -o name) -- sh

# 查看實際載入的配置
nginx -T

# 測試配置
nginx -t

# 查看 include 路徑下的文件
ls -la /etc/nginx/conf.d/upstreams/
ls -la /etc/nginx/conf.d/routes/
```

### 常見錯誤

**錯誤**: `host not found in upstream`
- **原因**: Service 不存在或無法解析
- **解決**: 檢查 Service 是否存在並有 endpoints

**錯誤**: `no such file or directory`
- **原因**: ConfigMap 未正確掛載
- **解決**: 檢查 volume 和 volumeMount 配置

**錯誤**: `duplicate upstream`
- **原因**: 重複的 upstream 定義
- **解決**: 檢查是否有重複的 ConfigMap

## 最佳實踐

1. **命名規範**: 統一使用 `pr-dev-{number}` 格式
2. **標籤管理**: 為所有 PR ConfigMap 添加 `pr-branch` 標籤
3. **版本控制**: 將生成的 ConfigMap 文件提交到 git
4. **自動清理**: PR 關閉後自動刪除對應的 ConfigMap
5. **健康檢查**: 確保添加的 service 健康後再啟用路由
6. **文檔更新**: 添加新 PR 時更新相關文檔

---

更多信息請參考 [README.md](./README.md)

