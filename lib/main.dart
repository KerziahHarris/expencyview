import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'budget_page.dart';
import 'chart_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'store.dart';
import 'theme.dart';
import 'welcome.dart';

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
        builder: (context, child) =>
            UiScale(textScale: store.textScale, child: child!),
        home: AppShell(store: store),
      ),
    );
  }
}

/// Draws the whole app (pages, sheets, dialogs) at [kUiScale] of its normal
/// size, like zooming a web page out, so it fits small screens better.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.child, this.textScale = 1});

  final Widget child;

  /// Accessibility text size on top of the whole-app zoom.
  final double textScale;

  @override
  Widget build(BuildContext context) {
    const s = kUiScale;
    final mq = MediaQuery.of(context);
    final size = mq.size / s;
    return MediaQuery(
      data: mq.copyWith(
        size: size,
        padding: mq.padding / s,
        viewPadding: mq.viewPadding / s,
        viewInsets: mq.viewInsets / s,
        devicePixelRatio: mq.devicePixelRatio * s,
        textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: Transform.scale(
            scale: s,
            alignment: Alignment.topLeft,
            child: child,
          ),
        ),
      ),
    );
  }
}

enum AppTab {
  home('Home', Icons.home_rounded),
  chart('Chart', Icons.pie_chart_rounded),
  budget('Budget', Icons.receipt_long_rounded);

  const AppTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Top bar with the settings gear, the current page, and — once income is
/// entered — small Home / Chart (/ Budget) buttons at the bottom.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppTab _tab = AppTab.home;
  Timer? _expiryTimer;
  bool _welcomeOpen = false;

  /// Shows the one-time update pop-up for an existing user, once the
  /// current frame is drawn. (New users get the full welcome screen.)
  void _maybeWelcome(ExpenseStore store) {
    if (_welcomeOpen || !store.needsUpdateNotice) return;
    _welcomeOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _tab = AppTab.home);
      await showUpdateNotice(context, store);
      _welcomeOpen = false;
    });
  }

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

  /// Tabs that currently exist: Chart needs income; Budget also needs the
  /// recommended-budget setting.
  List<AppTab> _tabs(ExpenseStore store) => [
    if (store.hasIncome && store.showRecommended) AppTab.budget,
    AppTab.home,
    if (store.hasIncome) AppTab.chart,
  ];

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // First time (or after "Clear all data"): the welcome screen.
        if (!store.seenWelcome) return WelcomeScreen(store: store);
        _maybeWelcome(store);
        final tabs = _tabs(store);
        final tab = tabs.contains(_tab) ? _tab : AppTab.home;
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
          body: switch (tab) {
            AppTab.home => HomePage(store: store),
            AppTab.chart => ChartPage(store: store),
            AppTab.budget => BudgetPage(store: store),
          },
          bottomNavigationBar: tabs.length > 1
              ? _BottomBar(
                  tabs: tabs,
                  current: tab,
                  onSelect: (t) => setState(() => _tab = t),
                )
              : null,
        );
      },
    );
  }
}

/// Compact footer: small round buttons, no background bar.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tabs,
    required this.current,
    required this.onSelect,
  });

  final List<AppTab> tabs;
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget roundButton(AppTab tab) {
      final selected = tab == current;
      return Tooltip(
        message: tab.label,
        child: Semantics(
          label: tab.label,
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () => onSelect(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? context.colors.homeButton
                    : context.colors.pill,
              ),
              child: Icon(
                tab.icon,
                size: 26,
                color: selected
                    ? context.colors.onHomeButton
                    : context.colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, t) in tabs.indexed) ...[
              if (i > 0) const SizedBox(width: 24),
              roundButton(t),
            ],
          ],
        ),
      ),
    );
  }
}
