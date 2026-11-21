import 'package:material_ui/material_ui.dart';

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ---- Summary cards ----
        // Income is context, not the headline: a slim strip above the cards.
        if (store.hasIncome)
          _IncomeStrip(monthly: store.income!, weekly: store.weeklyIncome!),
        SummaryCard(
          title: 'Monthly Expense',
          amount: store.expenseTotal,
          color: context.colors.expenseBlue,
          large: true,
        ),
        if (store.hasIncome && store.showWhatsLeft)
          SummaryCard(
            title: 'Remaining Income',
            amount: store.whatsLeft,
            subtitle: '${money(store.whatsLeftWeekly)} per week',
            color: store.whatsLeft < 0
                ? context.colors.negative
                : context.colors.leftAmber,
          ),
        if (store.foldersOf(FolderType.savings).isNotEmpty)
          SummaryCard(
            title: 'Savings',
            amount: store.savingsTotal,
            color: context.colors.savingsGreen,
          ),
        for (final f in separateSavings)
          SummaryCard(
            title: f.name,
            amount: f.total,
            color: f.paused
                ? context.colors.muted
                : context.colors.savingsGreen,
            subtitle: f.paused ? 'Paused · not counted' : null,
          ),

        const SizedBox(height: 24),

        // ---- Expenses section ----
        _Section(
          title: 'Expenses',
          accent: context.colors.expenseBlue,
          addLabel: 'Add Expense',
          onAdd: () =>
              showFolderEditor(context, store, initialType: FolderType.expense),
          children: [
            for (final f in store.foldersOf(FolderType.expense))
              FolderTile(store: store, folder: f),
            if (store.foldersOf(FolderType.expense).isEmpty)
              const _EmptyHint(
                'Tap + to add an expense folder (e.g. Bills, Car)',
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ---- Savings section ----
        _Section(
          title: 'Savings',
          accent: context.colors.savingsGreen,
          addLabel: 'Add Savings',
          onAdd: () =>
              showFolderEditor(context, store, initialType: FolderType.savings),
          children: [
            for (final f in store.foldersOf(FolderType.savings))
              FolderTile(store: store, folder: f),
            if (store.foldersOf(FolderType.savings).isEmpty)
              const _EmptyHint('Tap + to add a savings folder'),
          ],
        ),
      ],
    );
  }
}

/// Compact one-line "Income  $3,000 / mo" bar shown above the summary cards.
class _IncomeStrip extends StatelessWidget {
  const _IncomeStrip({required this.monthly, required this.weekly});

  final double monthly;
  final double weekly;

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
            'Income',
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
                  Text(
                    money(weekly),
                    style: TextStyle(
                      fontSize: 15,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    ' / wk   ',
                    style: TextStyle(fontSize: 13, color: context.colors.muted),
                  ),
                  Text(
                    money(monthly),
                    style: TextStyle(
                      fontSize: 17,
                      color: context.colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ' / mo',
                    style: TextStyle(fontSize: 13, color: context.colors.muted),
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
  });

  final String title;
  final double amount;
  final Color color;
  final bool large;

  /// Small line under the amount (e.g. "$350 per week").
  final String? subtitle;

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

/// One bill / savings item: name on the left, amount on the right,
/// and a small "removes in N days" line when it has an end date.
class _FilePill extends StatelessWidget {
  const _FilePill({required this.file, required this.onTap});

  final EntryFile file;
  final VoidCallback onTap;

  String? _expiryText() {
    final days = file.daysLeft();
    if (days == null) return null;
    if (days <= 0) return 'Removes today';
    if (days == 1) return 'Removes tomorrow';
    return 'Removes in $days days · ${shortDate(file.expiresOn!)}';
  }

  @override
  Widget build(BuildContext context) {
    final expiry = [
      if (file.fromIncome) 'From income',
      ?_expiryText(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
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
                      Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.colors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (expiry.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            expiry,
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
                    fontSize: 16,
                    color: context.colors.text,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled block (Expenses / Savings) on its own background so the two
/// groups read as separate, with the add button in the header.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.accent,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final Color accent;
  final String addLabel;
  final VoidCallback onAdd;
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
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    color: context.colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(addLabel),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.muted,
                ),
              ),
            ],
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
