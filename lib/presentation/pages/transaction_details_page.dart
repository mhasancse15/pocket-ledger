import 'dart:ui';

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
  const TransactionDetailsPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categories =
        ref.watch(allCategoriesProvider).valueOrNull ?? <Category>[];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loadedTransaction = transactionsAsync.maybeWhen(
      data: _findTransaction,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 0,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: .82),
        title: Text(
          'Transaction details',
          style: theme.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            tooltip: 'Go back',
            onPressed: () => context.pop(),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surface.withValues(alpha: .88),
              foregroundColor: scheme.onSurface,
              fixedSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
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
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface.withValues(alpha: .88),
                  foregroundColor: scheme.onSurface,
                  fixedSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  context.pushNamed(
                    AppRoutes.editTransactionName,
                    pathParameters: {'id': transaction.id},
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
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (error, stackTrace) =>
            _ErrorView(message: 'Unable to load transaction\n$error'),
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
          );
        },
      ),
      bottomNavigationBar: loadedTransaction == null
          ? null
          : _TransactionDetailsFooter(
              onEdit: () {
                context.pushNamed(
                  AppRoutes.editTransactionName,
                  pathParameters: {'id': loadedTransaction.id},
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

  String? _findCategoryName(List<Category> categories, String categoryId) {
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
  });

  final Transaction transaction;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final accentColor = isIncome
        ? const Color(0xFF059669)
        : const Color(0xFFE11D48);
    final theme = Theme.of(context);

    return Stack(
      children: [
        const Positioned.fill(child: _TransactionDetailsBackdrop()),
        SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            children: [
              _buildSummaryCard(
                context,
                isIncome: isIncome,
                accentColor: accentColor,
              ),
              const SizedBox(height: 23),
              Text(
                'Transaction information',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: 12),
              _buildInformationCard(
                context,
                accentColor: accentColor,
                date: transaction.date.toLocal(),
                note: transaction.note?.trim(),
              ),
            ],
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
    final gradientColors = isIncome
        ? [const Color(0xFF10B981), const Color(0xFF047857)]
        : [const Color(0xFFFF6B7A), const Color(0xFFE11D48)];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
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
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .24),
                  ),
                ),
                child: Icon(
                  isIncome ? Icons.south_west : Icons.north_east,
                  color: Theme.of(context).colorScheme.surface,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isIncome ? 'Income transaction' : 'Expense transaction',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .8,
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
                fontSize: 38,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
            color: Theme.of(context).colorScheme.primary,
            tint: const Color(0xFF4F46E5),
          ),
          const Divider(height: 1),
          _DetailRow(
            icon: Icons.access_time_outlined,
            label: 'Time',
            value: DateFormat('h:mm a').format(date),
            color: Theme.of(context).colorScheme.primary,
            tint: const Color(0xFF8B5CF6),
          ),
          const Divider(height: 1),
          _DetailRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payment method',
            value: _formatLabel(transaction.paymentMethod.name),
            color: const Color(0xFF0284C7),
            tint: const Color(0xFF0284C7),
          ),
          if (note != null && note.isNotEmpty) ...[
            const Divider(height: 1),
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Note',
              value: note,
              color: const Color(0xFF9333EA),
              tint: const Color(0xFF9333EA),
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
    this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (tint ?? color).withValues(alpha: .09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (tint ?? color).withValues(alpha: .1)),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
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

class _TransactionDetailsFooter extends StatelessWidget {
  const _TransactionDetailsFooter({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: .94),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .25)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  'Edit transaction',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 128,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
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
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TransactionDetailsBackdrop extends StatelessWidget {
  const _TransactionDetailsBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        Positioned(
          top: -60,
          left: -90,
          child: _orb(const Color(0xFFFF8A9B).withValues(alpha: .15), 260),
        ),
        Positioned(
          top: 180,
          right: -120,
          child: _orb(colors.primary.withValues(alpha: .13), 290),
        ),
      ],
    );
  }

  Widget _orb(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Unable to load transaction',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
