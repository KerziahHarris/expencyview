import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'budget.dart';
import 'models.dart';
import 'tour.dart';
import 'store.dart';
import 'theme.dart';

enum _BudgetView { guide, compare }

/// Budget tab: a suggested monthly breakdown of the user's income, grouped
/// into needs / wants / savings, for their household size. The Compare view
/// totals the user's own items per category (from their Budget folders,
/// savings plan and tour subscriptions) and sets them against the guide.
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  _BudgetView _view = _BudgetView.guide;

  // The household size typed here is held (not saved) until "Apply
  // changes", so typing doesn't redraw and save the whole app each keystroke.
  int? _pendingHousehold;
  final _dirty = ValueNotifier<bool>(false);

  void _editHousehold(int n) {
    _pendingHousehold = n;
    _dirty.value = true;
  }

  // Compare → Edit: one box per item (and one per empty category). Nothing
  // changes until Save.
  bool _editing = false;
  final Map<EntryFile, TextEditingController> _itemBoxes = {};
  final Map<String, TextEditingController> _newBoxes = {};

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static double? _parse(String t) =>
      double.tryParse(t.replaceAll(RegExp(r'[,\$ ]'), '').trim());

  void _startEdit() {
    _clearBoxes();
    for (final l in widget.store.recommendedLines) {
      final items = widget.store.categoryItems(l.category.id);
      if (items.isEmpty) {
        _newBoxes[l.category.id] = TextEditingController();
      }
      for (final (_, file) in items) {
        _itemBoxes[file] = TextEditingController(text: _fmt(file.monthlyValue));
      }
    }
    setState(() => _editing = true);
    _dirty.value = true;
  }

  void _cancelEdit() {
    _clearBoxes();
    setState(() => _editing = false);
    _dirty.value = _pendingHousehold != null;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _clearBoxes() {
    for (final c in [..._itemBoxes.values, ..._newBoxes.values]) {
      c.dispose();
    }
    _itemBoxes.clear();
    _newBoxes.clear();
  }

  /// The box(es) shown for one category while editing.
  Widget _editor(BudgetLine line) {
    final c = context.colors;
    Widget box(
      String label,
      String? note,
      TextEditingController ctrl,
      Key key,
    ) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: c.text)),
                if (note != null)
                  Text(note, style: TextStyle(fontSize: 11, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextField(
              key: key,
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                isDense: true,
                prefixText: '\$ ',
                hintText: '0',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final items = widget.store.categoryItems(line.category.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (folder, file) in items)
          if (_itemBoxes[file] case final ctrl?)
            box(
              file.name,
              '${folder.loose ? folder.type.label : folder.name} · per month',
              ctrl,
              ValueKey('edit-${file.id}'),
            ),
        if (_newBoxes[line.category.id] case final ctrl?)
          box(
            'Add an amount',
            'Saved to a "My budget" folder',
            ctrl,
            ValueKey('edit-new-${line.category.id}'),
          ),
      ],
    );
  }

  /// Saves pending edits (household and/or Compare amounts) in one go.
  void _apply() {
    final store = widget.store;
    if (_pendingHousehold case final n?) store.setHouseholdSize(n);
    _pendingHousehold = null;
    if (_editing) {
      store.applyCompareEdits(
        items: {
          for (final e in _itemBoxes.entries) e.key: _parse(e.value.text),
        },
        added: {
          for (final e in _newBoxes.entries)
            if (_parse(e.value.text) case final v? when v > 0) e.key: v,
        },
      );
      _clearBoxes();
      setState(() => _editing = false);
    }
    _dirty.value = false;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    // Leaving the page without pressing Apply still keeps what was typed.
    if (_pendingHousehold case final n?) {
      final store = widget.store;
      Future.microtask(() => store.setHouseholdSize(n));
    }
    _clearBoxes();
    _dirty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lines = store.recommendedLines;
    final basis = store.usesBalance
        ? 'your ${money(store.income ?? 0)} balance'
        : '${money(store.income ?? 0)} / month';
    final compare = _view == _BudgetView.compare;

    List<BudgetLine> linesOf(BudgetGroup g) => [
      for (final l in lines)
        if (l.category.group == g) l,
    ];

    final page = ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          'Recommended budget',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, color: context.colors.text),
        ),
        const SizedBox(height: 4),
        Text(
          compare ? 'Your budget next to the guide' : 'Where $basis could go',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, fontSize: 16),
        ),
        const SizedBox(height: 14),
        SegmentedButton<_BudgetView>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: _BudgetView.guide,
              icon: Icon(Icons.pie_chart_outline, size: 18),
              label: Text('Guide'),
            ),
            ButtonSegment(
              value: _BudgetView.compare,
              icon: Icon(Icons.compare_arrows, size: 18),
              label: Text('Compare'),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (v) => setState(() => _view = v.first),
        ),
        const SizedBox(height: 14),
        HouseholdStepper(store: store, onEdit: _editHousehold),
        const SizedBox(height: 16),
        if (compare) ...[
          _CompareSummary(store: store),
          // Edit my amounts ↔ Cancel / Save
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_editing) ...[
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Save'),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: _startEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
              ],
            ),
          ),
          for (final group in BudgetGroup.values)
            _CompareGroupCard(
              store: store,
              group: group,
              lines: linesOf(group),
              editor: _editing ? _editor : null,
            ),
        ] else
          for (final group in BudgetGroup.values)
            _GroupCard(group: group, lines: linesOf(group)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: context.colors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'These are estimates based on typical U.S. household '
                'spending, not financial advice. Rent, location and debt '
                'change a lot from person to person, so treat this as a '
                'starting point and adjust it to fit you.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: context.colors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Stack(
      children: [
        // Make room for the floating button while it's showing (changes only
        // when edits start / are applied, not on every keystroke).
        ValueListenableBuilder<bool>(
          valueListenable: _dirty,
          builder: (context, dirty, child) => AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(top: dirty ? 48 : 0),
            child: child,
          ),
          child: page,
        ),
        // Floating "Apply changes" (top right), only while edits are pending.
        Positioned(
          top: 6,
          right: 12,
          child: ValueListenableBuilder<bool>(
            valueListenable: _dirty,
            builder: (context, dirty, _) => AnimatedScale(
              scale: dirty ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: FilledButton.icon(
                onPressed: dirty ? _apply : null,
                icon: const Icon(Icons.check, size: 18),
                label: Text(_editing ? 'Save' : 'Apply changes'),
                style: FilledButton.styleFrom(
                  elevation: 6,
                  shadowColor: Colors.black54,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Color _groupAccent(BuildContext context, BudgetGroup group) => switch (group) {
  BudgetGroup.needs => context.colors.expenseBlue,
  BudgetGroup.wants => context.colors.leftAmber,
  BudgetGroup.savings => context.colors.savingsGreen,
};

/// "Household  [ 4 ] people" — a number field, shared by the Budget tab and
/// Settings. Saves as you type; blank or 0 is treated as 1.
class HouseholdStepper extends StatefulWidget {
  const HouseholdStepper({super.key, required this.store, this.onEdit});

  final ExpenseStore store;

  /// When set, typed values go here instead of being saved right away (the
  /// Budget page applies them with "Apply changes").
  final ValueChanged<int>? onEdit;

  @override
  State<HouseholdStepper> createState() => _HouseholdStepperState();
}

class _HouseholdStepperState extends State<HouseholdStepper> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.store.householdSize}');
    // When the field is left blank or invalid, show the saved value again.
    _focus.addListener(() {
      final n = int.tryParse(_controller.text);
      if (!_focus.hasFocus && (n == null || n < 1)) {
        _controller.text = '${widget.store.householdSize}';
      }
    });
  }

  @override
  void didUpdateWidget(HouseholdStepper old) {
    super.didUpdateWidget(old);
    // Keep in sync if it was changed on the other screen.
    final saved = '${widget.store.householdSize}';
    if (widget.onEdit == null &&
        !_focus.hasFocus &&
        _controller.text != saved) {
      _controller.text = saved;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final n = int.tryParse(text);
    if (n == null || n < 1) return;
    final onEdit = widget.onEdit;
    onEdit == null ? widget.store.setHouseholdSize(n) : onEdit(n);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.store.householdSize;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.section,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline, size: 20, color: context.colors.muted),
          const SizedBox(width: 8),
          // Takes the free space (and shortens with "…" if text is huge),
          // so the box and "person/people" always fit on one line.
          Expanded(
            child: Text(
              'Household',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: context.colors.muted),
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              key: const ValueKey('household-size'),
              controller: _controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.text,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '1',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: _onChanged,
            ),
          ),
          const SizedBox(width: 8),
          // No fixed width, so "person"/"people" never wraps.
          Text(
            n == 1 ? 'Person' : 'People',
            softWrap: false,
            style: TextStyle(fontSize: 15, color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.lines});

  final BudgetGroup group;
  final List<BudgetLine> lines;

  @override
  Widget build(BuildContext context) {
    final total = lines.fold<double>(0, (s, l) => s + l.amount);
    final pct = lines.fold<double>(0, (s, l) => s + l.percent);
    final accent = _groupAccent(context, group);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: context.colors.section,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.colors.text,
                      ),
                    ),
                    Text(
                      group.blurb,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  Text(
                    '${pct.round()}%',
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: context.colors.cardBorder, height: 20),
          for (final l in lines) _LineRow(line: l),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.category.name,
                  style: TextStyle(fontSize: 15, color: context.colors.text),
                ),
                const SizedBox(height: 1),
                Text(
                  line.category.examples,
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(line.amount.roundToDouble()),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${line.percent.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compare view
// ---------------------------------------------------------------------------

/// How one category's real spending stacks up against the guide.
class _Verdict {
  _Verdict(this.text, this.color, this.fill);
  final String text;
  final Color color;

  /// 0–1 for the progress bar (spending ÷ guide, capped).
  final double fill;

  static _Verdict of(
    BuildContext context,
    BudgetGroup group,
    double guide,
    double actual,
  ) {
    final diff = actual - guide;
    final fill = guide <= 0 ? 1.0 : (actual / guide).clamp(0.0, 1.0);
    final c = context.colors;
    if (diff.abs() < 0.5) {
      return _Verdict('Right on the guide', c.savingsGreen, fill);
    }
    // For savings, putting away more than the guide is the good direction.
    if (group == BudgetGroup.savings) {
      return diff > 0
          ? _Verdict(
              'Ahead by ${money(diff.roundToDouble())}',
              c.savingsGreen,
              fill,
            )
          : _Verdict(
              'Short by ${money((-diff).roundToDouble())}',
              c.leftAmber,
              fill,
            );
    }
    return diff < 0
        ? _Verdict(
            'Saving ${money((-diff).roundToDouble())}',
            c.savingsGreen,
            fill,
          )
        : _Verdict('Over by ${money(diff.roundToDouble())}', c.negative, fill);
  }
}

/// Totals for the categories the user has filled in.
class _CompareSummary extends StatelessWidget {
  const _CompareSummary({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final lines = store.recommendedLines;
    final spent = {
      for (final l in lines)
        l.category.id: ?store.categorySpending(l.category.id),
    };
    final spending = [
      for (final l in lines)
        if (l.category.group != BudgetGroup.savings &&
            spent.containsKey(l.category.id))
          l,
    ];
    final filled = spent.length;
    final actual = spending.fold<double>(
      0,
      (s, l) => s + spent[l.category.id]!,
    );
    final guide = spending.fold<double>(0, (s, l) => s + l.amount);
    final diff = actual - guide;
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.section,
        borderRadius: BorderRadius.circular(20),
      ),
      child: filled == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nothing to compare yet. Build your budget with the guided '
                  'tour and your amounts will show up here, category by '
                  'category.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: c.muted),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => confirmEditBudget(context, store),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Budget'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$filled of ${lines.length} categories filled in',
                  style: TextStyle(fontSize: 13, color: c.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'You spend',
                        value: money(actual.roundToDouble()),
                        color: c.text,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'Guide',
                        value: money(guide.roundToDouble()),
                        color: c.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: diff > 0 ? 'Over' : 'Saving',
                        value: money(diff.abs().roundToDouble()),
                        color: diff > 0 ? c.negative : c.savingsGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Needs and wants only; savings are compared separately '
                  'below.',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: context.colors.muted)),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _CompareGroupCard extends StatelessWidget {
  const _CompareGroupCard({
    required this.store,
    required this.group,
    required this.lines,
    this.editor,
  });

  final ExpenseStore store;
  final BudgetGroup group;
  final List<BudgetLine> lines;

  /// Edit mode: builds the boxes for one category.
  final Widget Function(BudgetLine)? editor;

  @override
  Widget build(BuildContext context) {
    final accent = _groupAccent(context, group);
    final guideTotal = lines.fold<double>(0, (s, l) => s + l.amount);
    final filled = [
      for (final l in lines) ?store.categorySpending(l.category.id),
    ];
    final yourTotal = filled.fold<double>(0, (s, v) => s + v);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: context.colors.section,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.colors.text,
                  ),
                ),
              ),
              // This container's guide total (and yours, once filled in).
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Guide ${money(guideTotal.roundToDouble())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  if (filled.isNotEmpty)
                    Text(
                      'You ${money(yourTotal.roundToDouble())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.muted,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Divider(color: context.colors.cardBorder, height: 20),
          for (final l in lines)
            _CompareRow(
              key: ValueKey(l.category.id),
              actual: store.categorySpending(l.category.id),
              line: l,
              editor: editor?.call(l),
            ),
        ],
      ),
    );
  }
}

/// One category: what you spend (from your items), the guide, and how they
/// compare.
class _CompareRow extends StatelessWidget {
  const _CompareRow({
    super.key,
    required this.line,
    required this.actual,
    this.editor,
  });

  /// Edit mode: the boxes, shown instead of the verdict.
  final Widget? editor;

  final BudgetLine line;

  /// Your monthly total for this category; null when none of your items
  /// belong to it.
  final double? actual;

  @override
  Widget build(BuildContext context) {
    final guide = line.amount.roundToDouble();
    if (editor != null) {
      final c = context.colors;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.category.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                Text(
                  'Guide ${money(guide)}',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
            editor!,
          ],
        ),
      );
    }
    final verdict = actual == null
        ? null
        : _Verdict.of(context, line.category.group, guide, actual!);
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.category.name,
                  style: TextStyle(fontSize: 15, color: c.text),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                actual == null ? '—' : money(actual!.roundToDouble()),
                key: ValueKey('spend-${line.category.id}'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: actual == null ? c.muted : c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Guide ${money(guide)}',
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verdict?.text ?? 'Not in your budget',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: verdict == null
                        ? FontWeight.normal
                        : FontWeight.w600,
                    color: verdict?.color ?? c.muted,
                  ),
                ),
              ),
            ],
          ),
          if (verdict != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: verdict.fill,
                minHeight: 5,
                color: verdict.color,
                backgroundColor: c.row,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
