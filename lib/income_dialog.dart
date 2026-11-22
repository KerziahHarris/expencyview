import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Simple centered "add your income" pop-up: just the pay options and one
/// amount box (no breakdown). Shown after the budget is added when there is
/// no income yet.
Future<void> showIncomeDialog(BuildContext context, ExpenseStore store) =>
    showDialog<void>(
      context: context,
      builder: (_) => _IncomeDialog(store: store),
    );

class _IncomeDialog extends StatefulWidget {
  const _IncomeDialog({required this.store});

  final ExpenseStore store;

  @override
  State<_IncomeDialog> createState() => _IncomeDialogState();
}

class _IncomeDialogState extends State<_IncomeDialog> {
  late PayFrequency _frequency = widget.store.payFrequency;
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_amount.text.replaceAll(RegExp(r'[,\$ ]'), ''));
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    widget.store
      ..setPayFrequency(_frequency)
      ..setPayAmount(v);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.pill,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Would you like to add your income?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'How do you get paid?',
                style: TextStyle(fontSize: 14, color: c.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in PayFrequency.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: _frequency == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _frequency = f),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('income-amount'),
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: _frequency.amountLabel,
                  prefixText: '\$ ',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
