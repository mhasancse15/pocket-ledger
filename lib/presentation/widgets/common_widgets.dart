/// Widgets for Pocket Ledger
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetStatusCard extends StatelessWidget {
  final String month;
  final double spent;
  final double limit;
  final VoidCallback onPressed;

  const BudgetStatusCard({
    Key? key,
    required this.month,
    required this.spent,
    required this.limit,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = limit > 0 ? (spent / limit * 100) : 0.0;
    final remaining = limit - spent;
    final statusColor = _getStatusColor(percentage);
    final statusLabel = _getStatusLabel(percentage);

    return Card(
      elevation: 0,
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  month,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Budget Status',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(0)}% spent',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '৳${spent.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Limit: ৳${limit.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining >= 0 ? '৳${remaining.toStringAsFixed(2)} left' : '৳${remaining.toStringAsFixed(2)} over',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: remaining >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage < 75) return Colors.green;
    if (percentage < 90) return Colors.amber;
    if (percentage < 100) return Colors.orange;
    return Colors.red;
  }

  String _getStatusLabel(double percentage) {
    if (percentage < 75) return 'On Track';
    if (percentage < 90) return 'Warning';
    if (percentage < 100) return 'Critical';
    return 'Exceeded';
  }
}

class TransactionItemCard extends StatelessWidget {
  final String categoryName;
  final String categoryIcon;
  final String? note;
  final double amount;
  final bool isIncome;
  final String paymentMethod;
  final VoidCallback onTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  const TransactionItemCard({
    Key? key,
    required this.categoryName,
    required this.categoryIcon,
    this.note,
    required this.amount,
    this.isIncome = false,
    required this.paymentMethod,
    required this.onTap,
    this.onEditTap,
    this.onDeleteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final amountColor = isIncome ? Colors.green : Colors.red;
    final amountPrefix = isIncome ? '+' : '−';

    return Card(
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: amountColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.category,
              color: amountColor,
              size: 20,
            ),
          ),
        ),
        title: Text(categoryName),
        subtitle: Text(
          '$paymentMethod${note != null ? ' • ${note!}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix৳${amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEditTap != null)
                  GestureDetector(
                    onTap: onEditTap,
                    child: Icon(Icons.edit, size: 16, color: Colors.blue),
                  ),
                if (onEditTap != null && onDeleteTap != null)
                  const SizedBox(width: 8),
                if (onDeleteTap != null)
                  GestureDetector(
                    onTap: onDeleteTap,
                    child: Icon(Icons.delete, size: 16, color: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CategorySelectorChip extends StatelessWidget {
  final String categoryName;
  final bool isSelected;
  final VoidCallback onSelected;

  const CategorySelectorChip({
    Key? key,
    required this.categoryName,
    required this.isSelected,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(categoryName),
      selected: isSelected,
      onSelected: (_) => onSelected(),
    );
  }
}

class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  const MonthSelector({
    Key? key,
    required this.selectedMonth,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(selectedMonth);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final previousMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
                onMonthChanged(previousMonth);
              },
            ),
            Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final nextMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                );
                onMonthChanged(nextMonth);
              },
            ),
          ],
        ),
      ),
    );
  }
}
