import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../providers/category_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  static const purple = Color(0xFF5D56AA);
  static const textColor = Color(0xFF23232B);

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
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: purple,
        foregroundColor: Colors.white,
        onPressed: () => editCategory(),
        icon: const Icon(Icons.add),
        label: const Text(
          'New category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: categoriesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: purple)),
        error: (error, _) {
          return ErrorView(message: 'Unable to load categories\n$error');
        },
        data: (items) {
          final filtered = items.where((category) {
            return category.type == selectedType &&
                category.name.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              const Text(
                'Organize your money',
                style: TextStyle(
                  color: textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create categories that match the way you earn and spend.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              _searchField(),
              const SizedBox(height: 12),
              _pageTypeTabs(),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                const EmptyView(
                  icon: Icons.category_outlined,
                  title: 'No categories found',
                  message:
                      'Create a category to keep your transactions organized.',
                )
              else
                ...filtered.map(_categoryItem),
            ],
          );
        },
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

    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          query = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search by category name',
        prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();

                  setState(() {
                    query = '';
                  });
                },
                icon: const Icon(Icons.clear),
              ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _pageTypeTabs() {
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
              label: 'Expenses',
              icon: Icons.north_east,
              selectedOverride: selectedType,
              onChanged: (value) {
                setState(() {
                  selectedType = value;
                });
              },
            ),
          ),
          Expanded(
            child: _typeTabButton(
              type: CategoryType.income,
              label: 'Income',
              icon: Icons.south_west,
              selectedOverride: selectedType,
              onChanged: (value) {
                setState(() {
                  selectedType = value;
                });
              },
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
    required ValueChanged<CategoryType> onChanged,
    CategoryType? selectedOverride,
  }) {
    final currentType = selectedOverride ?? selectedType;
    final isSelected = currentType == type;

    final color = type == CategoryType.expense
        ? const Color(0xFFE85E6F)
        : const Color(0xFF00A578);

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () {
        onChanged(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryItem(Category category) {
    final isIncome = category.type == CategoryType.income;

    final color = isIncome ? const Color(0xFF00A578) : const Color(0xFFE85E6F);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isIncome ? Icons.trending_up : Icons.category_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.isArchived
                      ? 'Archived category'
                      : isIncome
                      ? 'Income category'
                      : 'Expense category',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (category.isArchived)
            const Chip(
              label: Text('Archived'),
              visualDensity: VisualDensity.compact,
            )
          else
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  editCategory(category);
                }

                if (value == 'archive') {
                  archiveCategory(category);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
        ],
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
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * .82,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.existing == null
                        ? 'Create a category to organize your transactions.'
                        : 'Update the category information.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Category name',
                      hintText: 'Example: Groceries',
                      errorText: error,
                      prefixIcon: const Icon(Icons.label_outline),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (error != null) setState(() => error = null);
                    },
                    onSubmitted: (_) => save(),
                  ),
                  const SizedBox(height: 12),
                  _typeTabs(theme),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isClosing ? null : close,
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
                          onPressed: isClosing ? null : save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            widget.existing == null ? 'Create' : 'Save',
                          ),
                        ),
                      ),
                    ],
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _typeTab(theme, CategoryType.expense, 'Expense', Icons.north_east),
          _typeTab(theme, CategoryType.income, 'Income', Icons.south_west),
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

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: isClosing ? null : () => setState(() => selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? color : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
