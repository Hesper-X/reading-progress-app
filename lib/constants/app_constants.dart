/// 应用常量（V3.0）
class AppConstants {
  AppConstants._();

  static const String appName = '读书进度条';
  static const String slogan = '把你读完的书，变成一种生命的进度';
  static const String watermark = '来自读书进度条 App';
  static const String appVersion = '3.0.0';

  // V3.0 输入限制
  static const int maxBookTitle = 100;
  static const int maxAuthorName = 50;
  static const int maxFeeling = 200;
  static const int maxCustomMessage = 200;

  // V2.0 兼容别名
  static const int maxTitleLength = maxBookTitle;
  static const int maxAuthorLength = maxAuthorName;
  static const int maxNotesLength = maxFeeling;

  // 免费版限制
  static const int freeVersionLimit = 5;
  static const int maxReadingCardShow = 2;
  static const int softLimitWarning = 3;

  // Pro 版
  static const double proPrice = 12.0;
  static const String proProductId = 'pro_version';

  // 默认设置
  static const int defaultYearlyGoal = 52; // V3.0: 默认改为52
  static const String defaultReminderTime = '21:00';

  // V3.0 分享图尺寸
  static const int shareImageWidth = 360;
  static const int shareImageHeight = 640;
  static const double shareScale = 3.0;

  // V3.0 启动页时间
  static const double splashMinDuration = 1.5;
  static const double splashMaxDuration = 3.0;

  // 环形进度条参数（首页）
  static const double homeProgressDiameter = 240.0;
  static const double homeProgressStrokeWidth = 16.0;

  // V2.0 兼容
  static const int splashDurationMs = 3000;

  // 动画时长
  static const int progressAnimationMs = 500;
  static const int successAnimationMs = 1500;

  // 数据库
  static const String dbName = 'reading_progress.db';
  static const int dbVersion = 3; // V3.0

  // 法律与政策（上架合规）
  static const String privacyLegalText = '用户协议\n\n欢迎使用「读书进度条」App。本协议是您与本 App 之间关于使用本服务的法律协议。\n\n1. 服务说明：本 App 提供阅读记录与管理服务，所有数据存储在您的设备本地。\n\n2. 用户行为：您承诺不利用本 App 从事任何违法违规行为。\n\n3. 免责声明：本 App 按"现状"提供，不附带任何明示或暗示的保证。\n\n4. 协议变更：我们保留随时修改本协议的权利，修改后的协议一经发布即生效。\n\n如果您继续使用本 App，即表示您接受修订后的协议。';

  static const String privacyPolicyText = '隐私政策\n\n「读书进度条」尊重并保护您的隐私。\n\n1. 数据本地存储：本 App 的所有数据（包括书籍记录、阅读进度、设置偏好）均存储在您的设备本地，不会上传至任何服务器。\n\n2. 不收集个人信息：我们不会收集您的姓名、位置、设备标识符、通讯录等任何个人信息。\n\n3. 无需网络权限：本 App 的核心功能无需网络连接即可使用（分享、导出等功能除外）。\n\n4. 第三方服务：分享功能使用系统原生 Share Sheet，不会将数据传输给第三方分析平台。\n\n5. 政策更新：我们可能会更新本隐私政策，更新后会在 App 内展示。';

  static const String privacyDataCollectionText = '个人信息收集清单\n\n根据国内安卓应用商店审核要求，特此说明：\n\n「读书进度条」采用纯本地架构，不收集任何个人信息。\n\n所有您在使用过程中产生的数据（书籍信息、阅读记录、设置偏好等）均仅存储在您的设备本地，不会传输至任何远程服务器。\n\n我们无需您注册账号、无需绑定手机号、无需开启任何权限即可使用核心功能。';

  static const String privacyThirdPartyText = '第三方信息共享清单\n\n本 App 使用的第三方 SDK 及库：\n\n1. Flutter SDK — 跨平台 UI 框架\n2. sqflite — 本地数据库引擎\n3. share_plus — 系统分享功能\n4. fl_chart — 图表渲染\n5. provider — 状态管理\n6. image_picker — 图片选择\n7. path_provider — 文件路径管理\n8. url_launcher — 链接跳转\n9. in_app_purchase — 应用内购买\n10. share_plus — 社交分享\n\n以上均为开源库，不涉及数据传输至第三方。';

  static const String privacyOpenSourceText = '开源许可\n\n本 App 基于 Flutter 框架开发，使用的开源库许可声明如下：\n\n• Flutter (BSD 3-Clause License)\n• sqflite (MIT License)\n• share_plus (BSD 3-Clause License)\n• fl_chart (MIT License)\n• provider (MIT License)\n• image_picker (BSD 3-Clause License)\n• path_provider (BSD 3-Clause License)\n• url_launcher (BSD 3-Clause License)\n• in_app_purchase (BSD 3-Clause License)\n• share_plus (BSD 3-Clause License)\n\n各开源库的完整许可文本可在其 GitHub 仓库中查阅。';

  // 联系我们
  static const String contactEmail = 'feedback@reading-progress.app';
}
