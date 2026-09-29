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
    final primary = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : categoriesAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : categoriesAsync.hasError
          ? Center(
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
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Netflix subscription',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) => value?.trim().isEmpty ?? true
                          ? 'Enter a title.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
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
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '৳ ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value?.trim() ?? '');
                        return amount == null || amount <= 0
                            ? 'Enter an amount greater than ৳0.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _selectionField(
                      label: 'Expense category',
                      value: categoryLabel,
                      icon: Icons.category_outlined,
                      onTap: _saving ? null : () => _selectCategory(categories),
                    ),
                    const SizedBox(height: 12),
                    _selectionField(
                      label: 'Payment method',
                      value: _paymentMethodLabel(
                        PaymentMethod.values.byName(_paymentMethod),
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: _saving ? null : _selectPaymentMethod,
                    ),
                    const SizedBox(height: 12),
                    _selectionField(
                      label: 'Frequency',
                      value: _frequencyLabel(_frequency),
                      icon: Icons.repeat,
                      onTap: _saving ? null : _selectFrequency,
                    ),
                    if (_frequency == RecurringFrequency.monthly ||
                        _frequency == RecurringFrequency.quarterly)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          'Repeats on day $anchorDay '
                          'of the month.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 12),
                    _dateTile(
                      label: 'Starts',
                      value: DateFormat('d MMMM yyyy').format(_startDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: _saving ? null : () => _pickDate(isEndDate: false),
                    ),
                    const SizedBox(height: 10),
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
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      enabled: !_saving,
                      maxLines: 3,
                      maxLength: AppConstants.maxNoteLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatically create transaction'),
                      subtitle: const Text(
                        'Turn off to track the schedule without adding an expense automatically.',
                      ),
                      value: _autoCreate,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _autoCreate = value),
                    ),
                    const SizedBox(height: 8),
                    _selectionField(
                      label: 'Payment reminder',
                      value: _reminderLabel(_reminder),
                      icon: Icons.notifications_outlined,
                      onTap: _saving ? null : _selectReminder,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Saving...' : 'Save recurring rule',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: trailing ?? const Icon(Icons.calendar_month_outlined),
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
