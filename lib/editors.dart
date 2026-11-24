import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Bottom sheet for creating or editing a folder.
/// Pass [folder] to edit; omit it to create a new one of [initialType].
Future<void> showFolderEditor(
  BuildContext context,
  ExpenseStore store, {
  Folder? folder,
  FolderType initialType = FolderType.expense,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.pill,
    builder: (_) =>
        _FolderEditor(store: store, folder: folder, initialType: initialType),
  );
}

/// "New expense" / "New savings" / "New subscription".
String newItemLabel(FolderType t) => switch (t) {
  FolderType.expense => 'New expense',
  FolderType.savings => 'New savings',
  FolderType.subscription => 'New subscription',
  FolderType.budget => 'New budget item',
};

/// The container "+ Add" sheet: a switch between adding an item straight to
/// the container (default) or a new folder with the usual folder settings.
Future<void> showAddToContainer(
  BuildContext context,
  ExpenseStore store,
  FolderType type,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.pill,
    builder: (_) => _AddToContainer(store: store, type: type),
  );
}

class _AddToContainer extends StatefulWidget {
  const _AddToContainer({required this.store, required this.type});

  final ExpenseStore store;
  final FolderType type;

  @override
  State<_AddToContainer> createState() => _AddToContainerState();
}

class _AddToContainerState extends State<_AddToContainer> {
  bool _folder = false;

  @override
  Widget build(BuildContext context) {
    final choice = SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: false,
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text(newItemLabel(widget.type)),
        ),
        const ButtonSegment(
          value: true,
          icon: Icon(Icons.create_new_folder_outlined, size: 18),
          label: Text('New folder'),
        ),
      ],
      selected: {_folder},
      onSelectionChanged: (s) => setState(() => _folder = s.first),
    );
    return _folder
        ? _FolderEditor(
            key: const ValueKey('folder'),
            store: widget.store,
            folder: null,
            initialType: widget.type,
            fixedType: true,
            top: choice,
          )
        : _FileEditor(
            key: const ValueKey('item'),
            store: widget.store,
            folder: widget.store.looseOf(widget.type),
            top: choice,
          );
  }
}

/// Asks before deleting [folder] (and everything in it). Returns true if
/// the folder was deleted.
Future<bool> confirmDeleteFolder(
  BuildContext context,
  ExpenseStore store,
  Folder folder,
) async {
  final count = folder.files.length;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete "${folder.name}"?'),
      content: Text(
        count == 0
            ? 'This folder is empty.'
            : 'This also deletes the $count item${count == 1 ? '' : 's'} '
                  'inside it. This can\'t be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.colors.negative,
            foregroundColor: ctx.colors.onHomeButton,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  store.deleteFolder(folder);
  return true;
}

class _FolderEditor extends StatefulWidget {
  const _FolderEditor({
    super.key,
    required this.store,
    required this.folder,
    required this.initialType,
    this.top,
    this.fixedType = false,
  });

  final ExpenseStore store;
  final Folder? folder;
  final FolderType initialType;
  final Widget? top;

  /// Created from a container: the container decides the type, so the
  /// Expense / Savings picker is hidden.
  final bool fixedType;

  @override
  State<_FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends State<_FolderEditor> {
  late final TextEditingController _name;
  late FolderType _type;
  late bool _showCost;
  late bool _separate;

  bool get _isNew => widget.folder == null;

  @override
  void initState() {
    super.initState();
    final f = widget.folder;
    _name = TextEditingController(text: f?.name ?? '');
    _type = f?.type ?? widget.initialType;
    _showCost = f?.showCostOnMain ?? true;
    _separate = f?.showAsSeparateContainer ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final f = widget.folder;
    if (f == null) {
      widget.store.addFolder(
        Folder(
          name: name,
          type: _type,
          showCostOnMain: _showCost,
          showAsSeparateContainer: _type == FolderType.savings && _separate,
        ),
      );
    } else {
      f
        ..name = name
        ..type = _type
        ..showCostOnMain = _showCost
        ..showAsSeparateContainer = _type == FolderType.savings && _separate;
      widget.store.updateFolder();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      top: widget.top,
      title: _isNew ? 'New folder' : 'Folder settings',
      onSave: _save,
      onDelete: _isNew
          ? null
          : () async {
              final deleted = await confirmDeleteFolder(
                context,
                widget.store,
                widget.folder!,
              );
              if (deleted && context.mounted) Navigator.pop(context);
            },
      children: [
        TextField(
          controller: _name,
          autofocus: _isNew,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Folder name'),
          onSubmitted: (_) => _save(),
        ),
        // Budget folders always stay in the Budget container.
        if (!widget.fixedType && _type != FolderType.budget) ...[
          const SizedBox(height: 16),
          SegmentedButton<FolderType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: FolderType.expense, label: Text('Expense')),
              ButtonSegment(value: FolderType.savings, label: Text('Savings')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'How it shows on home',
          style: TextStyle(fontSize: 13, color: context.colors.muted),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show cost on home page'),
          value: _showCost,
          onChanged: (v) => setState(() => _showCost = v),
        ),
        if (_type == FolderType.savings)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show as a separate container'),
            subtitle: const Text('Gets its own card at the top of home'),
            value: _separate,
            onChanged: (v) => setState(() => _separate = v),
          ),
      ],
    );
  }
}

/// Bottom sheet for creating or editing a file inside [folder].
Future<void> showFileEditor(
  BuildContext context,
  ExpenseStore store,
  Folder folder, {
  EntryFile? file,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.pill,
    builder: (_) => _FileEditor(store: store, folder: folder, file: file),
  );
}

class _FileEditor extends StatefulWidget {
  const _FileEditor({
    super.key,
    required this.store,
    required this.folder,
    this.file,
    this.top,
  });

  final ExpenseStore store;
  final Folder folder;
  final EntryFile? file;
  final Widget? top;

  @override
  State<_FileEditor> createState() => _FileEditorState();
}

class _FileEditorState extends State<_FileEditor> {
  late final TextEditingController _name;
  late final TextEditingController _value;
  late final TextEditingController _days;
  late final TextEditingController _saved;
  late bool _includeAsExpense;
  late bool _fromIncome;
  late bool _paused;
  late BillingCycle _cycle;
  String? _error;
  String? _daysError;

  bool get _isNew => widget.file == null;
  bool get _isSavings => widget.folder.type == FolderType.savings;
  bool get _isSubscription => widget.folder.type == FolderType.subscription;

  /// Expenses and subscriptions can be charged daily, weekly, yearly...
  bool get _hasCycle =>
      _isSubscription || widget.folder.type == FolderType.expense;

  @override
  void initState() {
    super.initState();
    final f = widget.file;
    _name = TextEditingController(text: f?.name ?? '');
    _value = TextEditingController(
      text: f == null ? '' : f.value.toStringAsFixed(2),
    );
    final left = f?.daysLeft();
    _days = TextEditingController(text: left == null ? '' : '$left');
    _includeAsExpense = f?.includeAsMonthlyExpense ?? false;
    _fromIncome = f?.fromIncome ?? false;
    _paused = f?.paused ?? false;
    _cycle = f?.cycle ?? BillingCycle.monthly;
    _saved = TextEditingController(
      text: f?.saved == null ? '' : f!.saved!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _days.dispose();
    _saved.dispose();
    super.dispose();
  }

  /// The amount box converted to a month, for the "How often" hint.
  double get _cycleMonthly =>
      (double.tryParse(_value.text.replaceAll(RegExp(r'[,\$ ]'), '')) ?? 0) *
      _cycle.perMonth;

  /// "Saved so far" (savings only); null when blank.
  double? get _parsedSaved {
    final v = double.tryParse(_saved.text.replaceAll(RegExp(r'[,\$ ]'), ''));
    return _isSavings && v != null && v > 0 ? v : null;
  }

  /// Parsed "remove after" days; null when blank. -1 when invalid.
  int? get _parsedDays {
    final t = _days.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return (n == null || n < 1) ? -1 : n;
  }

  DateTime? _expiryFor(int? days) => days == null || days < 1
      ? null
      : dateOnly(DateTime.now()).add(Duration(days: days));

  void _save() {
    final name = _name.text.trim();
    final value = double.tryParse(
      _value.text.replaceAll(RegExp(r'[,\$ ]'), ''),
    );
    if (name.isEmpty || value == null || value < 0) {
      setState(() => _error = 'Enter a name and a valid amount');
      return;
    }
    final days = _parsedDays;
    if (days == -1) {
      setState(() => _daysError = 'Enter a whole number of days (1 or more)');
      return;
    }
    final expiresOn = _expiryFor(days);
    final f = widget.file;
    if (f == null) {
      widget.store.addFile(
        widget.folder,
        EntryFile(
          name: name,
          value: value,
          expiresOn: expiresOn,
          fromIncome: _isSavings && _fromIncome,
          includeAsMonthlyExpense:
              _isSavings && _fromIncome && _includeAsExpense,
          paused: _paused,
          cycle: _hasCycle ? _cycle : BillingCycle.monthly,
          saved: _parsedSaved,
        ),
      );
    } else {
      f
        ..name = name
        ..value = value
        ..expiresOn = expiresOn
        ..fromIncome = _isSavings && _fromIncome
        ..includeAsMonthlyExpense =
            _isSavings && _fromIncome && _includeAsExpense
        ..paused = _paused
        ..cycle = _hasCycle ? _cycle : BillingCycle.monthly
        ..saved = _parsedSaved;
      widget.store.updateFolder();
    }
    Navigator.pop(context);
  }

  /// Helper line under the "Remove after" field.
  String _removalHint() {
    final days = _parsedDays;
    if (days == null) return 'Leave blank to keep it until you delete it';
    if (days < 1) return ' ';
    return 'Removes itself on ${shortDate(_expiryFor(days)!)}';
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      top: widget.top,
      title: _isNew
          ? (widget.folder.loose
                ? newItemLabel(widget.folder.type)
                : 'Add to ${widget.folder.name}')
          : 'Edit ${widget.file!.name}',
      onSave: _save,
      onDelete: _isNew
          ? null
          : () {
              widget.store.deleteFile(widget.folder, widget.file!);
              Navigator.pop(context);
            },
      children: [
        TextField(
          controller: _name,
          autofocus: _isNew,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: _isSubscription
                ? 'Price'
                : _isSavings
                ? 'Amount per month'
                : 'Amount',
            prefixText: '\$ ',
            errorText: _error,
          ),
          // Keeps the "Counted as $X a month" hint up to date.
          onChanged: (_) {
            if (_cycle != BillingCycle.monthly) setState(() {});
          },
          onSubmitted: (_) => _save(),
        ),
        if (_isSavings) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _saved,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Saved so far (optional)',
              helperText: 'Used to show how much you\'ll have in a year',
              prefixText: '\$ ',
            ),
          ),
        ],
        if (_hasCycle) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<BillingCycle>(
            key: const ValueKey('cycle'),
            initialValue: _cycle,
            decoration: InputDecoration(
              labelText: _isSubscription ? 'Billed' : 'How often',
              helperText: _cycle == BillingCycle.monthly
                  ? null
                  : 'Counted as ${money(_cycleMonthly)} a month',
            ),
            items: [
              for (final c
                  in _isSubscription
                      ? BillingCycle.values
                      : BillingCycle.forExpenses)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => _cycle = v ?? _cycle),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _days,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Remove after (days)',
            suffixText: 'days',
            helperText: _removalHint(),
            errorText: _daysError,
          ),
          onChanged: (_) => setState(() => _daysError = null),
          onSubmitted: (_) => _save(),
        ),
        if (_isSavings) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Comes out of my income'),
            subtitle: const Text('Subtracts this from Remaining Income'),
            value: _fromIncome,
            onChanged: (v) => setState(() {
              _fromIncome = v;
              if (!v) _includeAsExpense = false;
            }),
          ),
          if (_fromIncome)
            SwitchListTile(
              contentPadding: const EdgeInsets.only(left: 16),
              title: const Text('Also count as a monthly expense'),
              subtitle: const Text('Adds this to the Monthly Expense total'),
              value: _includeAsExpense,
              onChanged: (v) => setState(() => _includeAsExpense = v),
            ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Paused'),
          subtitle: const Text('Keeps it listed but leaves it out of totals'),
          value: _paused,
          onChanged: (v) => setState(() => _paused = v),
        ),
      ],
    );
  }
}

/// Shared layout for both sheets: title, fields, Delete / Save row.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
    this.top,
  });

  /// Optional widget above the title (the New item / New folder switch).
  final Widget? top;
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (top != null) ...[top!, const SizedBox(height: 16)],
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 20),
            Row(
              children: [
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.negative,
                    ),
                  ),
                const Spacer(),
                FilledButton(onPressed: onSave, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
