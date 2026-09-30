import 'package:flutter/material.dart';

import '../../core/utils/constants.dart';

class FinancialSummaryMetric {
  const FinancialSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class FinancialSummaryCard extends StatelessWidget {
  const FinancialSummaryCard({
    required this.label,
    required this.amount,
    required this.metrics,
    super.key,
  }) : assert(metrics.length >= 2 && metrics.length <= 3);

  final String label;
  final double amount;
  final List<FinancialSummaryMetric> metrics;

  static const Color _cardStart = Color(0xFF4338CA);
  static const Color _cardEnd = Color(0xFF712AE2);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 210,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_cardStart, _cardEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .20)),
        boxShadow: [
          BoxShadow(
            color: _cardStart.withValues(alpha: .24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -60,
            child: _circle(size: 155, opacity: .07),
          ),
          Positioned(
            right: 22,
            bottom: -78,
            child: _circle(size: 155, opacity: .05),
          ),
          Positioned(
            left: -65,
            bottom: -95,
            child: _circle(size: 170, opacity: .035),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'POCKET LEDGER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.25,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.contactless_outlined,
                      color: Colors.white70,
                      size: 25,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppUtils.formatCurrency(amount),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      if (index > 0) ...[
                        Container(
                          width: 1,
                          height: 35,
                          color: Colors.white.withValues(alpha: .20),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(child: _metric(metrics[index])),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle({required double size, required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _metric(FinancialSummaryMetric metric) {
    return Row(
      children: [
        Icon(metric.icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
