# gdou_helper

广东海洋大学助手（GDOU 助手）Flutter 客户端，配合无数据库后端 [`gdou_helper_backend`](https://github.com/farshore07/gdou_helper_backend) 使用。

## 核心功能

- **统一身份认证登录**：支持按需图形验证码、企业微信 / 短信二次验证（MFA）与可信设备指纹复用，支持记住密码与会话过期自动重登。
- **个人课表**：按学期查看周课表，支持单双周 / 跳周 / 复合周次精确识别，自动同步后端校历起始日期与节次时间。
- **考试日程与成绩查询**：查看本学期考试安排、课程成绩与绩点统计，支持查看及显式刷新单科成绩分项明细。
- **本地提醒**：支持上课前 15 分钟提醒与考试前一天 20:00 提醒，自动过滤非本周课程并适配 Android 精确闹钟与开机恢复。
- **离线缓存与外观**：课表、校历、成绩与考试数据持久化缓存在设备本地（仅主动清除时删除），支持浅色 / 深色模式切换与持久化、GitHub Releases 更新检查及隐私声明 / 用户协议阅读。

## 技术栈

- **框架**：Flutter（Dart `^3.12.2`）
- **状态管理与路由**：`flutter_riverpod`、`go_router`
- **网络与本地存储**：`dio`、`shared_preferences`、`flutter_secure_storage`
- **本地通知**：`flutter_local_notifications`、`timezone`

## 开发与构建

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 代码检查与测试

```bash
flutter analyze
flutter test
```

### 3. 运行与打包

可通过 `--dart-define=API_SERVER=<后端地址>` 指定教务查询后端地址：

```bash
# 调试运行
flutter run --dart-define=API_SERVER=http://127.0.0.1:8080

# Release 运行（连接真机直接安装并启动）
flutter run --release --dart-define=API_SERVER=https://your-backend.example.com

# 构建分架构 Release APK（主流手机取 app-arm64-v8a-release.apk）
flutter build apk --release --split-per-abi --dart-define=API_SERVER=https://your-backend.example.com
```

## 目录结构

```text
lib/
├── config/       # 应用配置、隐私声明与用户协议文案
├── models/       # 课程、成绩、考试、版本更新等数据模型
├── pages/        # 课表、考试与成绩、登录、设置、关于等页面
├── providers/    # 认证、课表/成绩/考试数据、提醒、主题、学期与更新状态
├── services/     # API 请求、本地缓存、安全存储与本地通知封装
└── widgets/      # 公共组件（学期选择器、Toast 等）
test/
└── frontend_regression_test.dart
```

## 免责声明

本项目为开源第三方学习工具，与广东海洋大学官方无隶属、合作或授权关系，所有教务信息均以学校官方系统及通知为准。
