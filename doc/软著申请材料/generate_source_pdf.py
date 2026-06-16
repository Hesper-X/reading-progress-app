"""
软著源代码文档生成器
- 前30页（程序开头）+ 后30页（程序结尾）
- 每页50行代码
- 页眉标注软件名称和版本号
- A4纸，等宽字体
"""

import os
import re
from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm, cm
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.fonts import addMapping

# ============ 配置 ============
SOFTWARE_NAME = "读书进度条"
VERSION = "V3.4.0"
LINES_PER_PAGE = 50
TOTAL_PAGES = 60
FIRST_HALF = 30  # 前30页
SECOND_HALF = 30  # 后30页

# 源码目录
SOURCE_DIR = Path(r"C:\Users\hespe\reading_progress_app\lib")

# 输出文件
OUTPUT_DIR = Path(r"C:\Users\hespe\reading_progress_app\doc\软著申请材料")
OUTPUT_FILE = OUTPUT_DIR / f"{SOFTWARE_NAME}_{VERSION}_源代码文档.pdf"

# 字体设置 - 使用系统等宽字体
# Windows 上优先使用更纱黑体或微软雅黑作为等宽可用字体
FONT_NAME = "Courier"
FONT_SIZE = 8
HEADER_FONT_SIZE = 9
LINE_HEIGHT = 11  # 点


def collect_source_files(source_dir: Path) -> list[Path]:
    """收集所有 .dart 源文件，按路径排序"""
    files = []
    for f in source_dir.rglob("*.dart"):
        files.append(f)
    files.sort(key=lambda p: str(p))
    return files


def read_source_lines(filepath: Path) -> list[str]:
    """读取源文件所有行，去除 BOM"""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        # 去除 BOM
        if content.startswith("\ufeff"):
            content = content[1:]
        return content.split("\n")
    except Exception as e:
        return [f"// Error reading file: {e}"]


def generate_pdf():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 收集所有源文件
    source_files = collect_source_files(SOURCE_DIR)
    print(f"共找到 {len(source_files)} 个源文件")

    # 读取所有行
    all_lines = []
    file_boundaries = []  # (start_line_index, file_path)
    for filepath in source_files:
        start_idx = len(all_lines)
        lines = read_source_lines(filepath)
        rel_path = filepath.relative_to(SOURCE_DIR)
        all_lines.extend(lines)
        all_lines.append("")  # 文件间空行
        file_boundaries.append((start_idx, len(all_lines), rel_path))

    total_lines = len(all_lines)
    print(f"总代码行数: {total_lines}")

    # 计算需要多少页
    total_needed_lines = LINES_PER_PAGE * TOTAL_PAGES
    print(f"需要 {TOTAL_PAGES} 页 x {LINES_PER_PAGE}行 = {total_needed_lines} 行")

    if total_lines < total_needed_lines:
        print(f"⚠️ 代码不足 {total_needed_lines} 行，将提交全部代码")
        first_lines = all_lines
        last_lines = []
    else:
        # 前30页：取前 FIRST_HALF * LINES_PER_PAGE 行
        first_count = FIRST_HALF * LINES_PER_PAGE
        first_lines = all_lines[:first_count]

        # 后30页：取最后 SECOND_HALF * LINES_PER_PAGE 行
        last_count = SECOND_HALF * LINES_PER_PAGE
        last_lines = all_lines[-last_count:]

    print(f"前{FIRST_HALF}页: {len(first_lines)} 行")
    print(f"后{SECOND_HALF}页: {len(last_lines)} 行")

    # 创建 PDF
    c = canvas.Canvas(str(OUTPUT_FILE), pagesize=A4)
    width, height = A4  # 595.27 x 841.89 points

    # 页边距
    margin_top = 20 * mm
    margin_bottom = 15 * mm
    margin_left = 18 * mm
    margin_right = 15 * mm

    usable_width = width - margin_left - margin_right
    usable_height = height - margin_top - margin_bottom

    # 计算实际可容纳行数
    actual_lines_per_page = int(usable_height / LINE_HEIGHT)
    if actual_lines_per_page < LINES_PER_PAGE:
        print(f"⚠️ 页面只能容纳 {actual_lines_per_page} 行，调整为该值")
    lines_per_page = min(LINES_PER_PAGE, actual_lines_per_page)

    # 页眉模板
    header_text = f"软件名称：{SOFTWARE_NAME}   版本号：{VERSION}"

    def draw_page(block_lines: list[str], start_page_num: int, block_label: str):
        """绘制一组页面"""
        page_num = 0
        line_idx = 0
        total_block_lines = len(block_lines)
        total_pages = (total_block_lines + lines_per_page - 1) // lines_per_page

        for p in range(total_pages):
            # 获取本页行
            page_start = p * lines_per_page
            page_end = min(page_start + lines_per_page, total_block_lines)
            page_lines = block_lines[page_start:page_end]

            # 不画第一页的空白页（没有代码行的页）
            if len(page_lines) == 0 or all(l.strip() == "" for l in page_lines):
                continue

            page_num = start_page_num + p

            # 页眉
            c.setFont(FONT_NAME, HEADER_FONT_SIZE)
            c.drawString(margin_left, height - margin_top + 5 * mm, header_text)
            c.drawRightString(width - margin_right, height - margin_top + 5 * mm, f"第 {page_num} 页")
            # 分隔线
            c.setStrokeGray(0.5)
            c.line(margin_left, height - margin_top + 3 * mm, width - margin_right, height - margin_top + 3 * mm)

            # 代码行
            y = height - margin_top
            c.setFont(FONT_NAME, FONT_SIZE)
            chars_per_line = int(usable_width / (FONT_SIZE * 0.6))  # 等宽字体估算

            for i, line in enumerate(page_lines):
                # 截断过长的行
                if len(line) > chars_per_line:
                    line = line[:chars_per_line - 3] + "..."
                # 替换 tab 为空格
                line = line.replace("\t", "    ")
                c.drawString(margin_left, y - (i + 1) * LINE_HEIGHT, line)

            c.showPage()

        return page_num + 1

    # 绘制前30页
    first_end_page = draw_page(first_lines, 1, "前")
    print(f"前部分结束于第 {first_end_page - 1} 页")

    # 绘制后30页（只有代码超过60页时才绘制）
    if last_lines:
        draw_page(last_lines, FIRST_HALF + 1, "后")
    else:
        # 如果总页数不到60页，后面补空白页（不需要，因为已经全部提交）
        pass

    c.save()
    print(f"\n✅ 源代码文档已生成: {OUTPUT_FILE}")
    print(f"   文件大小: {OUTPUT_FILE.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    generate_pdf()
