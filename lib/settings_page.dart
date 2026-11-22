import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'budget_page.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'welcome.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _pay;

  @override
  void initState() {
    super.initState();
    final amount = widget.store.payAmount;
    _pay = TextEditingController(
      text: amount == null ? '' : amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _pay.dispose();
    super.dispose();
  }

  void _savePay(String text) {
    final v = double.tryParse(text.replaceAll(RegExp(r'[,\$ ]'), ''));
    widget.store.setPayAmount(v);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Heading('Income'),
            const SizedBox(height: 4),
            Text(
              'How do you want to enter your money?',
              style: TextStyle(color: context.colors.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in PayFrequency.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: store.payFrequency == f,
                    showCheckmark: false,
                    onSelected: (_) => store.setPayFrequency(f),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pay,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: store.payFrequency.amountLabel,
                helperText: store.usesBalance
                    ? 'Money you have right now. Expenses are taken straight '
                          'from it, with no weekly or monthly conversions.'
                    : 'After taxes',
                helperMaxLines: 3,
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
              ),
              onChanged: _savePay,
            ),
            if (store.hasIncome) ...[
              const SizedBox(height: 16),
              _Breakdown(store: store),
            ],
            const SizedBox(height: 28),
            const _Heading('Home page'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                store.usesBalance
                    ? 'Show Remaining Balance'
                    : 'Show Remaining Income',
              ),
              subtitle: const Text(
                'What\'s left after expenses and savings taken from it',
              ),
              value: store.showWhatsLeft,
              onChanged: store.hasIncome ? store.setShowWhatsLeft : null,
            ),
            for (final t in FolderType.values)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Show ${t.label}'),
                value: store.showsSection(t),
                onChanged: (v) => store.setShowSection(t, v),
              ),
            if (!store.hasIncome)
              Text(
                'Enter your income to unlock Remaining Income, the chart '
                'and the recommended budget.',
                style: TextStyle(color: context.colors.muted),
              ),
            const SizedBox(height: 28),
            const _Heading('Budget'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show current budget as a folder'),
              subtitle: const Text(
                'What you spend per category (Add budget), at the top of home',
              ),
              value: store.currentOnHome,
              onChanged: store.setCurrentOnHome,
            ),
            if (store.currentOnHome) ...[
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: 16),
                title: const Text('Count it in my totals'),
                subtitle: Text(
                  store.currentCounts
                      ? 'Counted in Monthly Expense and Remaining Income'
                      : 'Off — shown for reference only',
                ),
                value: store.currentCounts,
                onChanged: store.setCurrentCounts,
              ),
              if (store.currentCounts) const _DuplicateWarning(),
            ],
            const SizedBox(height: 28),
            const _Heading('Recommended budget'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show recommended budget'),
              subtitle: const Text(
                'Adds a Budget tab that splits your income into everyday '
                'categories for your household',
              ),
              value: store.showRecommended,
              onChanged: store.hasIncome ? store.setShowRecommended : null,
            ),
            if (store.showRecommended && store.hasIncome) ...[
              const SizedBox(height: 4),
              HouseholdStepper(store: store),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show recommended budget as a folder'),
                subtitle: const Text('Read-only; it updates on its own'),
                value: store.recommendedOnHome,
                onChanged: store.setRecommendedOnHome,
              ),
              if (store.recommendedOnHome) ...[
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 16),
                  title: const Text('Count it in my totals'),
                  subtitle: Text(
                    store.recommendedCounts
                        ? 'Counted in Monthly Expense and Remaining Income'
                        : 'Off — shown as a guide only',
                  ),
                  value: store.recommendedCounts,
                  onChanged: store.setRecommendedCounts,
                ),
                if (store.recommendedCounts) const _DuplicateWarning(),
              ],
            ],
            const SizedBox(height: 28),
            const _Heading('Appearance'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                store.darkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              title: const Text('Dark mode'),
              subtitle: Text(store.darkMode ? 'On' : 'Off — light mode'),
              value: store.darkMode,
              onChanged: store.setDarkMode,
            ),
            const SizedBox(height: 20),
            Divider(color: context.colors.cardBorder),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline, color: context.colors.muted),
              title: Text(
                'App Info',
                style: TextStyle(color: context.colors.muted, fontSize: 15),
              ),
              trailing: Icon(Icons.chevron_right, color: context.colors.muted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AppInfoPage()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_forever_outlined,
                color: context.colors.negative,
              ),
              title: Text(
                'Clear all data',
                style: TextStyle(color: context.colors.negative, fontSize: 15),
              ),
              onTap: () => confirmClearAllData(context, store),
            ),
          ],
        ),
      ),
    );
  }
}

/// "What you make" per week / paycheck / month / year, plus how much of it is
/// still free to budget each week and month.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, double amount, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.colors.muted, fontSize: 15),
            ),
          ),
          Text(
            money(amount),
            style: TextStyle(
              color: color ?? context.colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    final left = store.whatsLeft;
    final leftColor = left < 0
        ? context.colors.negative
        : context.colors.leftAmber;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.section,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (store.usesBalance) ...[
            row('Current balance', store.income!),
            row('Expenses & savings', store.incomeUsed),
            Divider(color: context.colors.cardBorder, height: 20),
            row('Left after expenses', left, color: leftColor),
          ] else ...[
            row('Per week', store.weeklyIncome!),
            if (store.payFrequency == PayFrequency.biweekly)
              row('Per paycheck', store.payAmount!),
            row('Per month', store.income!),
            row('Per year', store.yearlyIncome!),
            Divider(color: context.colors.cardBorder, height: 20),
            row(
              'Left to budget / week',
              store.whatsLeftWeekly,
              color: leftColor,
            ),
            row('Left to budget / month', left, color: leftColor),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: context.colors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  store.usesBalance
                      ? 'These numbers are estimates. Recurring bills are '
                            'counted at one month\'s cost.'
                      : 'These numbers are estimates. A month is counted '
                            'as 4 weekly or 2 bi-weekly paychecks, so a few '
                            'months a year (with an extra paycheck) give you '
                            'a little more.',
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
      ),
    );
  }
}

/// Privacy disclaimer on the App Info page.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.section,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your data stays with you. Nothing you enter is shared or sold. '
              'All information is saved only on this device, and it will be '
              'removed if the app is deleted or the browser cache / site data '
              'is cleared.',
              style: TextStyle(fontSize: 12, height: 1.45, color: c.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title in Settings.
class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  );
}

/// Shown when the recommended budget is counted in totals.
class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning();

  @override
  Widget build(BuildContext context) {
    final amber = context.colors.leftAmber;
    return Container(
      margin: const EdgeInsets.only(top: 4, left: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Heads up: expenses you already added yourself (like rent or '
              'groceries) may now be counted twice, once in your folders and '
              'once in the recommended budget.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// About page reached from the quiet "App Info" row in settings.
class AppInfoPage extends StatelessWidget {
  const AppInfoPage({super.key});

  static const version = 'Version $appVersion · $appReleaseNote';

  @override
  Widget build(BuildContext context) {
    final body = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: context.colors.textSecondary,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('App Info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Center(
            child: Image.asset(
              'assets/icon/logo_mark.png',
              width: 72,
              height: 72,
              color: context.colors.muted,
              semanticLabel: 'ExpencyView logo',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ExpencyView',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.section,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thank you for trying this app.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This was made one morning with a massive help from AI as I '
                  'am still learning how to program well.',
                  style: body,
                ),
                const SizedBox(height: 12),
                Text(
                  'Thank you to all that has supported me and I hope this app '
                  'has improved the way you budget.',
                  style: body,
                ),
                const SizedBox(height: 20),
                Text('Best regards,', style: body),
                const SizedBox(height: 2),
                Text(
                  'Kerziah Harris',
                  style: TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: context.colors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _PrivacyNote(),
          const SizedBox(height: 24),
          Text(
            version,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
