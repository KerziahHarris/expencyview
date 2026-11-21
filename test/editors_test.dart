import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:expensive/main.dart';
import 'package:expensive/models.dart';
import 'package:expensive/store.dart';

void main() {
  testWidgets('Add a folder and a file through the UI', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ExpenseStore.memory();
    await tester.pumpWidget(ExpenseApp(store: store));

    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();
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
    expect(store.folders.first.files.first.daysLeft(), 30);
    expect(find.textContaining('Removes in 30 days'), findsOneWidget);

    // Savings folder shows the extra toggles.
    await tester.tap(find.text('Add Savings'));
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
    expect(store.folders, hasLength(1));

    await tester.tap(find.byTooltip('Folder options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(store.folders, isEmpty);
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
    expect(find.text('Version 1'), findsOneWidget);
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
    expect(Theme.of(ctx()).brightness, Brightness.dark);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Dark mode'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(store.darkMode, isFalse);
    expect(Theme.of(ctx()).brightness, Brightness.light);
  });
}
