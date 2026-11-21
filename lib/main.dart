import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'chart_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ExpenseStore.load();
  runApp(ExpenseApp(store: store));
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the dark-mode setting flips.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'ExpencyView',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
        home: AppShell(store: store),
      ),
    );
  }
}

/// Top bar with the settings gear, the current page, and — once income is
/// entered — floating Home / Chart buttons at the bottom.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _page = 0; // 0 = home, 1 = chart
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Items with a "remove after" date clear themselves once that day arrives,
    // even if the app stays open past midnight.
    _expiryTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => widget.store.purgeExpired(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.store.purgeExpired();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // Chart page only exists when income is set.
        final page = store.hasIncome ? _page : 0;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 48,
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined, size: 30),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsPage(store: store),
                  ),
                ),
              ),
            ],
          ),
          body: page == 0 ? HomePage(store: store) : ChartPage(store: store),
          bottomNavigationBar: store.hasIncome
              ? _BottomBar(
                  page: page,
                  onSelect: (p) => setState(() => _page = p),
                )
              : null,
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.page, required this.onSelect});

  final int page;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget roundButton(int index, IconData icon, String label) {
      final selected = page == index;
      return Semantics(
        label: label,
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? context.colors.homeButton : context.colors.pill,
            ),
            child: Icon(
              icon,
              size: 44,
              color: selected
                  ? context.colors.onHomeButton
                  : context.colors.textSecondary,
            ),
          ),
        ),
      );
    }

    // No background: the buttons sit directly on the page color.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            roundButton(0, Icons.home_rounded, 'Home'),
            const SizedBox(width: 32),
            roundButton(1, Icons.pie_chart_rounded, 'Chart'),
          ],
        ),
      ),
    );
  }
}
