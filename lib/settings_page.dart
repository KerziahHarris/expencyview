import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

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
            const Text(
              'Income',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'How often do you get paid?',
              style: TextStyle(color: context.colors.muted),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PayFrequency>(
              showSelectedIcon: false,
              segments: [
                for (final f in PayFrequency.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {store.payFrequency},
              onSelectionChanged: (s) => store.setPayFrequency(s.first),
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
                helperText: 'After taxes',
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
              ),
              onChanged: _savePay,
            ),
            if (store.hasIncome) ...[
              const SizedBox(height: 16),
              _Breakdown(store: store),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Remaining Income'),
              subtitle: const Text(
                'Income minus expenses and savings taken from income',
              ),
              value: store.showWhatsLeft,
              onChanged: store.hasIncome ? store.setShowWhatsLeft : null,
            ),
            if (!store.hasIncome)
              Text(
                'Enter your income to unlock Remaining Income and the chart page.',
                style: TextStyle(color: context.colors.muted),
              ),
            const SizedBox(height: 28),
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
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
          row('Per week', store.weeklyIncome!),
          if (store.payFrequency == PayFrequency.biweekly)
            row('Per paycheck', store.payAmount!),
          row('Per month', store.income!),
          row('Per year', store.yearlyIncome!),
          Divider(color: context.colors.cardBorder, height: 20),
          row('Left to budget / week', store.whatsLeftWeekly, color: leftColor),
          row('Left to budget / month', left, color: leftColor),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: context.colors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'These numbers are estimates. Weekly and monthly amounts are '
                  'averaged over a year, so some months (like ones with an '
                  'extra paycheck) will come out a little different.',
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

/// About page reached from the quiet "App Info" row in settings.
class AppInfoPage extends StatelessWidget {
  const AppInfoPage({super.key});

  static const version = 'Version 1';

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
