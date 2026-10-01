import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  Color get purple => Theme.of(context).colorScheme.primary;
  Color get textColor => Theme.of(context).colorScheme.onSurface;

  final searchController = TextEditingController();

  CategoryType selectedType = CategoryType.expense;
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _legacyEditCategory([Category? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');

    final typeNotifier = ValueNotifier<CategoryType>(
      existing?.type ?? selectedType,
    );

    final errorNotifier = ValueNotifier<String?>(null);

    // Guards against a fast double-tap firing Navigator.pop twice, which
    // throws "Looking up a deactivated widget's ancestor is unsafe" once
    // the sheet is already mid-dismissal — this was the crash behind the
    // Flutter error page showing up on button taps.
    final isClosingNotifier = ValueNotifier<bool>(false);

    (String, CategoryType)? result;

    void closeSheet(
      BuildContext sheetContext, [
      (String, CategoryType)? value,
    ]) {
      if (isClosingNotifier.value || !sheetContext.mounted) return;
      isClosingNotifier.value = true;

      // Don't call FocusManager.unfocus() here. Popping the route already
      // disposes its FocusScopeNode, which shifts focus away and closes
      // the keyboard on its own. Manually unfocusing first raced against
      // that teardown and was the actual cause of both the earlier
      // '!_debugLocked' assertion and the '_dependents.isEmpty' one —
      // it tore down the focus/overlay tree out of step with the
      // Navigator's own InheritedElement cleanup.
      Navigator.of(sheetContext).pop(value);
    }

    try {
      result = await showModalBottomSheet<(String, CategoryType)>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (sheetContext) {
          final mediaQuery = MediaQuery.of(sheetContext);
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: Material(
                color: Theme.of(sheetContext).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: mediaQuery.size.height * .78,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    // The keyboard inset is already handled by the
                    // AnimatedPadding above. Adding mediaQuery.viewInsets.bottom
                    // here too was double-counting it, which is what pushed
                    // the button row out of place (or off-screen) whenever
                    // the keyboard was open.
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetHandle(context),
                        const SizedBox(height: 22),
                        Text(
                          existing == null
                              ? 'Create category'
                              : 'Edit category',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          existing == null
                              ? 'Create a category to organize your transactions.'
                              : 'Update the category information.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<String?>(
                          valueListenable: errorNotifier,
                          builder: (context, error, _) {
                            return TextField(
                              controller: nameController,
                              maxLength: 40,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Category name',
                                hintText: 'Example: Groceries',
                                errorText: error,
                                prefixIcon: Icon(
                                  Icons.label_outline,
                                  color: Theme.of(sheetContext)
                                      .colorScheme
                                      .primary,
                                ),
                                filled: true,
                                fillColor: Theme.of(sheetContext)
                                    .colorScheme
                                    .surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Theme.of(sheetContext)
                                        .colorScheme
                                        .primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (_) {
                                if (errorNotifier.value != null) {
                                  errorNotifier.value = null;
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _bottomSheetTypeTabs(typeNotifier: typeNotifier),
                        const SizedBox(height: 22),
                        ValueListenableBuilder<bool>(
                          valueListenable: isClosingNotifier,
                          builder: (context, isClosing, _) {
                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isClosing
                                        ? null
                                        : () => closeSheet(sheetContext),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: isClosing
                                        ? null
                                        : () {
                                            final name = nameController.text
                                                .trim();

                                            if (name.isEmpty) {
                                              errorNotifier.value =
                                                  'Enter a category name';
                                              return;
                                            }

                                            closeSheet(sheetContext, (
                                              name,
                                              typeNotifier.value,
                                            ));
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(sheetContext)
                                          .colorScheme
                                          .primary,
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: Text(
                                      existing == null ? 'Create' : 'Save',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      // The modal route future completes as soon as the pop animation starts.
      // Defer owned-resource cleanup until the overlay has finished removing
      // its inherited-widget dependents.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
        typeNotifier.dispose();
        errorNotifier.dispose();
        isClosingNotifier.dispose();
      });
    }

    if (result == null || !mounted) return;

    final now = DateTime.now();

    final category = Category(
      id: existing?.id ?? AppUtils.generateId(),
      name: result.$1,
      type: result.$2,
      icon: existing?.icon,
      color: existing?.color,
      isArchived: false,
      createdAt: existing?.createdAt ?? now,
    );

    final repository = ref.read(categoryRepositoryProvider);

    final operation = existing == null
        ? repository.addCategory(category)
        : repository.updateCategory(category);

    final outcome = await operation;

    if (!mounted) return;

    outcome.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (_) {
        ref.invalidate(allCategoriesProvider);
        ref.invalidate(categoriesByTypeProvider(CategoryType.expense));
        ref.invalidate(categoriesByTypeProvider(CategoryType.income));

        _showMessage(
          existing == null ? 'Category created' : 'Category updated',
        );
      },
    );
  }

  Future<void> editCategory([Category? existing]) async {
    final result = await showModalBottomSheet<(String, CategoryType)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _CategoryEditorSheet(
        existing: existing,
        initialType: existing?.type ?? selectedType,
      ),
    );

    if (result == null || !mounted) return;

    final now = DateTime.now();
    final category = Category(
      id: existing?.id ?? AppUtils.generateId(),
      name: result.$1,
      type: result.$2,
      icon: existing?.icon,
      color: existing?.color,
      isArchived: false,
      createdAt: existing?.createdAt ?? now,
    );

    final repository = ref.read(categoryRepositoryProvider);
    final outcome = existing == null
        ? await repository.addCategory(category)
        : await repository.updateCategory(category);

    if (!mounted) return;

    outcome.fold((failure) => _showMessage(failure.message), (_) {
      ref.invalidate(allCategoriesProvider);
      ref.invalidate(categoriesByTypeProvider(CategoryType.expense));
      ref.invalidate(categoriesByTypeProvider(CategoryType.income));
      _showMessage(existing == null ? 'Category created' : 'Category updated');
    });
  }

  Future<void> archiveCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Archive category?'),
          content: Text(
            '“${category.name}” will remain available on historical transactions.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: purple),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(categoryRepositoryProvider)
        .deleteCategory(category.id);

    if (!mounted) return;

    result.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (_) {
        ref.invalidate(allCategoriesProvider);
        _showMessage('Category archived');
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: .82),
        title: const Text(
          'Categories',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 2, bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4338CA).withValues(alpha: .3),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Material(
            color: const Color(0xFF4338CA),
            borderRadius: BorderRadius.circular(32),
            child: InkWell(
              onTap: () => editCategory(),
              borderRadius: BorderRadius.circular(32),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 21, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 9),
                    Text(
                      'New category',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _CategoriesBackdrop()),
          categoriesAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: scheme.primary)),
            error: (error, _) {
              return ErrorView(message: 'Unable to load categories\n$error');
            },
            data: (items) {
              final filtered = items.where((category) {
                return category.type == selectedType &&
                    category.name.toLowerCase().contains(query.toLowerCase());
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Organize your money',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: scheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6,
                          ),
                        ),
                      ),
                      _CategoryTotalBadge(count: items.length),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Create categories that match the way you earn and spend.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _searchField(),
                  const SizedBox(height: 16),
                  _pageTypeTabs(
                    expenseCount: items
                        .where(
                          (category) => category.type == CategoryType.expense,
                        )
                        .length,
                    incomeCount: items
                        .where(
                          (category) => category.type == CategoryType.income,
                        )
                        .length,
                  ),
                  const SizedBox(height: 18),
                  if (filtered.isEmpty)
                    EmptyView(
                      icon: query.isEmpty
                          ? Icons.category_outlined
                          : Icons.search_off_rounded,
                      title: query.isEmpty
                          ? 'No categories yet'
                          : 'No categories found',
                      message: query.isEmpty
                          ? 'Create a category to keep your transactions organized.'
                          : 'Try a different search term.',
                    )
                  else
                    ...filtered.map(
                      (category) => _categoryItem(
                        category,
                        transactions: transactionsAsync.valueOrNull,
                        activityLoading: transactionsAsync.isLoading,
                        activityError: transactionsAsync.hasError,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 4,
          child: Center(
            child: Container(
              width: 128,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(.20),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _searchField() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) => setState(() => query = value),
        style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search by category name',
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: .7),
          ),
          prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    searchController.clear();
                    setState(() => query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: scheme.primary.withValues(alpha: .5)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _pageTypeTabs({required int expenseCount, required int incomeCount}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeTabButton(
              type: CategoryType.expense,
              label: 'Expenses',
              count: expenseCount,
              icon: Icons.north_east_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _typeTabButton(
              type: CategoryType.income,
              label: 'Income',
              count: incomeCount,
              icon: Icons.south_west_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomSheetTypeTabs({
    required ValueNotifier<CategoryType> typeNotifier,
  }) {
    return ValueListenableBuilder<CategoryType>(
      valueListenable: typeNotifier,
      builder: (context, selected, _) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: _typeTabButton(
                  type: CategoryType.expense,
                  label: 'Expense',
                  count: null,
                  icon: Icons.north_east,
                  selectedOverride: selected,
                  onChanged: (value) {
                    typeNotifier.value = value;
                  },
                ),
              ),
              Expanded(
                child: _typeTabButton(
                  type: CategoryType.income,
                  label: 'Income',
                  count: null,
                  icon: Icons.south_west,
                  selectedOverride: selected,
                  onChanged: (value) {
                    typeNotifier.value = value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _typeTabButton({
    required CategoryType type,
    required String label,
    required IconData icon,
    required int? count,
    ValueChanged<CategoryType>? onChanged,
    CategoryType? selectedOverride,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentType = selectedOverride ?? selectedType;
    final isSelected = currentType == type;

    final typeColor = type == CategoryType.expense
        ? const Color(0xFFE85E6F)
        : const Color(0xFF00A578);

    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () {
        if (onChanged != null) {
          onChanged(type);
        } else {
          setState(() => selectedType = type);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .045),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected
                    ? typeColor.withValues(alpha: .10)
                    : scheme.surfaceContainerHighest.withValues(alpha: .75),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? typeColor : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                constraints: const BoxConstraints(minWidth: 25, minHeight: 25),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? typeColor.withValues(alpha: .12)
                      : scheme.surfaceContainerHighest.withValues(alpha: .75),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected ? typeColor : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryItem(
    Category category, {
    required List<Transaction>? transactions,
    required bool activityLoading,
    required bool activityError,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _categoryColor(category);
    final categoryTransactions =
        transactions
            ?.where((transaction) => transaction.categoryId == category.id)
            .toList() ??
        const [];
    final amount = categoryTransactions.fold<double>(
      0,
      (total, transaction) => total + transaction.amount,
    );
    final subtitle = category.isArchived
        ? 'Archived category'
        : activityLoading
        ? 'Loading activity...'
        : activityError
        ? 'Activity unavailable'
        : '${categoryTransactions.length} ${categoryTransactions.length == 1 ? 'transaction' : 'transactions'} • ${AppUtils.formatCurrency(amount)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(_categoryIcon(category), color: color, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: .82),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (category.isArchived)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.archive_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Category options',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'edit') editCategory(category);
                  if (value == 'archive') archiveCategory(category);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(Category category) {
    final storedColor = category.color;
    if (storedColor != null) {
      final hex = storedColor.replaceFirst('#', '');
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
      }
    }
    return category.type == CategoryType.income
        ? const Color(0xFF059669)
        : const Color(0xFF6366F1);
  }

  IconData _categoryIcon(Category category) {
    const icons = <String, IconData>{
      'restaurant': Icons.restaurant_rounded,
      'directions_car': Icons.directions_car_rounded,
      'shopping_bag': Icons.shopping_bag_rounded,
      'receipt': Icons.receipt_long_rounded,
      'local_hospital': Icons.local_hospital_rounded,
      'movie': Icons.movie_rounded,
      'school': Icons.school_rounded,
      'phone': Icons.phone_iphone_rounded,
      'home': Icons.home_rounded,
      'person': Icons.person_rounded,
      'local_gas_station': Icons.local_gas_station_rounded,
      'medication': Icons.medication_rounded,
      'shopping_cart': Icons.shopping_cart_rounded,
      'local_grocery_store': Icons.local_grocery_store_rounded,
      'local_drink': Icons.local_drink_rounded,
      'category': Icons.category_rounded,
      'attach_money': Icons.attach_money_rounded,
      'work_outline': Icons.work_outline_rounded,
      'card_giftcard': Icons.card_giftcard_rounded,
      'trending_up': Icons.trending_up_rounded,
      'savings': Icons.savings_rounded,
    };
    return icons[category.icon] ??
        (category.type == CategoryType.income
            ? Icons.account_balance_wallet_outlined
            : Icons.category_outlined);
  }
}

class _CategoryTotalBadge extends StatelessWidget {
  const _CategoryTotalBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '$count Total',
        style: theme.textTheme.labelLarge?.copyWith(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoriesBackdrop extends StatelessWidget {
  const _CategoriesBackdrop();

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
          top: -70,
          left: -90,
          child: _glowOrb(colors.primary.withValues(alpha: .14), 270),
        ),
        Positioned(
          top: 250,
          right: -110,
          child: _glowOrb(colors.secondary.withValues(alpha: .10), 290),
        ),
      ],
    );
  }

  Widget _glowOrb(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({
    required this.existing,
    required this.initialType,
  });

  final Category? existing;
  final CategoryType initialType;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController nameController;
  late CategoryType selectedType;
  String? error;
  bool isClosing = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.existing?.name ?? '');
    selectedType = widget.initialType;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void close([(String, CategoryType)? result]) {
    if (isClosing || !mounted) return;
    setState(() => isClosing = true);
    Navigator.of(context).pop(result);
  }

  void save() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'Enter a category name');
      return;
    }
    close((name, selectedType));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final title = widget.existing == null ? 'Create category' : 'Edit category';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .97),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * .72,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -100,
                    right: -90,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: .12,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: .2,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: .1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.category_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: .48),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: TextField(
                            controller: nameController,
                            autofocus: true,
                            maxLength: 40,
                            textCapitalization: TextCapitalization.words,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Category name',
                              hintText: 'e.g. Groceries, Rent, Salary',
                              errorText: error,
                              prefixIcon: Icon(
                                Icons.edit_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.transparent,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: .55,
                                  ),
                                ),
                              ),
                            ),
                            onChanged: (_) {
                              if (error != null) setState(() => error = null);
                            },
                            onSubmitted: (_) => save(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'CATEGORY TYPE',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _typeTabs(theme),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isClosing ? null : close,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: isClosing ? null : save,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4338CA),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(46),
                                  shape: const StadiumBorder(),
                                ),
                                icon: const Icon(Icons.check_rounded),
                                label: Text(
                                  widget.existing == null ? 'Create' : 'Save',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeTabs(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          _typeTab(
            theme,
            CategoryType.expense,
            'Expense',
            Icons.north_east_rounded,
          ),
          _typeTab(
            theme,
            CategoryType.income,
            'Income',
            Icons.south_west_rounded,
          ),
        ],
      ),
    );
  }

  Widget _typeTab(
    ThemeData theme,
    CategoryType type,
    String label,
    IconData icon,
  ) {
    final selected = selectedType == type;
    final color = type == CategoryType.expense
        ? const Color(0xFFE85E6F)
        : const Color(0xFF00A578);
    final scheme = theme.colorScheme;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: isClosing ? null : () => setState(() => selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .045),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: .1)
                      : scheme.surface.withValues(alpha: .55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
