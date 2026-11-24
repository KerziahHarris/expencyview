import 'package:material_ui/material_ui.dart';

import 'tour.dart';
import 'store.dart';
import 'theme.dart';

/// First-time welcome: a full screen (not a pop-up, so it can't be tapped
/// away by mistake) with two clear choices.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.store});

  final ExpenseStore store;

  void _start(BuildContext context) {
    store.markWelcomeSeen();
    startTour(context, store);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            c.expenseBlue.withValues(alpha: 0.25),
                            c.savingsGreen.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                      child: Image.asset(
                        'assets/icon/logo_mark.png',
                        color: c.text,
                        semanticLabel: 'ExpencyView logo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Welcome to ExpencyView',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A place to view your expenses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: c.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.section,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'New here? The guided tour walks you through your '
                      'income, home, everyday needs, getting around, wants '
                      'and savings, one simple step at a time. It takes '
                      'about 5 minutes, and you can skip any step.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _start(context),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start the guided tour'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: store.markWelcomeSeen,
                    child: const Text('Skip for now'),
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

/// One-time pop-up for existing users after an update: try the tour, start
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
    case 'tour':
      await startTour(context, store);
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
                "What's new in version $noticeVersion",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.muted),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => showWhatsNew(context),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text("What's New?"),
                ),
              ),
              const SizedBox(height: 8),
              point(
                Icons.map_outlined,
                'A guided tour that builds your budget step by step',
              ),
              point(
                Icons.folder_outlined,
                'Your budget is saved as folders you can edit item by item',
              ),
              point(
                Icons.savings_outlined,
                'See how much your savings will be in a year',
              ),
              point(
                Icons.format_size,
                'Bigger text, and a text size setting in Accessibility',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'tour'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Try the new guided tour'),
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

/// Plain-language list of what this version added (Settings → App Info and
/// the update pop-up).
Future<void> showWhatsNew(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) {
    final c = ctx.colors;
    Widget item(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.expenseBlue.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: c.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: c.pill,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Text(
                "What's New in $appVersion",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    item(
                      Icons.map_outlined,
                      'Guided tour',
                      'Build your budget step by step: income, home, '
                          'everyday needs, getting around, wants and '
                          'savings. Skip anything that doesn\'t apply.',
                    ),
                    item(
                      Icons.folder_outlined,
                      'Budget folders',
                      'Each part of your budget is its own folder. Tap any '
                          'item to change just that one.',
                    ),
                    item(
                      Icons.savings_outlined,
                      'Savings in a year',
                      'Add what you\'ve saved so far and see how much '
                          'you\'ll have a year from now.',
                    ),
                    item(
                      Icons.compare_arrows,
                      'Compare with a guide',
                      'See your budget next to a recommended one, '
                          'category by category.',
                    ),
                    item(
                      Icons.event_repeat,
                      'Daily, weekly or yearly costs',
                      'Set how often an expense happens. It\'s turned into '
                          'a monthly amount for you.',
                    ),
                    item(
                      Icons.format_size,
                      'Text size',
                      'Make text bigger or smaller in Settings → '
                          'Accessibility.',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
