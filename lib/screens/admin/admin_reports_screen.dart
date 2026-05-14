import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naham_app/core/theme/app_theme.dart';
import 'package:naham_app/models/admin_report_model.dart';
import 'package:naham_app/services/backend/backend_admin_report_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final BackendAdminReportService _reportService = BackendAdminReportService();

  AdminReportSnapshot? _report;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final report = await _reportService.loadReport();
      if (!mounted) return;
      setState(() {
        _report = report;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F8),
        body: Column(
          children: [
            const _ReportsHeader(),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final report = _report;
    if (_isLoading && report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && report == null) {
      return _ReportMessageState(
        message: 'Failed to load reports: $_errorMessage',
        actionLabel: 'Retry',
        onAction: _loadReport,
      );
    }

    final resolvedReport = report ?? AdminReportSnapshot.empty();
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              _InlineReportError(
                message: _errorMessage!,
                onRetry: _loadReport,
              ),
              const SizedBox(height: 10),
            ],
            _buildTopMetricsSection(resolvedReport),
            const SizedBox(height: 10),
            _buildRevenuePerformanceCard(resolvedReport),
            const SizedBox(height: 10),
            _buildMonthGrowthTable(resolvedReport),
            const SizedBox(height: 10),
            _buildTopPerformerSection(resolvedReport),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMetricsSection(AdminReportSnapshot report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Revenue (Mo)',
                  value: _formatCompact(report.monthRevenue),
                  suffix: 'SAR',
                  change: _formatChange(report.revenueChangePercent),
                  changeTone: _changeTone(report.revenueChangePercent),
                  icon: Icons.attach_money_rounded,
                  iconColor: const Color(0xFF7B66EA),
                  valueColor: const Color(0xFF232A36),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Net Profit',
                  value: _formatCompact(report.netProfit),
                  suffix: 'SAR',
                  change: _formatChange(report.netProfitChangePercent),
                  changeTone: _changeTone(report.netProfitChangePercent),
                  icon: Icons.monitor_heart_outlined,
                  iconColor: Colors.white,
                  valueColor: Colors.white,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Total Orders',
                  value: '${report.totalOrders}',
                  change: _formatChange(report.ordersChangePercent),
                  changeTone: _changeTone(report.ordersChangePercent),
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF4E8BFF),
                  valueColor: const Color(0xFF232A36),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Loss / Refunds',
                  value: _formatCompact(report.lossRefunds),
                  suffix: 'SAR',
                  change: _formatChange(report.lossRefundsChangePercent),
                  changeTone: _changeTone(
                    report.lossRefundsChangePercent,
                    inverse: true,
                  ),
                  icon: Icons.report_gmailerrorred_outlined,
                  iconColor: const Color(0xFFFF6060),
                  valueColor: const Color(0xFFE23636),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PaymentMixCard(
            onlinePercent: report.onlinePaymentPercent,
            cashPercent: report.cashPaymentPercent,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenuePerformanceCard(AdminReportSnapshot report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: Color(0xFF725EF0),
              ),
              const SizedBox(width: 6),
              Text(
                'Revenue Performance (Daily)',
                style: GoogleFonts.poppins(
                  fontSize: 14.2,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF303848),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _RevenueChartPainter(points: report.dailyRevenuePoints),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEF1F6)),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _ChartFooterMetric(
                    label: 'HIGHEST DAY',
                    value: '${_formatAmount(report.highestDay.revenue)}\nSAR',
                    day: report.highestDay.dayLabel,
                    valueColor: const Color(0xFF1BB263),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFEEF1F6),
                ),
                Expanded(
                  child: _ChartFooterMetric(
                    label: 'LOWEST DAY',
                    value: '${_formatAmount(report.lowestDay.revenue)}\nSAR',
                    day: report.lowestDay.dayLabel,
                    valueColor: const Color(0xFFE24949),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrowthTable(AdminReportSnapshot report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month-over-Month Growth',
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2F3746),
            ),
          ),
          const SizedBox(height: 8),
          _buildGrowthHeader(),
          const SizedBox(height: 4),
          for (int i = 0; i < report.monthGrowth.length; i++) ...[
            _buildGrowthRow(report.monthGrowth[i]),
            if (i != report.monthGrowth.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F6)),
          ],
        ],
      ),
    );
  }

  Widget _buildGrowthHeader() {
    return Row(
      children: [
        _tableHeaderCell('Month', flex: 3),
        _tableHeaderCell('Revenue', flex: 3),
        _tableHeaderCell('Profit', flex: 2, alignEnd: true),
        _tableHeaderCell('Growth', flex: 2, alignEnd: true),
      ],
    );
  }

  Widget _tableHeaderCell(
    String text, {
    required int flex,
    bool alignEnd = false,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12.3,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8A92A1),
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthRow(AdminReportMonthRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.monthLabel,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4E5665),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _formatCompact(row.revenue),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF5D6574),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatCompact(row.profit),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6E5AF0),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _changeTone(row.growthPercent).background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatChange(row.growthPercent),
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _changeTone(row.growthPercent).foreground,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformerSection(AdminReportSnapshot report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP PERFORMERS RANKING',
            style: GoogleFonts.poppins(
              fontSize: 23 / 1.4,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF61697A),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EAF0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PerformerTab(
                    selected: true,
                    label: 'Cooks Performance',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _RankingCard(
            title: 'TOP 5 BY REVENUE',
            icon: Icons.attach_money_rounded,
            items: report.topCooksByRevenue
                .map(
                  (item) => _RankItem(
                    name: item.name,
                    value: '${_formatAmount(item.value)} SAR',
                  ),
                )
                .toList(growable: false),
            valueColor: const Color(0xFF6E5AF0),
          ),
          const SizedBox(height: 10),
          _RankingCard(
            title: 'MOST ACTIVE (ORDERS)',
            icon: Icons.show_chart_rounded,
            items: report.topCooksByOrders
                .map(
                  (item) => _RankItem(
                    name: item.name,
                    value: '${item.value.round()} Orders',
                  ),
                )
                .toList(growable: false),
            valueColor: const Color(0xFF2E3442),
          ),
        ],
      ),
    );
  }

  String _formatCompact(double value) {
    final absolute = value.abs();
    if (absolute >= 1000000) {
      return '${_trimDecimal(value / 1000000)}m';
    }
    if (absolute >= 1000) {
      return '${_trimDecimal(value / 1000)}k';
    }
    return _formatAmount(value);
  }

  String _formatAmount(double value) {
    final rounded = value.round();
    if ((value - rounded).abs() < 0.01) {
      return _withThousands(rounded);
    }
    return _withThousands(value).replaceAll(RegExp(r'\.0$'), '');
  }

  String _formatChange(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${_trimDecimal(value)}%';
  }

  String _trimDecimal(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.05) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _withThousands(num value) {
    final negative = value < 0;
    final normalized = value.abs();
    final whole = normalized.truncate().toString();
    final fraction = normalized is double && normalized % 1 != 0
        ? normalized.toStringAsFixed(2).split('.').last
        : '';
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return '${negative ? '-' : ''}$buffer${fraction.isEmpty ? '' : '.$fraction'}';
  }

  _ChangeTone _changeTone(double value, {bool inverse = false}) {
    final isPositive = value >= 0;
    final isGood = inverse ? !isPositive : isPositive;
    if (isGood) {
      return const _ChangeTone(
        background: Color(0xFFDDF7E8),
        foreground: Color(0xFF1CA75A),
      );
    }
    return const _ChangeTone(
      background: Color(0xFFFFE6E6),
      foreground: Color(0xFFE24949),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(10, topPadding + 8, 10, 12),
      decoration: const BoxDecoration(
        color: AppColors.homeChrome,
        boxShadow: [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            splashRadius: 22,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'Reports',
              style: GoogleFonts.poppins(
                fontSize: 30 / 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMessageState extends StatelessWidget {
  const _ReportMessageState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFB00020),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineReportError extends StatelessWidget {
  const _InlineReportError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD6D6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFE24949),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9D2A2A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE24949),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeTone {
  const _ChangeTone({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    required this.changeTone,
    this.suffix,
    this.isHighlighted = false,
  });

  final String title;
  final String value;
  final String change;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;
  final _ChangeTone changeTone;
  final String? suffix;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        gradient: isHighlighted
            ? const LinearGradient(
                colors: [Color(0xFF7867F0), Color(0xFF6853E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isHighlighted ? null : const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? Colors.transparent : const Color(0xFFE8EBF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withValues(alpha: 0.20)
                      : iconColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withValues(alpha: 0.18)
                      : changeTone.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  change,
                  style: GoogleFonts.poppins(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted ? Colors.white : changeTone.foreground,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12.2,
              color: isHighlighted
                  ? Colors.white.withValues(alpha: 0.92)
                  : const Color(0xFF8B93A2),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 29 / 1.32,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              if (suffix != null && suffix!.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  suffix!,
                  style: GoogleFonts.poppins(
                    fontSize: 12.2,
                    color: isHighlighted
                        ? Colors.white.withValues(alpha: 0.88)
                        : const Color(0xFFA0A8B7),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMixCard extends StatelessWidget {
  const _PaymentMixCard({
    required this.onlinePercent,
    required this.cashPercent,
  });

  final int onlinePercent;
  final int cashPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EBF1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 330;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressBar(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _LegendDot(
                      color: const Color(0xFF705BEE),
                      label: '$onlinePercent% Online',
                    ),
                    _LegendDot(
                      color: const Color(0xFF26C2A6),
                      label: '$cashPercent% Cash',
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _PaymentProgressBar(
                  onlinePercent: onlinePercent,
                  cashPercent: cashPercent,
                ),
              ),
              const SizedBox(width: 10),
              _LegendDot(
                color: const Color(0xFF705BEE),
                label: '$onlinePercent% Online',
              ),
              const SizedBox(width: 8),
              _LegendDot(
                color: const Color(0xFF26C2A6),
                label: '$cashPercent% Cash',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() => _PaymentProgressBar(
        onlinePercent: onlinePercent,
        cashPercent: cashPercent,
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.4,
            color: const Color(0xFF5E6676),
            height: 1.05,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ChartFooterMetric extends StatelessWidget {
  const _ChartFooterMetric({
    required this.label,
    required this.value,
    required this.day,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String day;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.3,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFA4ACB9),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            day,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFA4ACB9),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentProgressBar extends StatelessWidget {
  const _PaymentProgressBar({
    required this.onlinePercent,
    required this.cashPercent,
  });

  final int onlinePercent;
  final int cashPercent;

  @override
  Widget build(BuildContext context) {
    if (onlinePercent <= 0 && cashPercent <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: const SizedBox(
          height: 10,
          child: ColoredBox(color: Color(0xFFE3E7EE)),
        ),
      );
    }
    if (cashPercent <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: const SizedBox(
          height: 10,
          child: ColoredBox(color: Color(0xFF705BEE)),
        ),
      );
    }
    if (onlinePercent <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: const SizedBox(
          height: 10,
          child: ColoredBox(color: Color(0xFF26C2A6)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: onlinePercent.clamp(1, 100),
              child: const ColoredBox(color: Color(0xFF705BEE)),
            ),
            Expanded(
              flex: cashPercent.clamp(1, 100),
              child: const ColoredBox(color: Color(0xFF26C2A6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformerTab extends StatelessWidget {
  const _PerformerTab({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16 / 1.3,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF4A5160)
                    : const Color(0xFF747D8D),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.valueColor,
  });

  final String title;
  final IconData icon;
  final List<_RankItem> items;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF9CA4B3)),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12.4,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF707888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No cook data yet',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF9CA4B3),
                ),
              ),
            )
          else
            for (int i = 0; i < items.length; i++) ...[
              _RankRow(
                rank: i + 1,
                name: items[i].name,
                value: items[i].value,
                valueColor: valueColor,
              ),
              if (i != items.length - 1)
                const Divider(
                  height: 10,
                  thickness: 1,
                  color: Color(0xFFF0F2F6),
                ),
            ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.valueColor,
  });

  final int rank;
  final String name;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFEEEAFD),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontSize: 11.3,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7D68EE),
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4E5665),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  const _RevenueChartPainter({required this.points});

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(0, 6, size.width, size.height - 12);
    final paint = Paint()
      ..color = const Color(0xFF7A67F0)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length < 2) return;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = chartRect.left + (chartRect.width * i / (points.length - 1));
      final normalized = points[i].clamp(0.0, 1.0);
      final y = chartRect.bottom - (chartRect.height * normalized);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX =
            chartRect.left + (chartRect.width * (i - 1) / (points.length - 1));
        final prevY = chartRect.bottom -
            (chartRect.height * points[i - 1].clamp(0.0, 1.0));
        final midX = (prevX + x) / 2;
        path.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);
        if (i == points.length - 1) {
          path.quadraticBezierTo(x, y, x, y);
        }
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}

class _RankItem {
  const _RankItem({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;
}
