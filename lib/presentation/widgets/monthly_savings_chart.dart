import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/monthly_saving.dart';

class MonthlySavingsChart extends StatelessWidget {
  const MonthlySavingsChart({
    required this.entries,
    required this.year,
    required this.endMonth,
    required this.monthCount,
    super.key,
  });

  final List<MonthlySavingEntry> entries;
  final int year;
  final int endMonth;
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    final totals = List<double>.generate(monthCount, (index) {
      final month = DateTime(year, endMonth - (monthCount - 1 - index));
      return entries
          .where(
            (entry) => entry.year == month.year && entry.month == month.month,
          )
          .fold<double>(0, (sum, entry) => sum + entry.amount);
    });
    final maxValue = totals.fold<double>(0, math.max);
    final maxY = maxValue == 0 ? 100.0 : maxValue * 1.2;
    final interval = maxY / 4;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 16, 14),
        child: SizedBox(
          height: 245,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, _, rod, _) {
                    final month = DateTime(
                      year,
                      endMonth - (monthCount - 1 - group.x),
                    );
                    return BarTooltipItem(
                      '${DateFormat('MMMM yyyy').format(month)}\n'
                      '${AppUtils.formatCurrency(rod.toY)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: interval,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Text(
                        _compactAmount(value),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      if (index < 0 || index >= monthCount) {
                        return const SizedBox.shrink();
                      }
                      final month = DateTime(
                        year,
                        endMonth - (monthCount - 1 - index),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('MMM').format(month),
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var index = 0; index < totals.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: totals[index],
                        width: monthCount > 8 ? 12 : 20,
                        borderRadius: BorderRadius.circular(5),
                        color: theme.colorScheme.primary.withValues(
                          alpha: index == totals.length - 1 ? 1 : 0.62,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _compactAmount(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}
