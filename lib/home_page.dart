import 'package:material_ui/material_ui.dart';

import 'budget.dart';
import 'tour.dart';
import 'editors.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final separateSavings = store
        .foldersOf(FolderType.savings)
        .where((f) => f.showAsSeparateContainer)
        .toList();

    final balance = store.usesBalance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ---- Summary cards ----
        // Income is context, not the headline: a slim strip above the cards.
        if (store.hasIncome)
          _IncomeStrip(
            label: balance ? 'Balance' : 'Income',
            amount: store.income!,
            weekly: store.weeklyIncome,
          ),
        SummaryCard(
          title: 'Monthly Expense',
          amount: store.expenseTotal,
          color: context.colors.expenseBlue,
          large: true,
          // Optional (Settings): daily / weekly / yearly costs in their own
          // amounts, faded under the monthly total.
          detail: store.showCycleCosts && store.cycleCosts.isNotEmpty
              ? [
                  for (final e in store.cycleCosts.entries)
                    '${money(e.value)} / ${e.key.short}',
                ].join('  ·  ')
              : null,
        ),
        if (store.hasIncome && store.showWhatsLeft)
          SummaryCard(
            title: balance ? 'Remaining Balance' : 'Remaining Income',
            amount: store.whatsLeft,
            subtitle: balance
                ? null
                : '${money(store.whatsLeftWeekly)} per week',
            color: store.whatsLeft < 0
                ? context.colors.negative
                : context.colors.leftAmber,
          ),
        if (store.showsSection(FolderType.savings) &&
            (store.foldersOf(FolderType.savings).isNotEmpty ||
                store.looseOf(FolderType.savings).files.isNotEmpty))
          SummaryCard(
            title: 'Savings',
            amount: store.savingsTotal,
            color: context.colors.savingsGreen,
          ),
        if (store.showsSection(FolderType.savings))
          for (final f in separateSavings)
            SummaryCard(
              title: f.name,
              amount: f.total,
              color: f.paused
                  ? context.colors.muted
                  : context.colors.savingsGreen,
              subtitle: f.paused ? 'Paused · not counted' : null,
            ),

        // ---- Budget container: first, since budgeting comes first ----
        if (store.showsBudgetSection) ...[
          const SizedBox(height: 20),
          _Section(
            title: 'Budget',
            accent: context.colors.leftAmber,
            total: store.currentOnHome
                ? store.containerTotal(FolderType.budget)
                : null,
            onAdd: () => confirmEditBudget(context, store),
            addLabel: 'Edit Budget',
            addIcon: Icons.edit_outlined,
            children: [
              if (store.currentOnHome) ...[
                for (final f in store.foldersOf(FolderType.budget))
                  FolderTile(store: store, folder: f),
                if (store.foldersOf(FolderType.budget).isEmpty)
                  const _EmptyHint(
                    'Tap Edit Budget to build your budget with the guided '
                    'tour',
                  ),
              ],
              if (store.recommendedOnHome && store.hasIncome)
                _RecommendedFolder(store: store),
            ],
          ),
        ],

        // ---- Containers (each one switched on/off in Settings) ----
        for (final type in FolderType.containers)
          if (store.showsSection(type)) ...[
            const SizedBox(height: 20),
            if (type == FolderType.subscription)
              _SubscriptionsSection(store: store)
            else
              _Section(
                // With a budget on home, the rest are "Other Expenses".
                title: type == FolderType.expense && store.showsBudgetSection
                    ? 'Other Expenses'
                    : type.label,
                accent: sectionAccent(context, type),
                total: store.containerTotal(type),
                subtitle: type == FolderType.savings && store.savingsInAYear > 0
                    ? 'In a year: ${money(store.savingsInAYear.roundToDouble())}'
                    : null,
                onAdd: () => showAddToContainer(context, store, type),
                children: [
                  // Items added straight to the container, then folders.
                  for (final file in store.looseOf(type).files)
                    _FilePill(
                      file: file,
                      onTap: () => showFileEditor(
                        context,
                        store,
                        store.looseOf(type),
                        file: file,
                      ),
                    ),
                  for (final f in store.foldersOf(type))
                    FolderTile(store: store, folder: f),
                  if (store.foldersOf(type).isEmpty &&
                      store.looseOf(type).files.isEmpty)
                    _EmptyHint(
                      type == FolderType.expense
                          ? 'Tap Add for a new expense or a folder '
                                '(e.g. Bills, Car)'
                          : 'Tap Add for a new savings item or a folder',
                    ),
                ],
              ),
          ],
        if (!FolderType.containers.any(store.showsSection))
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: _EmptyHint(
              'All containers are hidden. Turn them back on in Settings.',
            ),
          ),
      ],
    );
  }
}

/// Accent bar color for each container type.
Color sectionAccent(BuildContext context, FolderType type) => switch (type) {
  FolderType.expense => context.colors.expenseBlue,
  FolderType.savings => context.colors.savingsGreen,
  FolderType.subscription => context.colors.subscriptionPurple,
  FolderType.budget => context.colors.leftAmber,
};

/// Compact one-line "Income  $750 / wk  $3,250 / mo" bar shown above the
/// summary cards. In balance mode it reads "Balance  $2,000".
class _IncomeStrip extends StatelessWidget {
  const _IncomeStrip({required this.label, required this.amount, this.weekly});

  final String label;
  final double amount;

  /// null in balance mode (no per-week figure).
  final double? weekly;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.section,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: context.colors.muted,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 15, color: context.colors.muted),
          ),
          const SizedBox(width: 12),
          // Shrinks (never overflows) on narrow phones.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  if (weekly != null) ...[
                    Text(
                      money(weekly!),
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' / wk   ',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                  Text(
                    money(amount),
                    style: TextStyle(
                      fontSize: 17,
                      color: context.colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (weekly != null)
                    Text(
                      ' / mo',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The big rounded grey cards at the top ("Monthly Expense", "Savings").
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    this.large = false,
    this.subtitle,
    this.detail,
  });

  final String title;
  final double amount;
  final Color color;
  final bool large;

  /// Small line under the amount (e.g. "$350 per week").
  final String? subtitle;

  /// Extra faded line under the amount (e.g. "$5 / day · $1,200 / yr").
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.colors.cardBorder,
        borderRadius: BorderRadius.circular(large ? 40 : 32),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: large ? 24 : 10,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(large ? 34 : 26),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: large ? 40 : 30,
                  color: context.colors.text,
                ),
              ),
            ),
            FittedBox(
              child: Text(
                money(amount),
                style: TextStyle(
                  fontSize: large ? 64 : 42,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 15,
                  color: context.colors.textSecondary,
                ),
              ),
            if (detail != null)
              Opacity(
                opacity: 0.6,
                child: Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A collapsible category with its files listed as pills underneath.
class FolderTile extends StatelessWidget {
  const FolderTile({super.key, required this.store, required this.folder});

  final ExpenseStore store;
  final Folder folder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: tap to collapse, gear for folder settings, + to add a file.
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => store.toggleCollapsed(folder),
            child: Padding(
              // Right inset matches the item rows so the icons line up
              // with the rows' right edge.
              padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: folder.collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Name (+ badge) takes all free space, so the action
                  // icons always sit flush against the right edge.
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            folder.showCostOnMain
                                ? '${folder.name} · ${money(folder.total)}'
                                : folder.name,
                            style: TextStyle(
                              fontSize: 17,
                              color: folder.paused
                                  ? context.colors.muted
                                  : context.colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (folder.paused) ...[
                          const SizedBox(width: 8),
                          const _PausedBadge(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tight, evenly spaced action group: pause · add · menu.
                  _HeaderIcon(
                    tooltip: folder.paused
                        ? 'Resume ${folder.name}'
                        : 'Pause ${folder.name}',
                    icon: folder.paused
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline,
                    color: folder.paused
                        ? context.colors.leftAmber
                        : context.colors.muted,
                    onTap: () => store.togglePaused(folder),
                  ),
                  const SizedBox(width: _HeaderIcon.gap),
                  _HeaderIcon(
                    tooltip: 'Add to ${folder.name}',
                    icon: Icons.add_circle,
                    onTap: () => showFileEditor(context, store, folder),
                  ),
                  const SizedBox(width: _HeaderIcon.gap),
                  PopupMenuButton<String>(
                    tooltip: 'Folder options',
                    padding: EdgeInsets.zero,
                    color: context.colors.pill,
                    child: SizedBox.square(
                      dimension: _HeaderIcon.size,
                      child: Icon(
                        Icons.more_vert,
                        size: _HeaderIcon.iconSize,
                        color: context.colors.muted,
                      ),
                    ),
                    onSelected: (v) {
                      if (v == 'edit') {
                        showFolderEditor(context, store, folder: folder);
                      } else if (v == 'delete') {
                        confirmDeleteFolder(context, store, folder);
                      }
                    },
                    itemBuilder: (menu) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit folder'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: menu.colors.negative,
                          ),
                          title: Text(
                            'Delete folder',
                            style: TextStyle(color: menu.colors.negative),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: folder.collapsed
                ? const SizedBox(width: double.infinity)
                : AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: folder.paused ? 0.45 : 1,
                    child: Column(
                      children: [
                        for (final file in folder.files)
                          _FilePill(
                            file: file,
                            showCycle: folder.type == FolderType.subscription,
                            onTap: () => showFileEditor(
                              context,
                              store,
                              folder,
                              file: file,
                            ),
                          ),
                        if (folder.files.isEmpty)
                          const _EmptyHint('Empty — tap + to add one'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Compact round icon button used in folder headers, so all three header
/// actions share one size and spacing.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color,
  });

  static const double size = 34;
  static const double iconSize = 22;
  static const double gap = 2;

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  /// Defaults to the muted palette color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: size / 2 + 4,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: iconSize,
            color: color ?? context.colors.muted,
          ),
        ),
      ),
    );
  }
}

/// Small amber "Paused" chip next to a paused folder's name.
class _PausedBadge extends StatelessWidget {
  const _PausedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.leftAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Paused',
        style: TextStyle(
          fontSize: 12,
          color: context.colors.leftAmber,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One bill / savings / subscription item: name on the left, amount on the
/// right, and a small detail line (paused, from income, billing, expiry).
class _FilePill extends StatelessWidget {
  const _FilePill({
    required this.file,
    required this.onTap,
    this.showCycle = false,
  });

  final EntryFile file;
  final VoidCallback onTap;

  /// Subscriptions: show "/ mo", "/ yr"... after the price.
  final bool showCycle;

  String? _expiryText() {
    final days = file.daysLeft();
    if (days == null) return null;
    if (days <= 0) return 'Removes today';
    if (days == 1) return 'Removes tomorrow';
    return 'Removes in $days days · ${shortDate(file.expiresOn!)}';
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      if (file.saved != null) 'Saved ${money(file.saved!)}',
      if (file.fromIncome) 'From income',
      if (file.cycle != BillingCycle.monthly)
        '≈ ${money(file.value * file.cycle.perMonth)} / mo',
      ?_expiryText(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      child: Opacity(
        opacity: file.paused ? 0.55 : 1,
        child: Material(
          color: context.colors.row,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                file.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: context.colors.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (file.paused) ...[
                              const SizedBox(width: 8),
                              const _PausedBadge(),
                            ],
                          ],
                        ),
                        if (details.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              details,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    money(file.value),
                    style: TextStyle(
                      fontSize: 17,
                      color: context.colors.text,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (showCycle || file.cycle != BillingCycle.monthly)
                    Text(
                      ' / ${file.cycle.short}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.muted,
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
}

/// The recommended budget shown as a locked folder in the Budget container. It can't be
/// edited here; it changes with income and household size (Budget tab).
class _RecommendedFolder extends StatefulWidget {
  const _RecommendedFolder({required this.store});

  final ExpenseStore store;

  @override
  State<_RecommendedFolder> createState() => _RecommendedFolderState();
}

class _RecommendedFolderState extends State<_RecommendedFolder> {
  bool _collapsed = true;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lines = store.recommendedLines;
    final counted = store.recommendedIsCounted;
    // When counted, the header shows only the lines that are switched on.
    final total = counted
        ? store.recommendedContribution
        : lines.fold<double>(0, (s, l) => s + l.amount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 9, 4, 9),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Recommended budget · ${money(total.roundToDouble())}',
                      style: TextStyle(
                        fontSize: 17,
                        color: context.colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    counted ? 'Counted' : 'Guide',
                    color: counted
                        ? context.colors.expenseBlue
                        : context.colors.muted,
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Read-only · change it in Settings',
                    child: Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: context.colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_collapsed && counted)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                'Switch off anything you already track in your own folders '
                'so it isn\'t counted twice.',
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
            ),
          if (!_collapsed)
            for (final l in lines)
              _RecommendedRow(
                line: l,
                counted: counted,
                on: !store.recommendedOff.contains(l.category.id),
                onChanged: (v) => store.setRecommendedLineOn(l.category.id, v),
              ),
        ],
      ),
    );
  }
}

/// One line of the recommended folder. When the folder is counted it gets a
/// switch; lines switched off are dimmed, struck through and not counted.
class _RecommendedRow extends StatelessWidget {
  const _RecommendedRow({
    required this.line,
    required this.counted,
    required this.on,
    required this.onChanged,
  });

  final BudgetLine line;
  final bool counted;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final off = counted && !on;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      child: Opacity(
        opacity: off ? 0.5 : 1,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            14,
            counted ? 2 : 10,
            6,
            counted ? 2 : 10,
          ),
          decoration: BoxDecoration(
            color: context.colors.row,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  line.category.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.text,
                    decoration: off ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                money(line.amount.roundToDouble()),
                style: TextStyle(
                  fontSize: 15,
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  decoration: off ? TextDecoration.lineThrough : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (counted)
                Transform.scale(
                  scale: 0.75,
                  child: Switch(value: on, onChanged: onChanged),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tinted label chip ("Guide", "Counted").
class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Subscriptions have no folders: each one is listed directly, and the
/// header button adds a subscription (not a folder).
class _SubscriptionsSection extends StatelessWidget {
  const _SubscriptionsSection({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final list = store.subscriptions;
    return _Section(
      title: FolderType.subscription.label,
      accent: sectionAccent(context, FolderType.subscription),
      total: list.total,
      onAdd: () => showFileEditor(context, store, list),
      children: [
        for (final file in list.files)
          _FilePill(
            file: file,
            showCycle: true,
            onTap: () => showFileEditor(context, store, list, file: file),
          ),
        if (list.files.isEmpty)
          const _EmptyHint('Tap Add to add one (e.g. Netflix, Spotify)'),
      ],
    );
  }
}

/// A titled block (Expenses / Savings / Subscriptions) on its own background so the two
/// groups read as separate, with the add button in the header.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.accent,
    required this.children,
    this.onAdd,
    this.total,
    this.addLabel = 'Add',
    this.addIcon = Icons.add,
    this.subtitle,
  });

  final String title;
  final Color accent;

  /// Monthly total shown next to the title ("Expenses · $1,240").
  final double? total;

  /// Header button; none when null.
  final VoidCallback? onAdd;
  final String addLabel;
  final IconData addIcon;

  /// Small line under the title (e.g. "In a year: $5,400").
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                height: 20,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      if (total != null)
                        TextSpan(
                          text: ' · ${money(total!)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 22,
                    color: context.colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onAdd != null)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: Icon(addIcon, size: 18),
                  label: Text(addLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.muted,
                  ),
                ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          Divider(color: context.colors.cardBorder, height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: context.colors.muted),
    ),
  );
}
