# 文件說明

## 📁 目錄結構

```
k8s/nginx-proxy/
├── README.md                  # 主文檔（快速開始、架構說明）
├── DEPLOYMENT-ORDER.md        # 部署順序指南 ⭐ 必讀
├── QUICKSTART.md              # 快速參考指令
├── USAGE.md                   # 詳細使用指南（完整流程、進階配置）
├── FILES.md                   # 本文件（文件說明）
│
├── configmap.yml              # Nginx 主配置（含 include 指令）
├── deployment.yml             # Nginx Proxy Deployment
├── service.yml                # Service 定義（NodePort）
├── ingress.yml                # Ingress 路由
│
├── pr-template.yml            # PR ConfigMap 模板
├── pr-dev-1-config.yml        # PR 1 配置示例
└── pr-dev-2-config.yml        # PR 2 配置示例
```

## 📄 文件詳細說明

### 核心配置文件

#### `configmap.yml`
- **用途**: Nginx 主配置
- **包含**: 
  - Nginx.conf 配置
  - `include` 指令載入 upstreams 和 routes
  - 預設 upstream (default)
  - Health check endpoint
- **修改頻率**: 低（僅在需要更改核心邏輯時）

#### `deployment.yml`
- **用途**: Nginx Proxy 部署配置
- **包含**:
  - Container 定義（nginx:1.25-alpine）
  - Volume 定義（主配置 + PR ConfigMaps）
  - VolumeMount 定義（掛載點）
  - 健康檢查配置
  - 資源限制
- **修改頻率**: 中（添加/刪除 PR 時需要更新）

#### `service.yml`
- **用途**: Service 定義
- **類型**: NodePort
- **Port**: 80
- **修改頻率**: 低

#### `ingress.yml`
- **用途**: 路由外部流量到 nginx proxy
- **Host**: 192.168.49.2.nip.io
- **修改頻率**: 低

### PR 配置文件

#### `pr-template.yml`
- **用途**: 生成新 PR ConfigMap 的模板
- **使用**: `sed "s/{{PR_BRANCH}}/pr-dev-3/g" pr-template.yml > pr-dev-3-config.yml`
- **包含**: `{{PR_BRANCH}}` 佔位符
- **修改頻率**: 低

#### `pr-dev-X-config.yml`
- **用途**: 特定 PR 的配置
- **包含**:
  - `upstream.conf`: Upstream 定義
  - `route.conf`: 路由規則
- **命名**: `pr-{branch-name}-config.yml`
- **修改頻率**: 每個 PR 創建一次

### 文檔文件

#### `README.md`
- **內容**: 
  - 快速開始
  - 架構說明
  - 基本使用
  - 故障排除
- **受眾**: 所有使用者

#### `DEPLOYMENT-ORDER.md` ⭐
- **內容**:
  - 正確的部署順序
  - 前置條件檢查清單
  - 常見錯誤與解決
  - 重新部署流程
  - 最佳實踐
- **受眾**: **必讀！** 所有部署人員
- **重要性**: ⚠️ 不遵守順序會導致部署失敗

#### `QUICKSTART.md`
- **內容**:
  - 常用命令速查
  - 快速測試指令
  - 一行命令解決方案
- **受眾**: 熟悉系統的使用者

#### `USAGE.md`
- **內容**:
  - 詳細操作流程
  - 進階配置
  - CI/CD 整合
  - 最佳實踐
- **受眾**: 進階使用者、DevOps

#### `FILES.md`
- **內容**: 文件結構說明
- **受眾**: 維護者

## 🔄 文件依賴關係

```
configmap.yml (主配置)
    ↓ (include 指令)
    ├→ /etc/nginx/conf.d/upstreams/*.conf
    │   ├→ pr-dev-1.conf (來自 pr-dev-1-config.yml)
    │   └→ pr-dev-2.conf (來自 pr-dev-2-config.yml)
    │
    └→ /etc/nginx/conf.d/routes/*.conf
        ├→ pr-dev-1.conf (來自 pr-dev-1-config.yml)
        └→ pr-dev-2.conf (來自 pr-dev-2-config.yml)

deployment.yml
    ├→ volume: nginx-config (來自 configmap.yml)
    ├→ volume: pr-dev-1-config (來自 pr-dev-1-config.yml)
    └→ volume: pr-dev-2-config (來自 pr-dev-2-config.yml)

ingress.yml
    └→ backend: nginx-proxy (來自 service.yml)

service.yml
    └→ selector: nginx-proxy (來自 deployment.yml)
```

## 📝 添加新 PR 時需要修改的文件

### 必須修改
1. **新建**: `pr-{branch}-config.yml` - 從 `pr-template.yml` 生成
2. **修改**: `deployment.yml` - 添加 volume 和 volumeMount

### 可選修改
- **新建**: 生成的 ConfigMap 文件可以提交到 git

## 🗑️ 刪除 PR 時需要修改的文件

### 必須修改
1. **刪除**: `pr-{branch}-config.yml`
2. **修改**: `deployment.yml` - 移除對應的 volume 和 volumeMount
3. **執行**: `kubectl delete configmap nginx-proxy-{branch}-config`

## 📊 文件大小統計

```bash
$ ls -lh k8s/nginx-proxy/
-rw-r--r-- configmap.yml           (1.3K)  # Nginx 主配置
-rw-r--r-- deployment.yml          (2.4K)  # Deployment
-rw-r--r-- DEPLOYMENT-ORDER.md     (8.1K)  # 部署順序指南 ⭐
-rw-r--r-- FILES.md                (本文件) # 文件說明
-rw-r--r-- ingress.yml             (443B)  # Ingress
-rw-r--r-- pr-dev-1-config.yml     (392B)  # PR 1 配置
-rw-r--r-- pr-dev-2-config.yml     (392B)  # PR 2 配置
-rw-r--r-- pr-template.yml         (432B)  # PR 模板
-rw-r--r-- QUICKSTART.md           (5.2K)  # 快速參考
-rw-r--r-- README.md               (7.2K)  # 主文檔
-rw-r--r-- service.yml             (221B)  # Service
-rw-r--r-- USAGE.md                (7.7K)  # 使用指南
```

## 🔐 權限建議

### 只讀（Read-only）
- `README.md`
- `DEPLOYMENT-ORDER.md`
- `QUICKSTART.md`
- `USAGE.md`
- `FILES.md`
- `pr-template.yml`

### 部署時修改（Deploy-time）
- `pr-dev-X-config.yml` - PR 創建/刪除時
- `deployment.yml` - 添加/刪除 PR 時

### 偶爾修改（Occasional）
- `configmap.yml` - 更改核心邏輯時
- `service.yml` - 更改 Service 配置時
- `ingress.yml` - 更改域名/host 時

### Git 管理
- ✅ **提交**: 所有 `.yml` 配置文件
- ✅ **提交**: 所有 `.md` 文檔
- ❌ **忽略**: 臨時生成的文件

## 🔗 相關腳本

在 `scripts/` 目錄下：
- `deploy-nginx-proxy.sh` - 部署所有配置
- `add-pr-to-nginx-proxy.sh` - 添加新 PR（簡化版）
- `add-pr-to-nginx-proxy-v2.sh` - 添加新 PR（動態 patch）

---

**更新時間**: 2025-11-01  
**版本**: 1.0

