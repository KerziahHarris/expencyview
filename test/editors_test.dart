import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:expensive/main.dart';
import 'package:expensive/models.dart';
import 'package:expensive/store.dart';
import 'package:expensive/theme.dart';

/// A container's title, which also shows its total ("Expenses · \$0").
Finder title(String name) => find.textContaining('$name ·', findRichText: true);

void main() {
  testWidgets('Add a folder and a file through the UI', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    await tester.pumpWidget(ExpenseApp(store: store));

    await tester.tap(find.text('Add').first); // Expenses
    await tester.pumpAndSettle();
    // New expense is the default; switch to New folder. No type picker.
    expect(find.text('New expense'), findsWidgets);
    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SegmentedButton<FolderType>, 'Savings'),
      findsNothing,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Folder name'),
      'Car',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Car · \$0'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to Car'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Insurance');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '67.28');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Insurance'), findsOneWidget);
    expect(find.text('\$67.28'), findsWidgets);
    expect(store.expenseTotal, closeTo(67.28, 0.001));

    // Remove-after field sets an expiry date.
    await tester.tap(find.text('Insurance'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Remove after (days)'),
      '30',
    );
    await tester.pump();
    expect(find.textContaining('Removes itself on'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      store.foldersOf(FolderType.expense).first.files.first.daysLeft(),
      30,
    );
    expect(find.textContaining('Removes in 30 days'), findsOneWidget);

    // Savings folder shows the extra toggles.
    await tester.tap(find.text('Add').at(2)); // Savings
    await tester.pumpAndSettle();
    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    expect(find.text('Show as a separate container'), findsOneWidget);
  });

  testWidgets('Delete a folder from its menu (with confirmation)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    store
      ..addFolder(bills)
      ..addFile(bills, EntryFile(name: 'Rent', value: 1000));
    await tester.pumpWidget(ExpenseApp(store: store));

    await tester.tap(find.byTooltip('Folder options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete folder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('also deletes the 1 item'), findsOneWidget);

    // Cancel keeps it.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.foldersOf(FolderType.expense), hasLength(1));

    await tester.tap(find.byTooltip('Folder options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(store.foldersOf(FolderType.expense), isEmpty);
    expect(find.text('Rent'), findsNothing);
  });

  testWidgets('Settings: pay frequency and weekly breakdown', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    await tester.pumpWidget(ExpenseApp(store: store));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Weekly paycheck'),
      '600',
    );
    await tester.pumpAndSettle();
    expect(find.text('Per week'), findsOneWidget);
    expect(find.text('\$2,600'), findsNWidgets(2)); // per month + left
    expect(find.text('\$31,200'), findsOneWidget); // per year
    expect(find.text('Left to budget / week'), findsOneWidget);
    expect(find.textContaining('These numbers are estimates'), findsOneWidget);

    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Yearly salary'), findsOneWidget);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Monthly income'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('App Info'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('App Info'));
    await tester.pumpAndSettle();
    expect(find.text('Thank you for trying this app.'), findsOneWidget);
    expect(find.text('Version 1.2'), findsOneWidget);
    // The privacy disclaimer lives on App Info.
    expect(
      find.textContaining('Nothing you enter is shared or sold'),
      findsOneWidget,
    );
  });

  testWidgets('Pause button shows a Paused badge and resumes', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    final gym = Folder(name: 'Gym', type: FolderType.expense);
    store
      ..addFolder(gym)
      ..addFile(gym, EntryFile(name: 'Membership', value: 50));
    await tester.pumpWidget(ExpenseApp(store: store));

    expect(find.text('Paused'), findsNothing);
    await tester.tap(find.byTooltip('Pause Gym'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(store.expenseTotal, 0);

    await tester.tap(find.byTooltip('Resume Gym'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsNothing);
    expect(store.expenseTotal, 50);
  });

  testWidgets('Dark mode switch flips the theme', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    await tester.pumpWidget(ExpenseApp(store: store));
    BuildContext ctx() => tester.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx()).brightness, Brightness.light); // light by default

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Dark mode'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(store.darkMode, isTrue);
    expect(Theme.of(ctx()).brightness, Brightness.dark);
  });

  testWidgets('Subscriptions: billing cycle and per-item pause', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    final subs = store.subscriptions;
    await tester.pumpWidget(ExpenseApp(store: store));

    // No folders: the container adds subscriptions directly.
    await tester.tap(find.text('Add').at(1)); // Subscriptions
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Music');
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '120');
    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yearly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.expenseTotal, closeTo(10, 0.001)); // $120 / yr
    expect(find.text(' / yr'), findsOneWidget);
    expect(find.textContaining('≈ \$10 / mo'), findsOneWidget);

    // Pause just this item from its editor.
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paused'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.expenseTotal, 0);
    expect(find.text('Paused'), findsOneWidget); // badge on the row
    expect(subs.files, hasLength(1));
    expect(find.text('Add'), findsNWidgets(3)); // all three containers
  });

  testWidgets('Containers follow the Settings switches', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    await tester.pumpWidget(ExpenseApp(store: store));
    expect(find.text('Add'), findsNWidgets(3));
    expect(find.text('Add subscription'), findsNothing);
    expect(title('Subscriptions'), findsOneWidget);
    // Order: Expenses, Subscriptions, Savings.
    double y(String t) => tester.getTopLeft(title(t)).dy;
    expect(y('Expenses'), lessThan(y('Subscriptions')));
    expect(y('Subscriptions'), lessThan(y('Savings')));

    store
      ..setShowSection(FolderType.savings, false)
      ..setShowSection(FolderType.subscription, false);
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget); // only Expenses left
  });

  testWidgets('Recommended budget: tab, home folder, duplicate warning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()..setPayAmount(4000);
    await tester.pumpWidget(ExpenseApp(store: store));
    expect(find.byTooltip('Budget'), findsNothing);

    store.setShowRecommended(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Budget'));
    await tester.pumpAndSettle();
    expect(find.text('Recommended budget'), findsOneWidget);
    expect(find.text('Toiletries & personal care'), findsOneWidget);
    expect(find.text('Needs'), findsOneWidget);

    // Household size is typed in (large numbers allowed).
    await tester.enterText(find.byKey(const ValueKey('household-size')), '12');
    await tester.pump();
    expect(store.householdSize, 1); // held until Apply changes
    await tester.pumpAndSettle(); // button animates in
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();
    expect(store.householdSize, 12);
    expect(find.text('people'), findsOneWidget);

    // Read-only folder on home, guide only by default.
    store.setRecommendedOnHome(true);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recommended budget ·'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);
    expect(store.expenseTotal, 0);

    // Counting it shows the warning in Settings and adds it to totals.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    // The recommended folder's switch is the last of the two.
    await tester.dragUntilVisible(
      find.text('Appearance'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count it in my totals').last);
    await tester.pumpAndSettle();
    // One warning per counted budget folder (current is counted by default).
    expect(find.textContaining('counted twice'), findsNWidgets(2));
    expect(store.expenseTotal, closeTo(4000, 0.01));
  });

  testWidgets('Compare tab: enter spending and see over / under', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()
      ..setPayAmount(4000)
      ..setShowRecommended(true);
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.tap(find.byTooltip('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();

    final housing = store.recommendedLines.firstWhere(
      (l) => l.category.name == 'Housing',
    );
    final over = housing.amount.roundToDouble() + 100;
    await tester.enterText(
      find.byKey(ValueKey('spend-${housing.category.id}')),
      over.toStringAsFixed(0),
    );
    await tester.pumpAndSettle();
    // Nothing is saved or redrawn until Apply changes is pressed.
    expect(store.actualSpending, isEmpty);
    expect(find.text('Over by \$100'), findsNothing);
    await tester.pumpAndSettle(); // button animates in
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();
    expect(store.actualSpending[housing.category.id], over);
    expect(find.text('Over by \$100'), findsOneWidget);
    // Each container shows its own guide total.
    final needsGuide = store.recommendedLines
        .where((l) => l.category.group.name == 'needs')
        .fold<double>(0, (s, l) => s + l.amount)
        .roundToDouble();
    expect(find.text('Guide ${money(needsGuide)}'), findsOneWidget);

    // Spending less than the guide reads as "Saving".
    await tester.enterText(
      find.byKey(ValueKey('spend-${housing.category.id}')),
      (housing.amount.roundToDouble() - 50).toStringAsFixed(0),
    );
    await tester.pumpAndSettle(); // button animates in
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();
    expect(find.text('Saving \$50'), findsWidgets);
    expect(find.text('1 of 15 categories filled in'), findsOneWidget);

    // Clearing the box removes it again.
    await tester.enterText(
      find.byKey(ValueKey('spend-${housing.category.id}')),
      '',
    );
    await tester.pumpAndSettle(); // button animates in
    await tester.tap(find.text('Apply changes'));
    await tester.pumpAndSettle();
    expect(store.actualSpending, isEmpty);
  });

  testWidgets('Counted recommended folder: switch a line off on home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()
      ..setPayAmount(4000)
      ..setShowRecommended(true)
      ..setRecommendedOnHome(true);
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.tap(find.textContaining('Recommended budget ·'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing); // guide only: no switches

    store.setRecommendedCounts(true);
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNWidgets(15));
    await tester.tap(find.byType(Switch).first); // Housing
    await tester.pumpAndSettle();
    final housing = store.recommendedLines.first;
    expect(store.recommendedOff, contains(housing.category.id));
    expect(store.expenseTotal, closeTo(4000 - housing.amount, 0.01));
  });

  testWidgets('Add budget pop-up feeds the current budget and Compare', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()
      ..setPayAmount(4000)
      ..setShowRecommended(true)
      ..setCurrentOnHome(true)
      ..setRecommendedOnHome(true);
    await tester.pumpWidget(ExpenseApp(store: store));

    // Budget container sits above Expenses, current above recommended.
    final budgetY = tester.getTopLeft(find.text('Budget').first).dy;
    final expensesY = tester.getTopLeft(title('Expenses')).dy;
    expect(budgetY, lessThan(expensesY));
    expect(
      tester.getTopLeft(find.textContaining('Current budget ·')).dy,
      lessThan(
        tester.getTopLeft(find.textContaining('Recommended budget ·')).dy,
      ),
    );

    // The Budget container has no add button; it's on the folder.
    expect(find.text('Add budget'), findsOneWidget);
    await tester.tap(find.text('Add budget'));
    await tester.pumpAndSettle();
    expect(find.text('Your current budget'), findsOneWidget);
    // 0 counts as no input.
    await tester.enterText(find.byKey(const ValueKey('dialog-utilities')), '0');
    await tester.enterText(
      find.byKey(const ValueKey('dialog-housing')),
      '1500',
    );
    await tester.enterText(
      find.byKey(const ValueKey('dialog-groceries')),
      '400',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Only filled-in categories are listed.
    expect(store.actualSpending, {'housing': 1500, 'groceries': 400});
    expect(find.textContaining('Current budget · \$1,900'), findsOneWidget);
    expect(find.text('Utilities'), findsNothing);
    expect(store.expenseTotal, 1900); // counted by default

    // Same numbers show up (and stay editable) on Compare.
    await tester.tap(find.byTooltip('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    final box = find.byKey(const ValueKey('spend-housing'));
    expect(tester.widget<TextField>(box).controller!.text, '1500');
    await tester.enterText(box, '1450');
    await tester.pumpAndSettle();

    // Leaving the page without pressing Apply still keeps the edit.
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(store.actualSpending['housing'], 1450);
  });

  testWidgets('Add: a new expense goes straight into the container', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    store
      ..addFolder(bills)
      ..addFile(bills, EntryFile(name: 'Rent', value: 1000));
    await tester.pumpWidget(ExpenseApp(store: store));

    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Phone');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.foldersOf(FolderType.expense), hasLength(1)); // no new folder
    expect(store.looseOf(FolderType.expense).files.single.name, 'Phone');
    expect(find.text('Phone'), findsOneWidget);
    expect(store.expenseTotal, 1060);
    // Container total sits next to its name.
    expect(find.textContaining('Expenses · \$1,060'), findsOneWidget);
  });

  testWidgets('Footer: Budget sits left of Home', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()
      ..setPayAmount(3000)
      ..setShowRecommended(true);
    await tester.pumpWidget(ExpenseApp(store: store));
    double x(String t) => tester.getCenter(find.byTooltip(t)).dx;
    expect(x('Budget'), lessThan(x('Home')));
    expect(x('Home'), lessThan(x('Chart')));
  });

  testWidgets('First-time welcome leads to the budget pop-up', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()..seenWelcome = false;
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ExpencyView'), findsOneWidget);
    expect(find.text('A place to view your expenses.'), findsOneWidget);

    await tester.tap(find.text('Start by adding your budget'));
    await tester.pumpAndSettle();
    expect(store.seenWelcome, isTrue);
    expect(find.text('Your current budget'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('dialog-housing')), '900');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Next: a simple income pop-up (options + amount, no breakdown).
    expect(find.text('Would you like to add your income?'), findsOneWidget);
    expect(find.text('Per week'), findsNothing);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('income-amount')), '700');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.payFrequency, PayFrequency.weekly);
    expect(store.payAmount, 700);

    // Then: offer the recommended budget (income is set now).
    expect(find.text('Turn on the recommended budget?'), findsOneWidget);
    await tester.tap(find.text('Turn it on'));
    await tester.pumpAndSettle();
    expect(store.showRecommended, isTrue);
    expect(find.byTooltip('Budget'), findsOneWidget);

    // Shows on home right away, counted by default.
    expect(find.textContaining('Current budget · \$900'), findsOneWidget);
  });

  testWidgets('Returning users do not see the welcome', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ExpenseApp(store: ExpenseStore.memory()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ExpencyView'), findsNothing);
  });

  testWidgets('Clear all data asks first, then starts over', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()
      ..setPayAmount(3000)
      ..setDarkMode(true);
    store.addFile(
      store.looseOf(FolderType.expense),
      EntryFile(name: 'Rent', value: 1000),
    );
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Clear all data'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // Cancel keeps everything.
    await tester.tap(find.text('Clear all data'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.payAmount, 3000);

    await tester.tap(find.text('Clear all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear everything'));
    await tester.pumpAndSettle();
    expect(store.payAmount, isNull);
    expect(store.expenseTotal, 0);
    expect(store.darkMode, isFalse);
    expect(store.looseOf(FolderType.expense).files, isEmpty);
    // Back on home, greeted like a new user.
    expect(find.text('Welcome to ExpencyView'), findsOneWidget);
  });

  testWidgets('Existing users see the update pop-up once', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // A save from before 1.2: has data, no seenVersion.
    final store = ExpenseStore.memory()
      ..loadForTest({'payAmount': 3000, 'payFrequency': 'monthly'});
    expect(store.needsUpdateNotice, isTrue);
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('ExpencyView has been updated'), findsOneWidget);
    expect(find.text('Welcome to ExpencyView'), findsNothing);

    await tester.tap(find.text('Add my budget'));
    await tester.pumpAndSettle();
    expect(find.text('Your current budget'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.needsUpdateNotice, isFalse);
    expect(store.payAmount, 3000); // data untouched

    // Not shown again.
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('ExpencyView has been updated'), findsNothing);
  });

  testWidgets('Update pop-up: Start fresh resets to the new-user welcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()
      ..loadForTest({'payAmount': 3000, 'payFrequency': 'monthly'});
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start fresh (reset my data)'));
    await tester.pumpAndSettle();
    expect(find.text('Clear all data?'), findsOneWidget);
    await tester.tap(find.text('Clear everything'));
    await tester.pumpAndSettle();
    expect(store.payAmount, isNull);
    expect(find.text('Welcome to ExpencyView'), findsOneWidget);
    expect(find.text('ExpencyView has been updated'), findsNothing);
  });

  testWidgets('New users get the welcome, not the update pop-up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()..seenWelcome = false;
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(find.text('ExpencyView has been updated'), findsNothing);
    expect(store.needsUpdateNotice, isFalse);
  });

  testWidgets('Welcome: no recommended question if income was skipped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory()..seenWelcome = false;
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start by adding your budget'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dialog-housing')), '900');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now')); // skip income
    await tester.pumpAndSettle();
    expect(find.text('Turn on the recommended budget?'), findsNothing);
    expect(store.showRecommended, isFalse);
  });

  testWidgets('Expenses reads "Other Expenses" when the budget is on home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory(); // current budget folder on by default
    await tester.pumpWidget(ExpenseApp(store: store));
    expect(title('Other Expenses'), findsOneWidget);

    store.setCurrentOnHome(false); // no Budget container
    await tester.pumpAndSettle();
    expect(title('Other Expenses'), findsNothing);
    expect(title('Expenses'), findsOneWidget);
  });
}
