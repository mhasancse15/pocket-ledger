import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/monthly_limit.dart';

class MonthlyTargetEditorResult {
  const MonthlyTargetEditorResult.save(this.amount) : remove = false;

  const MonthlyTargetEditorResult.remove() : amount = null, remove = true;

  final double? amount;
  final bool remove;
}

class MonthlyTargetEditorSheet extends StatefulWidget {
  const MonthlyTargetEditorSheet({
    required this.month,
    required this.current,
    super.key,
  });

  final DateTime month;
  final MonthlyLimit? current;

  @override
  State<MonthlyTargetEditorSheet> createState() =>
      _MonthlyTargetEditorSheetState();
}

class _MonthlyTargetEditorSheetState extends State<MonthlyTargetEditorSheet> {
  late final TextEditingController controller;
  String? error;
  bool isClosing = false;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.current?.amount.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    final amount = double.tryParse(controller.text.trim());

    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => error = 'Enter an amount greater than ৳0.');
      return;
    }

    close(MonthlyTargetEditorResult.save(amount));
  }

  void close([MonthlyTargetEditorResult? result]) {
    if (isClosing || !mounted) return;
    setState(() => isClosing = true);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardInset + 24),
            children: [
              Text(
                'Monthly expense target',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('MMMM yyyy').format(widget.month),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Target amount',
                  prefixText: '৳ ',
                  prefixIcon: const Icon(Icons.track_changes_outlined),
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
                onSubmitted: (_) => save(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isClosing ? null : save,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save target'),
                ),
              ),
              if (widget.current != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isClosing
                        ? null
                        : () => close(const MonthlyTargetEditorResult.remove()),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove target'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
