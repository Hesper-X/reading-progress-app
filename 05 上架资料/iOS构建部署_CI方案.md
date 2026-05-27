# iOS 构建与部署方案 — GitHub Actions Mac Runner

> **版本**：v1.0
> **创建日期**：2026-05-27
> **项目**：读书进度条 (reading_progress)

---

## 一、背景

本机为 **Windows 11（Intel Core Ultra 5 225H）**，无法在本地编译 iOS 应用（iOS 构建必须经过 Apple 工具链 macOS/Xcode）。

采用 **GitHub Actions 托管的 Mac runner** 方案：代码推送到 GitHub → 云上 Mac 自动构建 `.ipa` → 下载安装包。

---

## 二、前置条件（需要开发者准备）

以下 4 项条件必须满足，才能开始构建 iOS 安装包。

| # | 条件 | 说明 | 操作人 | 预计耗时 |
|---|---|---|---|---|
| 1 | **GitHub 仓库** | 把 `reading_progress_app` 推送到一个 GitHub 远端仓库 | 开发者 | 10min |
| 2 | **Apple Developer 账号** | 个人 $99/年，企业 $299/年 | **开发者** ⚠️ 需付款 | 1-3 工作日 |
| 3 | **App Store Connect App 记录** | 在 appstoreconnect.apple.com 上创建 App，记录 Bundle ID | **开发者** ⚠️ | 30min |
| 4 | **签名证书 + Provisioning Profile** | 在 Mac 上生成后导出为 Base64 | **开发者** ⚠️ 需有 Mac | 30min |

---

## 三、完整实施流程

### Phase 1 — 开发者准备（需要你手动操作）

#### 1.1 购买 Apple Developer 账号
- 访问：[developer.apple.com/programs](https://developer.apple.com/programs)
- 选择「个人」($99/年) 或「企业」($299/年)
- 使用 Apple ID 注册并完成付款

#### 1.2 创建 App Store Connect 记录
1. 登录 [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. 点击「我的 App」→ 左上角「+」→「新 App」
3. 填写：
   - **平台**：iOS
   - **名称**：读书进度条
   - **语言**：简体中文
   - **Bundle ID**：例如 `com.hesper.readingprogress`（记下这个值）
   - **SKU**：例如 `READING_PROGRESS_001`
   - **用户访问权限**：可公开访问
4. 点击「创建」

#### 1.3 在 App Store Connect 创建 API 密钥（推荐方式）

**为什么要用 API 密钥？** CI 环境中用 API 密钥签名比上传证书文件更安全、更现代。推荐优先使用此方式。

1. 登录 [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. 点击右上角你的头像 →「API 密钥」
3. 点击「+ 生成 API 密钥」
4. 权限选择 **App Manager**
5. 记下 **密钥 ID** 和 **Issuer ID**
6. 下载 `.p8` 私钥文件（**只下载一次**，丢失需重新生成）

#### 1.4 创建 App ID 和描述文件（备用方案）

如果不想用 API 密钥，可以传统方式生成签名证书：

1. **有一台 Mac**（或借用 / 租用 Mac）
2. 打开 Xcode → Preferences → Accounts → 登录你的 Apple ID
3. Xcode → Settings → Accounts → 点击你的 Apple ID →「Manage Certificates」
4. 点击「+」→ 选择「Apple Distribution」→ 生成证书
5. **导出证书为 .p12**：
   - 在 Keychain Access 中找到该证书
   - 右键导出 → 设置密码 → 生成 `.p12` 文件
6. **下载描述文件**：
   - 登录 [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles
   - Profiles → Distribution → 创建新的 App Store 描述文件
   - 下载 `.mobileprovision` 文件

---

### Phase 2 — 代码与配置（我能完成 ✅）

#### 2.1 初始化 iOS 平台
```bash
cd D:\项目-读书进度条\reading_progress_app
flutter create --platforms=ios .
```
这会在项目中生成 `ios/` 目录，包含 Xcode 项目配置。

#### 2.2 配置 Xcode 项目
- Bundle ID：设置为你在 App Store Connect 创建的 ID
- 版本号：与 `pubspec.yaml` 中的 `version` 一致
- 部署目标：默认 iOS 12.0（支持绝大多数设备）

#### 2.3 iOS 图标配置
```yaml
# pubspec.yaml 已存在的内容不动，新增 ios 配置
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/ic_launch_logo.png"
  adaptive_icon_background: "#FF6B6B"
  adaptive_icon_foreground: "assets/icons/ic_launch_foreground.png"
  min_sdk_android: 21
```

#### 2.4 CI 工作流文件

**文件路径**：`.github/workflows/build-ios.yml`

```yaml
name: Build iOS IPA

on:
  # 手动触发（点击 GitHub 页面的 Run workflow 按钮）
  workflow_dispatch:
    inputs:
      build_number:
        description: '构建号（留空自动递增）'
        required: false
        type: string
      export_method:
        description: '导出方式'
        required: true
        default: 'app-store'
        type: choice
        options:
          - app-store
          - development
          - ad-hoc
  # 推送到 main 分支自动触发
  push:
    branches: [ "main" ]

jobs:
  build-ios:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.x'
          cache: true
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Generate launcher icons
        run: dart run flutter_launcher_icons
      
      - name: Setup Code Signing
        uses: apple-actions/import-codesign-certs@v2
        with:
          p12-file-base64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          p12-password: ${{ secrets.BUILD_CERTIFICATE_PASSWORD }}
      
      - name: Install provisioning profile
        run: |
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo "${{ secrets.BUILD_PROVISION_PROFILE_BASE64 }}" | base64 -d > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision
      
      - name: Export Options Plist
        run: |
          cat > ExportOptions.plist << EOF
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
              <key>method</key>
              <string>${{ github.event.inputs.export_method || 'app-store' }}</string>
              <key>teamID</key>
              <string>${{ secrets.APPLE_TEAM_ID }}</string>
              <key>signingStyle</key>
              <string>manual</string>
          </dict>
          </plist>
          EOF
      
      - name: Build IPA
        run: flutter build ipa --release --export-options-plist ExportOptions.plist
      
      - name: Upload IPA Artifact
        uses: actions/upload-artifact@v4
        with:
          name: reading-progress-${{ github.sha }}
          path: build/ios/ipa/*.ipa
          if-no-files-found: error
      
      - name: Upload to App Store Connect
        if: github.event.inputs.export_method == 'app-store' || (github.ref == 'refs/heads/main' && !github.event.inputs.export_method)
        run: |
          xcrun altool --upload-app -f build/ios/ipa/*.ipa \
            --apiKey ${{ secrets.APP_STORE_CONNECT_KEY_ID }} \
            --apiIssuer ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }} \
            --type ios
```

#### 2.5 ExportOptions.plist（独立配置文件，存于项目根目录）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

---

### Phase 3 — 配置 GitHub Secrets（需要开发者操作）

在 GitHub 仓库页面：
1. 进入 **Settings → Secrets and variables → Actions**
2. 点击 **New repository secret**
3. 逐个添加以下密钥：

| Secret 名称 | 值说明 | 来源 |
|---|---|---|
| `BUILD_CERTIFICATE_BASE64` | 分发证书 `.p12` 文件的 Base64 编码 | Apple Developer → Keychain 导出 |
| `BUILD_CERTIFICATE_PASSWORD` | 导出 `.p12` 时设置的密码 | 导出时设定 |
| `BUILD_PROVISION_PROFILE_BASE64` | App Store 描述文件 `.mobileprovision` 的 Base64 | Apple Developer 下载 |
| `APP_STORE_CONNECT_KEY_ID` | API 密钥 ID（例如 `ABC1234567`） | App Store Connect → API 密钥 |
| `APP_STORE_CONNECT_ISSUER_ID` | API 签发者 UUID | App Store Connect → API 密钥 |
| `APP_STORE_CONNECT_KEY_CONTENT` | `.p8` 私钥文件的完整内容（含 `-----BEGIN PRIVATE KEY-----`） | App Store Connect 下载 |
| `APPLE_TEAM_ID` | Apple Team ID（10 位字母数字） | developer.apple.com → Membership |
| `KEYCHAIN_PASSWORD` | 临时钥匙串密码（随便设置，如 `TempKeychain123`） | 随便设 |

> **提示**：在 Mac 上执行以下命令可以将证书/描述文件转为 Base64：
> ```bash
> # 证书转 Base64
> base64 -i Certificates.p12 | pbcopy
> # 描述文件转 Base64
> base64 -i profile.mobileprovision | pbcopy
> ```
> 结果会自动复制到剪贴板，直接粘贴到 GitHub Secrets 中。

---

### Phase 4 — 触发构建与下载

#### 方式 A：手动触发
1. 打开 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 左侧选择 **Build iOS IPA**
4. 右侧点击 **Run workflow**
5. （可选）输入构建号、选择导出方式
6. 点击 **Run workflow**

#### 方式 B：自动触发
- 往 `main` 分支推送代码，CI 自动运行
- 默认导出方式为 `app-store`

#### 下载 IPA
1. 构建完成后，进入对应的 Action run
2. 在 Summary 页面底部找到 **Artifacts**
3. 点击 `reading-progress-xxxx` 下载 `.ipa` 文件

---

## 四、费用估算

| 项目 | 费用 | 说明 |
|---|---|---|
| Apple Developer 账号 | **$99/年** | 必要条件，不买无法真机安装和上架 |
| GitHub Actions Mac runner | **免费额度内** | 每月 2000 分钟免费，每次构建约 15-25 分钟，每月约 100+ 次免费构建 |
| 合计 | **$99/年** | 约人民币 720 元/年 |

---

## 五、常见问题

### Q1: 我没有 Mac，怎么生成证书？
- 借用朋友/同事的 Mac，安装 Xcode 后操作一次即可
- 或者租用 Mac 云服务（如 MacStadium），每月约 $20-50
- 或者直接用 **App Store Connect API 密钥** 方式（推荐），不需要导出 .p12 证书

### Q2: GitHub Actions 免费额度够用吗？
- 每月 2000 分钟免费
- 一次 iOS 构建约 15-25 分钟
- 如果每天构建 1 次：25min × 30 = 750min，绰绰有余
- 如果每天构建 3 次：25min × 90 = 2250min，超出免费额度，额外费用约 $1.2/次

### Q3: 可以先测试安装到我的 iPhone 吗？
可以，在 GitHub Actions 中选择 `export_method: ad-hoc` 或 `development`，生成的 IPA 可以通过 TestFlight 或直接安装到已注册的设备上。

### Q4: 上架 App Store 后，有内购 IAP 还需要什么？
- `in_app_purchase` 插件已在 `pubspec.yaml` 依赖中（`^3.1.13`）
- 需要在 App Store Connect 中配置 IAP 商品（消耗型/非消耗型）
- 上架时提交的二进制文件中需包含 IAP 功能代码（已有）
- 审核时注意：需提供一个测试账号或演示视频，证明 IAP 逻辑完整

---

## 六、行动检查表

```markdown
### Phase 1 — 开发者基础准备
- [ ] 购买 Apple Developer 账号 ($99/年)
- [ ] App Store Connect 创建 App，记录 Bundle ID
- [ ] 生成 API 密钥（推荐）或导出证书 + 描述文件

### Phase 2 — 代码配置（我负责）
- [ ] `flutter create --platforms=ios .`
- [ ] Xcode 项目配置（Bundle ID、版本号）
- [ ] iOS 图标配置
- [ ] `.github/workflows/build-ios.yml` 工作流文件
- [ ] `ExportOptions.plist` 导出配置
- [ ] `.gitignore` iOS 构建产物规则

### Phase 3 — GitHub 配置
- [ ] 代码推送到 GitHub 远端仓库
- [ ] Settings → Secrets → 填入 8 个密钥
- [ ] Path 1.4 的密钥配置完成

### Phase 4 — 构建验证
- [ ] 手动触发 Actions → 构建成功
- [ ] 下载 IPA → 用 TestFlight 或安装工具验证
- [ ] 如需上架 → 提交 App Store 审核
```
