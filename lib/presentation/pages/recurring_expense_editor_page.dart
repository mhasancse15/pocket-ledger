import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/local_notification_service.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';

class RecurringExpenseEditorPage extends ConsumerStatefulWidget {
  const RecurringExpenseEditorPage({this.ruleId, super.key});

  final String? ruleId;

  @override
  ConsumerState<RecurringExpenseEditorPage> createState() =>
      _RecurringExpenseEditorPageState();
}

class _RecurringExpenseEditorPageState
    extends ConsumerState<RecurringExpenseEditorPage> {
  static const _uuid = Uuid();
  static const _brandIndigo = Color(0xFF4338CA);
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  DateTime _startDate = _dateOnly(DateTime.now());
  DateTime? _endDate;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  String? _categoryId;
  String _paymentMethod = PaymentMethod.cash.name;
  bool _autoCreate = true;
  _ReminderOption _reminder = _ReminderOption.none;
  RecurringRule? _originalRule;
  bool _loading = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    final ruleId = widget.ruleId;
    if (ruleId != null) _loadRule(ruleId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadRule(String id) async {
    setState(() => _loading = true);
    try {
      final rule = await ref.read(recurringRuleProvider(id).future);
      if (!mounted) return;
      if (rule == null) {
        setState(() {
          _loadError = 'Recurring rule not found.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _originalRule = rule;
        _titleController.text = rule.title;
        _amountController.text = rule.amount.toStringAsFixed(2);
        _noteController.text = rule.note ?? '';
        _startDate = _dateOnly(rule.startDate);
        _endDate = rule.endDate == null ? null : _dateOnly(rule.endDate!);
        _frequency = rule.frequency;
        _categoryId = rule.categoryId;
        _paymentMethod = rule.paymentMethod;
        _autoCreate = rule.autoCreateTransaction;
        _reminder = _reminderOption(rule.reminderDays);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Unable to load recurring rule: $error';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isEndDate}) async {
    final initialDate = isEndDate ? _endDate ?? _startDate : _startDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      helpText: isEndDate ? 'Select end date' : 'Select start date',
    );
    if (pickedDate == null || !mounted) return;
    setState(() {
      if (isEndDate) {
        _endDate = _dateOnly(pickedDate);
      } else {
        _startDate = _dateOnly(pickedDate);
      }
    });
  }

  Future<void> _selectCategory(List<Category> categories) async {
    final selected = await _showPicker<String>(
      title: 'Expense category',
      subtitle: 'Choose a category for this recurring expense.',
      selectedValue: _categoryId,
      options: categories
          .map(
            (category) => _EditorPickerOption(
              value: category.id,
              title: category.name,
              subtitle: category.isArchived
                  ? 'Archived category'
                  : 'Expense category',
              icon: Icons.category_outlined,
            ),
          )
          .toList(),
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryId = selected);
  }

  Future<void> _selectPaymentMethod() async {
    final selected = await _showPicker<String>(
      title: 'Payment method',
      subtitle: 'Choose how this expense is usually paid.',
      selectedValue: _paymentMethod,
      options: PaymentMethod.values
          .map(
            (method) => _EditorPickerOption(
              value: method.name,
              title: _paymentMethodLabel(method),
              subtitle: 'Payment method',
              icon: Icons.account_balance_wallet_outlined,
            ),
          )
          .toList(),
    );
    if (selected == null || !mounted) return;
    setState(() => _paymentMethod = selected);
  }

  Future<void> _selectFrequency() async {
    final selected = await _showPicker<RecurringFrequency>(
      title: 'Frequency',
      subtitle: 'Choose how often this expense repeats.',
      selectedValue: _frequency,
      options: _frequencies
          .map(
            (frequency) => _EditorPickerOption(
              value: frequency,
              title: _frequencyLabel(frequency),
              subtitle: _frequencySubtitle(frequency),
              icon: Icons.repeat,
            ),
          )
          .toList(),
    );
    if (selected == null || !mounted) return;
    setState(() => _frequency = selected);
  }

  Future<void> _selectReminder() async {
    final selected = await _showPicker<_ReminderOption>(
      title: 'Payment reminder',
      subtitle: 'Choose when to receive a local reminder.',
      selectedValue: _reminder,
      options: const [
        _EditorPickerOption(
          value: _ReminderOption.none,
          title: 'No reminder',
          subtitle: 'Do not send a notification',
          icon: Icons.notifications_off_outlined,
        ),
        _EditorPickerOption(
          value: _ReminderOption.dueDate,
          title: 'On the due date',
          subtitle: 'Notify at 9:00 AM',
          icon: Icons.event_available_outlined,
        ),
        _EditorPickerOption(
          value: _ReminderOption.oneDayBefore,
          title: '1 day before',
          subtitle: 'Notify at 9:00 AM',
          icon: Icons.notifications_active_outlined,
        ),
        _EditorPickerOption(
          value: _ReminderOption.threeDaysBefore,
          title: '3 days before',
          subtitle: 'Notify at 9:00 AM',
          icon: Icons.notifications_active_outlined,
        ),
        _EditorPickerOption(
          value: _ReminderOption.sevenDaysBefore,
          title: '7 days before',
          subtitle: 'Notify at 9:00 AM',
          icon: Icons.notifications_active_outlined,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _reminder = selected);
  }

  Future<T?> _showPicker<T>({
    required String title,
    required String subtitle,
    required T? selectedValue,
    required List<_EditorPickerOption<T>> options,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No options available.')),
              ),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: option.value == selectedValue
                      ? theme.colorScheme.primary.withValues(alpha: .08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => Navigator.of(sheetContext).pop(option.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: .1,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              option.icon,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  option.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            option.value == selectedValue
                                ? Icons.check_circle
                                : Icons.chevron_right,
                            color: option.value == selectedValue
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _selectionField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _EditorSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              _EditorIcon(icon: icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      _message('Select an expense category.');
      return;
    }
    if (_endDate != null && !_endDate!.isAfter(_startDate)) {
      _message('End date must be after the start date.');
      return;
    }
    final amount = double.parse(_amountController.text.trim());
    final title = _titleController.text.trim();
    setState(() => _saving = true);
    try {
      if (_reminder != _ReminderOption.none) {
        final allowed = await LocalNotificationService.instance
            .requestPermission();
        if (!mounted) return;
        if (!allowed) {
          setState(() => _saving = false);
          _message('Notification permission is needed for this reminder.');
          return;
        }
      }

      final existingRules = await ref.read(allRecurringRulesProvider.future);
      if (!mounted) return;
      final duplicate = existingRules.any(
        (rule) =>
            rule.id != _originalRule?.id &&
            rule.isActive &&
            rule.title.trim().toLowerCase() == title.toLowerCase() &&
            rule.amount == amount &&
            rule.categoryId == _categoryId &&
            rule.paymentMethod == _paymentMethod &&
            rule.frequency == _frequency &&
            _dateOnly(rule.startDate) == _startDate,
      );
      if (duplicate) {
        setState(() => _saving = false);
        _message('An identical active recurring rule already exists.');
        return;
      }

      final now = DateTime.now();
      final original = _originalRule;
      final ruleId = original?.id ?? _uuid.v4();
      final scheduleChanged =
          original == null ||
          original.frequency != _frequency ||
          _dateOnly(original.startDate) != _startDate;
      final rule = RecurringRule(
        id: ruleId,
        title: title,
        amount: amount,
        categoryId: _categoryId!,
        paymentMethod: _paymentMethod,
        frequency: _frequency,
        startDate: _startDate,
        nextOccurrenceDate: scheduleChanged
            ? _startDate
            : original.nextOccurrenceDate,
        anchorDay: scheduleChanged ? _startDate.day : original.anchorDay,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        endDate: _endDate,
        isActive: original?.isActive ?? true,
        autoCreateTransaction: _autoCreate,
        lastGeneratedAt: original?.lastGeneratedAt,
        reminderDays: _reminderDays,
        notificationId: _reminderDays == null
            ? null
            : LocalNotificationService.instance.recurringNotificationId(ruleId),
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
      );
      final notifier = ref.read(recurringNotifierProvider.notifier);
      if (original == null) {
        await notifier.addRecurringRule(rule);
      } else {
        await notifier.updateRecurringRule(rule);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Unable to save recurring rule: $error');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  void _addQuickAmount(double amount) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0;
    final updatedAmount = current + amount;
    final text = updatedAmount == updatedAmount.roundToDouble()
        ? updatedAmount.toStringAsFixed(0)
        : updatedAmount.toStringAsFixed(2);
    _amountController
      ..text = text
      ..selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoriesAsync = ref.watch(
      categoriesByTypeProvider(CategoryType.expense),
    );
    final matchingCategories =
        categoriesAsync.valueOrNull
            ?.where((category) => category.id == _categoryId)
            .toList() ??
        const <Category>[];
    final categoryLabel = matchingCategories.isEmpty
        ? 'Select a category'
        : matchingCategories.first.name;
    final original = _originalRule;
    final anchorDay =
        original != null &&
            original.frequency == _frequency &&
            _dateOnly(original.startDate) == _startDate
        ? original.anchorDay
        : _startDate.day;
    final categories =
        categoriesAsync.valueOrNull
            ?.where(
              (category) => !category.isArchived || category.id == _categoryId,
            )
            .toList() ??
        const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _originalRule == null ? 'Add recurring expense' : 'Edit rule',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _EditorBackdrop(isDark: theme.brightness == Brightness.dark),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (categoriesAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            )
          else if (categoriesAsync.hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load expense categories.'),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      categoriesByTypeProvider(CategoryType.expense),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else
            SafeArea(
              bottom: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  children: [
                    _titleField(theme),
                    const SizedBox(height: 9),
                    _amountField(theme),
                    const SizedBox(height: 9),
                    _selectionField(
                      label: 'Expense category',
                      value: categoryLabel,
                      icon: Icons.category_outlined,
                      onTap: _saving ? null : () => _selectCategory(categories),
                    ),
                    const SizedBox(height: 9),
                    _selectionField(
                      label: 'Payment method',
                      value: _paymentMethodLabel(
                        PaymentMethod.values.byName(_paymentMethod),
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: _saving ? null : _selectPaymentMethod,
                    ),
                    const SizedBox(height: 9),
                    _selectionField(
                      label: 'Frequency',
                      value: _frequencyLabel(_frequency),
                      icon: Icons.open_in_full_rounded,
                      onTap: _saving ? null : _selectFrequency,
                    ),
                    if (_frequency == RecurringFrequency.monthly ||
                        _frequency == RecurringFrequency.quarterly)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          'Repeats on day $anchorDay of the month.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 9),
                    _dateTile(
                      label: 'Starts',
                      value: DateFormat('d MMMM yyyy').format(_startDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: _saving ? null : () => _pickDate(isEndDate: false),
                    ),
                    const SizedBox(height: 8),
                    _dateTile(
                      label: 'Ends',
                      value: _endDate == null
                          ? 'No end date'
                          : DateFormat('d MMMM yyyy').format(_endDate!),
                      icon: Icons.event_busy_outlined,
                      onTap: _saving ? null : () => _pickDate(isEndDate: true),
                      trailing: _endDate == null
                          ? null
                          : IconButton(
                              tooltip: 'Remove end date',
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _endDate = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    const SizedBox(height: 9),
                    _noteField(theme),
                    const SizedBox(height: 9),
                    _autoCreateCard(theme),
                    const SizedBox(height: 9),
                    _selectionField(
                      label: 'Payment reminder',
                      value: _reminderLabel(_reminder),
                      icon: Icons.notifications_none_rounded,
                      onTap: _saving ? null : _selectReminder,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          _loading ||
              categoriesAsync.isLoading ||
              categoriesAsync.hasError ||
              _loadError != null
          ? null
          : _EditorSaveFooter(saving: _saving, onSave: _saving ? null : _save),
    );
  }

  Widget _titleField(ThemeData theme) {
    final scheme = theme.colorScheme;
    return _EditorSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          _EditorIcon(icon: Icons.title_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _titleController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Title (e.g. WiFi, Netflix, Gym)',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Enter a title.' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField(ThemeData theme) {
    final scheme = theme.colorScheme;
    return _EditorSurface(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              _EditorIcon(
                icon: Icons.credit_card_outlined,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '৳',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (value) {
                          final amount = double.tryParse(value?.trim() ?? '');
                          return amount == null || amount <= 0
                              ? 'Enter an amount greater than ৳0.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .38),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'QUICK:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(width: 7),
              for (final amount in [500.0, 1000.0, 5000.0]) ...[
                if (amount != 500) const SizedBox(width: 6),
                _QuickAmountChip(
                  amount: amount,
                  onTap: _saving ? null : () => _addQuickAmount(amount),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _noteField(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _EditorSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditorIcon(
                icon: Icons.notes_rounded,
                color: scheme.onSurfaceVariant,
                neutral: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _noteController,
                  enabled: !_saving,
                  maxLines: 2,
                  maxLength: AppConstants.maxNoteLength,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Note (optional)',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 3, right: 5),
          child: Text(
            '${_noteController.text.length}/${AppConstants.maxNoteLength}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _autoCreateCard(ThemeData theme) {
    final scheme = theme.colorScheme;
    return _EditorSurface(
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatically create transaction',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track the schedule without auto-adding expenses.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _autoCreate,
            activeTrackColor: _brandIndigo,
            onChanged: _saving
                ? null
                : (value) => setState(() => _autoCreate = value),
          ),
        ],
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _EditorSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              _EditorIcon(icon: icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.calendar_month_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  static const _frequencies = [
    RecurringFrequency.daily,
    RecurringFrequency.weekly,
    RecurringFrequency.monthly,
    RecurringFrequency.yearly,
    RecurringFrequency.quarterly,
  ];

  int? get _reminderDays => switch (_reminder) {
    _ReminderOption.none => null,
    _ReminderOption.dueDate => 0,
    _ReminderOption.oneDayBefore => 1,
    _ReminderOption.threeDaysBefore => 3,
    _ReminderOption.sevenDaysBefore => 7,
  };

  static _ReminderOption _reminderOption(int? days) => switch (days) {
    null => _ReminderOption.none,
    0 => _ReminderOption.dueDate,
    1 => _ReminderOption.oneDayBefore,
    3 => _ReminderOption.threeDaysBefore,
    7 => _ReminderOption.sevenDaysBefore,
    _ => _ReminderOption.none,
  };

  static String _frequencyLabel(RecurringFrequency frequency) =>
      switch (frequency) {
        RecurringFrequency.daily => 'Daily',
        RecurringFrequency.weekly => 'Weekly',
        RecurringFrequency.monthly => 'Monthly',
        RecurringFrequency.quarterly => 'Every 3 months',
        RecurringFrequency.yearly => 'Yearly',
      };

  static String _frequencySubtitle(RecurringFrequency frequency) =>
      switch (frequency) {
        RecurringFrequency.daily => 'Repeats every day',
        RecurringFrequency.weekly => 'Repeats every week',
        RecurringFrequency.monthly => 'Repeats monthly on the selected day',
        RecurringFrequency.quarterly => 'Repeats every three months',
        RecurringFrequency.yearly => 'Repeats every year',
      };

  static String _reminderLabel(_ReminderOption reminder) => switch (reminder) {
    _ReminderOption.none => 'No reminder',
    _ReminderOption.dueDate => 'On the due date',
    _ReminderOption.oneDayBefore => '1 day before',
    _ReminderOption.threeDaysBefore => '3 days before',
    _ReminderOption.sevenDaysBefore => '7 days before',
  };

  static String _paymentMethodLabel(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.bankTransfer => 'Bank transfer',
    PaymentMethod.debitCard => 'Debit card',
    PaymentMethod.creditCard => 'Credit card',
    PaymentMethod.mobileWallet => 'Mobile wallet',
    PaymentMethod.other => 'Other',
  };
}

enum _ReminderOption {
  none,
  dueDate,
  oneDayBefore,
  threeDaysBefore,
  sevenDaysBefore,
}

class _EditorSurface extends StatelessWidget {
  const _EditorSurface({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .92 : .96,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .12
                  : .035,
            ),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _EditorIcon extends StatelessWidget {
  const _EditorIcon({
    required this.icon,
    required this.color,
    this.neutral = false,
  });

  final IconData icon;
  final Color color;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: neutral
            ? scheme.surfaceContainerHighest.withValues(alpha: .65)
            : color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({required this.amount, required this.onTap});

  final double amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amountLabel = amount.toStringAsFixed(0);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            '+৳$amountLabel',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorBackdrop extends StatelessWidget {
  const _EditorBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [base, const Color(0xFF17182B), base]
              : [
                  const Color(0xFFF8F9FF),
                  const Color(0xFFF4F5FB),
                  const Color(0xFFF9FAFC),
                ],
        ),
      ),
    );
  }
}

class _EditorSaveFooter extends StatelessWidget {
  const _EditorSaveFooter({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: .96),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _RecurringExpenseEditorPageState._brandIndigo
                      .withValues(alpha: isDark ? .16 : .28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: _RecurringExpenseEditorPageState._brandIndigo,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _RecurringExpenseEditorPageState
                    ._brandIndigo
                    .withValues(alpha: .65),
                shape: const StadiumBorder(),
              ),
              child: saving
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Save recurring rule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorPickerOption<T> {
  const _EditorPickerOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final T value;
  final String title;
  final String subtitle;
  final IconData icon;
}
