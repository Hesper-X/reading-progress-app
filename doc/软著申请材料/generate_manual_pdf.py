"""
软著用户手册生成器 - 带截图
"""

import os
from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm, cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.colors import HexColor
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Image,
    PageBreak, KeepTogether
)
from reportlab.platypus.flowables import HRFlowable
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.cidfonts import UnicodeCIDFont

# ============ 配置 ============
SOFTWARE_NAME = "读书进度条"
VERSION = "V3.4.0"

SCREENSHOT_DIR = Path(r"C:\Users\hespe\.easyclaw\workspace-frontend-1")
OUTPUT_DIR = Path(r"C:\Users\hespe\reading_progress_app\doc\软著申请材料")
OUTPUT_FILE = OUTPUT_DIR / f"{SOFTWARE_NAME}_{VERSION}_用户手册.pdf"

# 截图映射（页面描述 → 截图文件名）
SCREENSHOTS = {
    "home": "emulator_home.png",      # 首页
    "stats": "emulator_stats.png",    # 统计页
    "share": "emulator_share.png",    # 分享页
    "settings": "emulator_settings.png",  # 设置页
    "shelf": "emulator_screen5.png",  # 书架页
}


def create_user_manual():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 注册中文字体
    try:
        pdfmetrics.registerFont(UnicodeCIDFont('STSong-Light'))
        cn_font = 'STSong-Light'
    except:
        cn_font = 'Helvetica'

    # 创建样式
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'CNTitle',
        parent=styles['Title'],
        fontName=cn_font,
        fontSize=20,
        leading=28,
        spaceAfter=16,
        alignment=TA_CENTER,
    )

    h1_style = ParagraphStyle(
        'CNH1',
        parent=styles['Heading1'],
        fontName=cn_font,
        fontSize=16,
        leading=22,
        spaceBefore=16,
        spaceAfter=10,
        textColor=HexColor('#333333'),
    )

    h2_style = ParagraphStyle(
        'CNH2',
        parent=styles['Heading2'],
        fontName=cn_font,
        fontSize=13,
        leading=18,
        spaceBefore=12,
        spaceAfter=8,
        textColor=HexColor('#555555'),
    )

    body_style = ParagraphStyle(
        'CNBody',
        parent=styles['BodyText'],
        fontName=cn_font,
        fontSize=10.5,
        leading=18,
        spaceAfter=6,
        firstLineIndent=0,
    )

    bullet_style = ParagraphStyle(
        'CNBullet',
        parent=body_style,
        leftIndent=20,
        bulletIndent=10,
        spaceBefore=2,
        spaceAfter=2,
    )

    small_style = ParagraphStyle(
        'CNSmall',
        parent=body_style,
        fontSize=9,
        leading=14,
    )

    # 构建文档
    doc = SimpleDocTemplate(
        str(OUTPUT_FILE),
        pagesize=A4,
        leftMargin=22*mm,
        rightMargin=22*mm,
        topMargin=22*mm,
        bottomMargin=22*mm,
        title=f"{SOFTWARE_NAME} {VERSION} 用户手册",
        author="读书进度条",
    )

    story = []

    # ===== 封面 =====
    story.append(Spacer(1, 60*mm))
    story.append(Paragraph(f"{SOFTWARE_NAME}", title_style))
    story.append(Spacer(1, 8*mm))
    story.append(Paragraph(f"{VERSION} 用户手册", ParagraphStyle(
        'SubTitle', parent=title_style, fontSize=14, leading=20, textColor=HexColor('#666666')
    )))
    story.append(Spacer(1, 20*mm))

    # 如果有启动图
    splash_path = SCREENSHOT_DIR / "startup.png"
    if splash_path.exists():
        img = Image(str(splash_path), width=80*mm, height=80*mm * (2992/1344) if False else 80*mm * 0.6)
        img.hAlign = 'CENTER'
        story.append(img)

    story.append(Spacer(1, 20*mm))
    story.append(Paragraph("© 2026 读书进度条 保留所有权利", ParagraphStyle(
        'Copyright', parent=small_style, alignment=TA_CENTER, textColor=HexColor('#999999')
    )))
    story.append(PageBreak())

    # ===== 一、软件简介 =====
    story.append(Paragraph("一、软件简介", h1_style))
    story.append(Paragraph(
        "「读书进度条」是一款专注于阅读进度管理的移动应用。它帮助你记录每一本正在读的书、标记已完成的阅读、查看阅读统计数据和年度趋势，把读书变成一种可视化的&#171;生命进度&#187;。",
        body_style
    ))
    story.append(Paragraph("核心功能：", body_style))
    features = [
        "📚 添加在读/已读/想读书籍",
        "📊 阅读统计与年度趋势图表",
        "✅ 每日打卡与连续记录",
        "📝 读后笔记与星级评价",
        "📤 生成阅读分享卡片",
        "🌙 支持深色/浅色主题切换",
        "🔔 每日阅读提醒通知",
        "🏆 Pro 版解锁高级统计功能",
    ]
    for f in features:
        story.append(Paragraph(f"• {f}", bullet_style))

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph("<b>适用平台：</b>Android / iOS", body_style))
    story.append(Paragraph("<b>软件版本：</b>V3.4.0", body_style))
    story.append(HRFlowable(width="100%", thickness=0.5, color=HexColor('#CCCCCC'), spaceBefore=8, spaceAfter=8))

    # ===== 二、安装说明 =====
    story.append(Paragraph("二、安装说明", h1_style))

    story.append(Paragraph("Android 安装", h2_style))
    story.append(Paragraph("1. 下载 APK 安装包到手机", body_style))
    story.append(Paragraph("2. 在设备设置中允许「安装未知来源应用」", body_style))
    story.append(Paragraph("3. 点击 APK 文件完成安装", body_style))
    story.append(Paragraph("4. 首次启动时建议授予通知权限，用于每日阅读提醒", body_style))

    story.append(Paragraph("iOS 安装", h2_style))
    story.append(Paragraph("1. 通过 App Store 搜索「读书进度条」下载", body_style))
    story.append(Paragraph("2. 首次启动时允许通知权限", body_style))
    story.append(HRFlowable(width="100%", thickness=0.5, color=HexColor('#CCCCCC'), spaceBefore=8, spaceAfter=8))

    # ===== 三、主要功能操作 =====
    story.append(Paragraph("三、主要功能操作", h1_style))

    # 3.1 首页
    story.append(Paragraph("3.1 首页（当前在读）", h2_style))
    story.append(Paragraph(
        "打开应用后，首页展示「当前在读」的书籍列表。每本书以卡片形式展示书名、作者、阅读进度等信息。",
        body_style
    ))
    story.append(Paragraph(
        "页面顶部显示年度阅读目标进度环，直观展示当年已读完书籍数量与目标的比例。",
        body_style
    ))

    # 插入首页截图
    home_screenshot = SCREENSHOT_DIR / SCREENSHOTS["home"]
    if home_screenshot.exists():
        img = Image(str(home_screenshot), width=70*mm, height=70*mm * 1.5)
        img.hAlign = 'CENTER'
        story.append(img)
        story.append(Paragraph("<i>图1：应用首页（当前在读列表）</i>", ParagraphStyle(
            'Caption', parent=small_style, alignment=TA_CENTER, textColor=HexColor('#888888')
        )))

    # 3.2 添加书籍
    story.append(Paragraph("3.2 添加书籍", h2_style))
    story.append(Paragraph("支持三种方式添加书籍：", body_style))
    story.append(Paragraph("• <b>拍照识书</b>：点击拍照按钮，使用 OCR 技术识别书籍封面文字，自动填充书名", bullet_style))
    story.append(Paragraph("• <b>搜索添加</b>：在搜索框输入书名关键词进行搜索", bullet_style))
    story.append(Paragraph("• <b>手动输入</b>：直接在输入框中填写书名和作者信息", bullet_style))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        "添加时可选择「加入想读」（放入心愿书单）或「开始阅读」（立即开始计时）。",
        body_style
    ))

    # 3.3 书架
    story.append(Paragraph("3.3 书架（全部书籍）", h2_style))
    story.append(Paragraph(
        "书架页面展示所有已添加的书籍，支持按「在读 / 已读 / 想读」三种状态筛选，"
        "也可以按自定义分类筛选或在搜索框中直接搜索书籍名称。",
        body_style
    ))
    shelf_screenshot = SCREENSHOT_DIR / SCREENSHOTS["shelf"]
    if shelf_screenshot.exists():
        img = Image(str(shelf_screenshot), width=70*mm, height=70*mm * 1.5)
        img.hAlign = 'CENTER'
        story.append(img)
        story.append(Paragraph("<i>图2：书架页面</i>", ParagraphStyle(
            'Caption', parent=small_style, alignment=TA_CENTER, textColor=HexColor('#888888')
        )))

    # 3.4 标记读完
    story.append(Paragraph("3.4 标记读完", h2_style))
    story.append(Paragraph(
        "在读列表中点击任意书籍进入详情页后：",
        body_style
    ))
    story.append(Paragraph("1. 点击「标记读完」按钮", body_style))
    story.append(Paragraph("2. 填写读后笔记（可选）", body_style))
    story.append(Paragraph("3. 给出星级评价（1-5星）", body_style))
    story.append(Paragraph("4. 选择读完日期", body_style))
    story.append(Paragraph("5. 点击确认保存", body_style))
    story.append(Paragraph("完成后该书籍自动从「在读」转移到「已读」书架。", body_style))

    # 3.5 阅读统计
    story.append(Paragraph("3.5 阅读统计", h2_style))
    story.append(Paragraph("统计页面提供多维度的阅读数据可视化：", body_style))
    story.append(Paragraph("• 年度阅读量：本年已读书籍总数", bullet_style))
    story.append(Paragraph("• 阅读趋势图：按月展示阅读数量的变化折线图", bullet_style))
    story.append(Paragraph("• 最爱作者排行：按阅读数量排序的作者榜单", bullet_style))
    story.append(Paragraph("• 最长与最短书籍：阅读时长的两极对比", bullet_style))
    story.append(Paragraph("• 阅读偏好分布：书籍类型的饼图分析", bullet_style))

    stats_screenshot = SCREENSHOT_DIR / SCREENSHOTS["stats"]
    if stats_screenshot.exists():
        img = Image(str(stats_screenshot), width=70*mm, height=70*mm * 1.5)
        img.hAlign = 'CENTER'
        story.append(img)
        story.append(Paragraph("<i>图3：阅读统计页面</i>", ParagraphStyle(
            'Caption', parent=small_style, alignment=TA_CENTER, textColor=HexColor('#888888')
        )))

    # 3.6 每日打卡
    story.append(Paragraph("3.6 每日打卡", h2_style))
    story.append(Paragraph(
        "在首页点击「打卡」按钮进入日历打卡界面。日历视图以月份为单位展示打卡记录，"
        "已打卡的日期以特殊标记显示。用户可查看连续打卡天数和总打卡次数，每日限打卡一次。",
        body_style
    ))

    # 3.7 分享功能
    story.append(Paragraph("3.7 分享功能", h2_style))
    story.append(Paragraph(
        "统计页面右上角可进入分享功能，生成精美的阅读数据分享卡片。"
        "卡片包含年度阅读数据摘要和个性化文案，可保存到相册或分享至微信、QQ 等社交平台。",
        body_style
    ))
    share_screenshot = SCREENSHOT_DIR / SCREENSHOTS["share"]
    if share_screenshot.exists():
        img = Image(str(share_screenshot), width=70*mm, height=70*mm * 1.5)
        img.hAlign = 'CENTER'
        story.append(img)
        story.append(Paragraph("<i>图4：分享卡片页面</i>", ParagraphStyle(
            'Caption', parent=small_style, alignment=TA_CENTER, textColor=HexColor('#888888')
        )))

    # 3.8 设置
    story.append(Paragraph("3.8 设置", h2_style))
    story.append(Paragraph("设置页面支持以下自定义选项：", body_style))
    story.append(Paragraph("• 主题模式：浅色 / 深色 / 跟随系统", bullet_style))
    story.append(Paragraph("• 每日提醒：设置阅读提醒时间", bullet_style))
    story.append(Paragraph("• 年度目标：设定每年计划阅读的书籍数量", bullet_style))
    story.append(Paragraph("• 数据管理：数据导出与导入", bullet_style))
    story.append(Paragraph("• 隐私与法律：用户协议、隐私政策、个人信息清单、第三方共享清单", bullet_style))

    settings_screenshot = SCREENSHOT_DIR / SCREENSHOTS["settings"]
    if settings_screenshot.exists():
        img = Image(str(settings_screenshot), width=70*mm, height=70*mm * 1.5)
        img.hAlign = 'CENTER'
        story.append(img)
        story.append(Paragraph("<i>图5：设置页面</i>", ParagraphStyle(
            'Caption', parent=small_style, alignment=TA_CENTER, textColor=HexColor('#888888')
        )))

    # 3.9 Pro 版
    story.append(Paragraph("3.9 Pro 版功能（高级会员）", h2_style))
    story.append(Paragraph("Pro 版本解锁以下高级功能：", body_style))
    story.append(Paragraph("• 📊 更多统计图表与分析维度", bullet_style))
    story.append(Paragraph("• 🎨 额外主题配色方案", bullet_style))
    story.append(Paragraph("• 🎯 自定义阅读目标与提醒", bullet_style))
    story.append(Paragraph("购买方式：设置页 → 升级 Pro → 选择订阅方案", body_style))

    story.append(HRFlowable(width="100%", thickness=0.5, color=HexColor('#CCCCCC'), spaceBefore=8, spaceAfter=8))

    # ===== 四、常见问题 =====
    story.append(Paragraph("四、常见问题", h1_style))

    story.append(Paragraph("<b>Q：如何修改已添加的书籍信息？</b>", body_style))
    story.append(Paragraph("A：在书架页面长按书籍卡片，选择「编辑」修改书名、作者等信息。", body_style))

    story.append(Paragraph("<b>Q：打卡错过了怎么办？</b>", body_style))
    story.append(Paragraph("A：系统仅支持当天打卡，不支持补签。连续打卡天数以实际打卡记录为准。", body_style))

    story.append(Paragraph("<b>Q：如何备份数据？</b>", body_style))
    story.append(Paragraph("A：设置 → 数据管理 → 导出数据，可将全部数据导出为文件保存。更换设备后可通过「导入数据」恢复。", body_style))

    story.append(Paragraph("<b>Q：深色模式如何开启？</b>", body_style))
    story.append(Paragraph("A：设置 → 主题模式 → 选择「深色模式」或「跟随系统」。", body_style))

    story.append(HRFlowable(width="100%", thickness=0.5, color=HexColor('#CCCCCC'), spaceBefore=8, spaceAfter=8))

    # ===== 五、技术支持 =====
    story.append(Paragraph("五、技术支持与反馈", h1_style))
    story.append(Paragraph("如有问题或建议，请通过以下方式联系：", body_style))
    story.append(Paragraph("• 📧 应用内反馈：设置页 → 意见反馈", bullet_style))
    story.append(Paragraph("• 📧 邮件：（待补充）", bullet_style))

    story.append(Spacer(1, 20*mm))
    story.append(Paragraph(f"© 2026 {SOFTWARE_NAME} 保留所有权利", ParagraphStyle(
        'Footer', parent=small_style, alignment=TA_CENTER, textColor=HexColor('#999999')
    )))

    # 生成 PDF
    doc.build(story)
    print(f"\n✅ 用户手册已生成: {OUTPUT_FILE}")
    print(f"   文件大小: {OUTPUT_FILE.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    create_user_manual()
