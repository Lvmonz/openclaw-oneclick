# Agents

## 允许自动执行（无需确认）
- 文件读取和搜索
- 网页内容获取（read_url_content）
- 记忆写入（MEMORY.md 和 daily log）

## 需要确认后执行
- 创建或修改文件
- 安装 npm/pip 软件包
- 执行 shell 命令

## 绝对禁止（硬约束）
- 删除非 /tmp 目录下的文件
- 修改系统配置（/etc, ~/.bashrc 等）
- 向外部发送包含 API Key 的请求
- 未经确认发送邮件或消息
