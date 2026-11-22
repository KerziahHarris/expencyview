import 'package:material_ui/material_ui.dart';

import 'budget_page.dart';
import 'store.dart';
import 'theme.dart';

/// First-time welcome pop-up. "Start by adding your budget" goes straight to
/// the budget pop-up; either button marks the welcome as seen.
Future<void> showWelcome(BuildContext context, ExpenseStore store) async {
  final addBudget = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _WelcomeDialog(),
  );
  store.markWelcomeSeen();
  if (addBudget != true || !context.mounted) return;
  // Budget → (income, if none yet) → offer the recommended budget, which
  // needs an income to work from.
  await showBudgetDialog(context, store);
  if (store.hasIncome && !store.showRecommended && context.mounted) {
    final turnOn = await showDialog<bool>(
      context: context,
      builder: (_) => const _RecommendedPrompt(),
    );
    if (turnOn == true) store.setShowRecommended(true);
  }
}

/// "Turn on the recommended budget?" asked once during the welcome flow.
class _RecommendedPrompt extends StatelessWidget {
  const _RecommendedPrompt();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.pill,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.receipt_long_rounded, size: 40, color: c.expenseBlue),
              const SizedBox(height: 12),
              Text(
                'Turn on the recommended budget?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Adds a Budget tab that suggests how to split your income '
                '(rent, groceries, toiletries, savings...) and lets you '
                'compare it with what you spend. You can change this in '
                'Settings anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.4, color: c.muted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No thanks'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Turn it on'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeDialog extends StatelessWidget {
  const _WelcomeDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      backgroundColor: c.pill,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/icon/logo_mark.png',
                  width: 72,
                  height: 72,
                  color: c.muted,
                  semanticLabel: 'ExpencyView logo',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to ExpencyView',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A place to view your expenses.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: c.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.add),
                label: const Text('Start by adding your budget'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Are you sure?" before erasing everything; then back to home, where the
/// welcome pop-up greets the (now new) user again.
Future<void> confirmClearAllData(
  BuildContext context,
  ExpenseStore store,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clear all data?'),
      content: const Text(
        'Are you sure? This permanently deletes your income, expenses, '
        'savings, subscriptions, budgets and settings from this device. '
        'It can\'t be undone.',
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
          child: const Text('Clear everything'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  Navigator.of(context).popUntil((r) => r.isFirst);
  await store.clearAllData();
}

/// One-time pop-up for existing users after an update: add a budget, start
/// fresh like a new user, or skip.
Future<void> showUpdateNotice(BuildContext context, ExpenseStore store) async {
  final choice = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateDialog(),
  );
  store.markUpdateSeen();
  if (!context.mounted) return;
  switch (choice) {
    case 'budget':
      await showBudgetDialog(context, store);
    case 'fresh':
      await confirmClearAllData(context, store);
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.expenseBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, height: 1.35, color: c.text),
            ),
          ),
        ],
      ),
    );

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
                'ExpencyView has been updated',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "What's new in version $appVersion",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.muted),
              ),
              const SizedBox(height: 16),
              point(
                Icons.account_balance_wallet_outlined,
                'Add your budget and compare it with a recommended one',
              ),
              point(
                Icons.autorenew,
                'Track subscriptions and how often they bill',
              ),
              point(
                Icons.pause_circle_outline,
                'Pause single bills, not just folders',
              ),
              point(
                Icons.light_mode_outlined,
                'Light and dark mode: switch anytime in Settings',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'budget'),
                icon: const Icon(Icons.add),
                label: const Text('Add my budget'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'fresh'),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Start fresh (reset my data)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.negative,
                  side: BorderSide(color: c.negative.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, 'later'),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
