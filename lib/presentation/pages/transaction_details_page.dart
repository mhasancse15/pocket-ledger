import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({
    required this.transactionId,
    super.key,
  });

  final String transactionId;

  static const Color purple = Color(0xFF5D56AA);
  static const Color background = Color(0xFFF7F7FB);
  static const Color darkText = Color(0xFF202027);
  static const Color mutedText = Color(0xFF72727D);
  static const Color borderColor = Color(0xFFE6E6EC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categories =
        ref.watch(allCategoriesProvider).valueOrNull ?? <Category>[];

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Transaction details',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          transactionsAsync.maybeWhen(
            data: (transactions) {
              final transaction = _findTransaction(transactions);

              if (transaction == null) {
                return const SizedBox.shrink();
              }

              return IconButton(
                tooltip: 'Edit transaction',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  context.pushNamed(
                    AppRoutes.editTransactionName,
                    pathParameters: {
                      'id': transaction.id,
                    },
                  );
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: purple,
          ),
        ),
        error: (error, stackTrace) => _ErrorView(
          message: 'Unable to load transaction\n$error',
        ),
        data: (transactions) {
          final transaction = _findTransaction(transactions);

          if (transaction == null) {
            return const _NotFoundView();
          }

          final categoryName =
              _findCategoryName(categories, transaction.categoryId) ??
                  transaction.categoryId;

          return _TransactionDetailsBody(
            transaction: transaction,
            categoryName: categoryName,
            onEdit: () {
              context.pushNamed(
                AppRoutes.editTransactionName,
                pathParameters: {
                  'id': transaction.id,
                },
              );
            },
          );
        },
      ),
    );
  }

  Transaction? _findTransaction(List<Transaction> items) {
    for (final item in items) {
      if (item.id == transactionId) {
        return item;
      }
    }

    return null;
  }

  String? _findCategoryName(
      List<Category> categories,
      String categoryId,
      ) {
    for (final category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }

    return null;
  }
}

class _TransactionDetailsBody extends StatelessWidget {
  const _TransactionDetailsBody({
    required this.transaction,
    required this.categoryName,
    required this.onEdit,
  });

  final Transaction transaction;
  final String categoryName;
  final VoidCallback onEdit;

  static const Color purple = Color(0xFF5D56AA);
  static const Color darkText = Color(0xFF202027);
  static const Color mutedText = Color(0xFF72727D);
  static const Color borderColor = Color(0xFFE6E6EC);

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final accentColor = isIncome
        ? const Color(0xFF079B73)
        : const Color(0xFFE35D68);

    final date = transaction.date.toLocal();
    final note = transaction.note?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _buildSummaryCard(
          context,
          isIncome: isIncome,
          accentColor: accentColor,
        ),
        const SizedBox(height: 18),
        const Text(
          'Transaction information',
          style: TextStyle(
            color: darkText,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _buildInformationCard(
          context,
          accentColor: accentColor,
          date: date,
          note: note,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: onEdit,
            style: FilledButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text(
              'Edit transaction',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, {
        required bool isIncome,
        required Color accentColor,
      }) {
    final amount =
        '${isIncome ? '+' : '-'}${AppUtils.formatCurrency(transaction.amount)}';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withOpacity(.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isIncome ? Icons.south_west : Icons.north_east,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIncome ? 'Income transaction' : 'Expense transaction',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Amount',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard(
      BuildContext context, {
        required Color accentColor,
        required DateTime date,
        required String? note,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.category_outlined,
            label: 'Category',
            value: categoryName,
            color: accentColor,
          ),
          const Divider(height: 1),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: DateFormat('d MMM yyyy').format(date),
            color: purple,
          ),
          const Divider(height: 1),
          _DetailRow(
            icon: Icons.access_time_outlined,
            label: 'Time',
            value: DateFormat('h:mm a').format(date),
            color: purple,
          ),
          const Divider(height: 1),
          _DetailRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payment method',
            value: _formatLabel(transaction.paymentMethod.name),
            color: purple,
          ),
          if (note != null && note.isNotEmpty) ...[
            const Divider(height: 1),
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Note',
              value: note,
              color: purple,
            ),
          ],
        ],
      ),
    );
  }

  String _formatLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
        .join(' ');
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  static const Color darkText = Color(0xFF202027);
  static const Color mutedText = Color(0xFF72727D);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Transaction not found',
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 52,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load transaction',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}