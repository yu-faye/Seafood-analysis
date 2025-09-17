# 🔗 集成现有Azure Data Factory指南

如果您已经有一个现有的Azure Data Factory并同步在GitHub上，可以按照以下步骤集成新的Global Fishing Watch分析功能。

## 📁 文件复制清单

### 1. 核心配置文件
复制这些文件到您现有的ADF仓库：

```
现有ADF仓库/
├── pipelines/
│   └── fishing-events-pipeline.json          # 新增：渔业事件处理管道
├── datasets/
│   ├── gfw-events-api.json                   # 新增：GFW API数据集
│   ├── raw-fishing-events-data.json          # 新增：原始数据存储
│   ├── processed-fishing-events-data.json    # 新增：处理后数据
│   └── fishing-events-table.json             # 新增：数据库表映射
├── linkedServices/
│   ├── global-fishing-watch-api.json         # 新增：GFW API连接
│   └── azure-databricks-linked-service.json  # 新增：Databricks连接
└── scripts/
    └── databricks-fishing-events-processor.py # 新增：数据处理脚本
```

### 2. 数据库脚本
```
sql/
└── create-fishing-events-tables.sql          # 新增：数据库表结构
```

### 3. 部署脚本（可选）
```
deployment/
├── deploy-to-existing-adf.ps1                # 专门用于现有ADF
├── simple-deploy.sh                          # 简化部署脚本
└── step-by-step-deploy.sh                    # 分步骤部署
```

## 🔧 集成步骤

### 步骤1：复制文件到现有仓库
```bash
# 在您的现有ADF仓库目录中
cp -r /path/to/azure-adf-setup/pipelines/* ./pipeline/
cp -r /path/to/azure-adf-setup/datasets/* ./dataset/
cp -r /path/to/azure-adf-setup/linked-services/* ./linkedService/
```

### 步骤2：更新现有链接服务
如果您已经有Azure Storage和SQL Database的链接服务，需要：

1. **更新存储链接服务**：确保支持Data Lake Gen2
2. **添加GFW API链接服务**：新增Global Fishing Watch API连接
3. **添加Databricks链接服务**：如果使用Databricks处理

### 步骤3：部署到现有ADF
使用专门的脚本：
```powershell
# 使用现有ADF的部署脚本
.\deployment\deploy-to-existing-adf.ps1 `
    -ResourceGroupName "your-existing-rg" `
    -DataFactoryName "your-existing-adf" `
    -GFWApiToken "your-token"
```

### 步骤4：创建数据库表
在您现有的SQL数据库中执行：
```sql
-- 运行 sql/create-fishing-events-tables.sql
-- 这会创建渔业分析所需的表结构
```

## 📋 文件映射对照表

| azure-adf-setup 文件 | 现有ADF仓库位置 | 说明 |
|---------------------|----------------|------|
| `pipelines/fishing-events-pipeline.json` | `pipeline/` | 主要分析管道 |
| `datasets/gfw-events-api.json` | `dataset/` | API数据集 |
| `datasets/raw-fishing-events-data.json` | `dataset/` | 原始数据 |
| `datasets/processed-fishing-events-data.json` | `dataset/` | 处理数据 |
| `datasets/fishing-events-table.json` | `dataset/` | 数据库表 |
| `linkedServices/global-fishing-watch-api.json` | `linkedService/` | API连接 |
| `linkedServices/azure-databricks-linked-service.json` | `linkedService/` | Databricks连接 |

## ⚠️ 注意事项

### 1. 命名冲突
- 检查是否有同名的pipeline、dataset或linkedService
- 如有冲突，重命名新文件或合并功能

### 2. 参数配置
- 更新pipeline中的参数以匹配您的环境
- 确保存储账户名、数据库名等配置正确

### 3. 权限设置
- 确保ADF有访问GFW API的权限
- 验证Databricks集群的访问权限

## 🚀 快速集成命令

如果您的现有ADF仓库结构标准，可以使用这个快速脚本：

```bash
#!/bin/bash
# 快速集成脚本

EXISTING_ADF_REPO="/path/to/your/existing/adf/repo"
SOURCE_DIR="/path/to/azure-adf-setup"

# 复制管道
cp "$SOURCE_DIR/pipelines/fishing-events-pipeline.json" "$EXISTING_ADF_REPO/pipeline/"

# 复制数据集
cp "$SOURCE_DIR/datasets/"*.json "$EXISTING_ADF_REPO/dataset/"

# 复制链接服务
cp "$SOURCE_DIR/linked-services/"*.json "$EXISTING_ADF_REPO/linkedService/"

# 复制脚本
mkdir -p "$EXISTING_ADF_REPO/scripts"
cp "$SOURCE_DIR/scripts/databricks-fishing-events-processor.py" "$EXISTING_ADF_REPO/scripts/"

# 复制SQL脚本
mkdir -p "$EXISTING_ADF_REPO/sql"
cp "$SOURCE_DIR/sql/create-fishing-events-tables.sql" "$EXISTING_ADF_REPO/sql/"

echo "✅ 文件集成完成！"
echo "📋 下一步："
echo "  1. 检查文件命名冲突"
echo "  2. 更新配置参数"
echo "  3. 部署到ADF"
echo "  4. 创建数据库表"
```

## 🔄 GitHub同步

集成完成后：
```bash
cd /path/to/your/existing/adf/repo
git add .
git commit -m "feat: Add Global Fishing Watch analysis pipeline

- Add fishing events processing pipeline
- Add GFW API datasets and linked services  
- Add Databricks processing script
- Add SQL schema for port visit analysis"
git push origin main
```

## 📞 需要帮助？

如果在集成过程中遇到问题：
1. 检查文件路径和命名约定
2. 验证JSON格式是否正确
3. 确认所有依赖的链接服务都已创建
4. 测试管道的连接和权限

集成完成后，您就可以在现有的ADF中使用Global Fishing Watch分析功能了！
