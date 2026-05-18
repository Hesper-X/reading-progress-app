import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/purchase_provider.dart';

/// Pro 升级页 — 按设计稿 08Pro 升级页.html 1:1 实现
class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  bool _buyLoading = false;
  bool _restoreLoading = false;

  Future<void> _buyPro() async {
    // 无网络检查
    // TODO: 集成 connectivity_plus 或平台网络状态检测

    // 已购买检查
    final purchase = context.read<PurchaseProvider>();
    if (purchase.isPro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('您已是 Pro 用户')),
        );
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _buyLoading = true);
    try {
      await purchase.setPro(true);
      if (mounted) {
        setState(() => _buyLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('恭喜解锁 Pro 版！'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _buyLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支付失败，请重试')),
        );
      }
    }
  }

  Future<void> _restorePurchase() async {
    setState(() => _restoreLoading = true);
    try {
      final purchase = context.read<PurchaseProvider>();
      await purchase.setPro(true);
      if (mounted) {
        setState(() => _restoreLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已恢复 Pro 版！'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _restoreLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恢复失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          '←',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '升级 Pro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // === Header ===
                      Column(
                        children: [
                          // 金色渐变徽章（设计稿1:1）
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFD700), Color(0xFFFFC700)],
                              ),
                            ),
                            child: const Text(
                              '✨ PRO',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '升级专业版',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '解锁全部功能，无限制记录',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xE6FFFFFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // === Limit Card（已添加书籍数）===
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              '5 / 5',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '已添加书籍',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xE6FFFFFF),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '免费版最多添加 5 本书',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xB3FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // === Features Card ===
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Pro 专业版功能',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF212529),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _ProFeatureItem(
                              icon: '📚',
                              title: '无限添加书籍',
                              desc: '摆脱 5 本限制，随心记录',
                            ),
                            const SizedBox(height: 16),
                            _ProFeatureItem(
                              icon: '📊',
                              title: '阅读生涯统计',
                              desc: '全部年份数据+年度对比趋势',
                            ),
                            const SizedBox(height: 16),
                            _ProFeatureItem(
                              icon: '🏆',
                              title: '我的阅读生涯',
                              desc: '多年数据累计，看见坚持的力量',
                            ),
                            const SizedBox(height: 16),
                            _ProFeatureItem(
                              icon: '🎉',
                              title: '自定义分享文案',
                              desc: '自由编辑分享文案，彰显个性',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // === Price Card ===
                      Container(
                        width: 280,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE066), Color(0xFFFFD43B)],
                          ),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              '原价 ¥30',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0x66000000),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '¥12',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '一次性付费，永久使用',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0x80000000),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // === 升级按钮 ===
                      SizedBox(
                        width: 280,
                        child: ElevatedButton(
                          onPressed: _buyLoading ? null : _buyPro,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _buyLoading ? const Color(0xFF495057) : const Color(0xFF1A1A2E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF495057),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _buyLoading
                              ? const Text(
                                  '处理中...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                )
                              : const Text(
                                  '立即升级 Pro',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // === 恢复购买 ===
                      GestureDetector(
                        onTap: _restoreLoading ? null : _restorePurchase,
                        child: Text(
                          _restoreLoading ? '恢复中...' : '已购买？恢复购买',
                          style: TextStyle(
                            fontSize: 13,
                            color: _restoreLoading
                                ? const Color(0x66FFFFFF)
                                : const Color(0xB3FFFFFF),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pro 功能项 — 设计稿: 左侧绿色勾圆圈 + 右侧emoji+标题 同排 + 描述
class _ProFeatureItem extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;

  const _ProFeatureItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 绿色勾圆圈（设计稿1:1）
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF51CF66).withValues(alpha: 0.1),
          ),
          child: Center(
            child: Icon(
              Icons.check,
              size: 16,
              color: const Color(0xFF51CF66),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // emoji + 标题 同排
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212529),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF868E96),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
