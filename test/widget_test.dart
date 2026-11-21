import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:expensive/main.dart';
import 'package:expensive/models.dart';
import 'package:expensive/store.dart';

void main() {
  test('Expense math: Income - Expense_Total = Remaining_Income', () {
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    final savings = Folder(name: 'Savings', type: FolderType.savings);
    store
      ..addFolder(bills)
      ..addFolder(savings)
      ..addFile(bills, EntryFile(name: 'Rent', value: 1000))
      ..addFile(bills, EntryFile(name: 'Car payment', value: 117.28))
      ..addFile(bills, EntryFile(name: 'Car insurance', value: 67.28))
      ..addFile(savings, EntryFile(name: 'Savings', value: 50))
      ..addFile(
        savings,
        EntryFile(name: 'Emergency', value: 20, includeAsMonthlyExpense: true),
      )
      ..setIncome(3000);

    expect(store.expenseTotal, closeTo(1204.56, 0.001));
    expect(store.savingsTotal, 70);
    expect(store.whatsLeft, closeTo(1795.44, 0.001));
  });

  test('Savings marked "from income" lower Remaining Income only', () {
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    final savings = Folder(name: 'Savings', type: FolderType.savings);
    store
      ..addFolder(bills)
      ..addFolder(savings)
      ..addFile(bills, EntryFile(name: 'Rent', value: 1000))
      ..addFile(savings, EntryFile(name: 'Gift', value: 40))
      ..addFile(savings, EntryFile(name: 'IRA', value: 200, fromIncome: true))
      ..setIncome(3000);

    expect(store.expenseTotal, 1000); // not an expense
    expect(store.whatsLeft, 1800); // 3000 - 1000 - 200
    expect(store.savingsTotal, 240);

    // Old data: "include as expense" implies it comes out of income.
    final legacy = EntryFile.fromJson({
      'name': 'Old',
      'value': 10,
      'includeAsMonthlyExpense': true,
    });
    expect(legacy.fromIncome, isTrue);
  });

  test('Pay frequency converts the entered amount', () {
    final store = ExpenseStore.memory()
      ..setPayFrequency(PayFrequency.weekly)
      ..setPayAmount(1000);
    expect(store.weeklyIncome, closeTo(1000, 0.001));
    expect(store.income, closeTo(1000 * 52 / 12, 0.001));

    store.setPayFrequency(PayFrequency.biweekly);
    expect(store.weeklyIncome, closeTo(500, 0.001));
    expect(store.income, closeTo(1000 * 26 / 12, 0.001));

    store
      ..setPayFrequency(PayFrequency.salary)
      ..setPayAmount(52000);
    expect(store.weeklyIncome, closeTo(1000, 0.001));
    expect(store.income, closeTo(52000 / 12, 0.001));
    expect(store.yearlyIncome, 52000);

    store
      ..setPayFrequency(PayFrequency.monthly)
      ..setPayAmount(4000);
    expect(store.income, closeTo(4000, 0.001));
  });

  test('Paused folders are left out of every total', () {
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    final gym = Folder(name: 'Gym', type: FolderType.expense);
    final ira = Folder(name: 'IRA', type: FolderType.savings);
    store
      ..addFolder(bills)
      ..addFolder(gym)
      ..addFolder(ira)
      ..addFile(bills, EntryFile(name: 'Rent', value: 1000))
      ..addFile(gym, EntryFile(name: 'Membership', value: 50))
      ..addFile(ira, EntryFile(name: 'Deposit', value: 200, fromIncome: true))
      ..setIncome(3000);
    expect(store.whatsLeft, 1750);

    store
      ..togglePaused(gym)
      ..togglePaused(ira);
    expect(store.expenseTotal, 1000);
    expect(store.savingsTotal, 0);
    expect(store.whatsLeft, 2000);
    expect(gym.total, 50); // items are kept, just not counted

    store.togglePaused(gym);
    expect(store.expenseTotal, 1050);
  });

  test('Expired items remove themselves', () {
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    final today = dateOnly(DateTime.now());
    store
      ..addFolder(bills)
      ..addFile(bills, EntryFile(name: 'Keep', value: 10))
      ..addFile(
        bills,
        EntryFile(
          name: 'Later',
          value: 20,
          expiresOn: today.add(const Duration(days: 3)),
        ),
      )
      ..addFile(bills, EntryFile(name: 'Gone', value: 30, expiresOn: today));

    store.purgeExpired();
    expect(bills.files.map((f) => f.name), ['Keep', 'Later']);

    store.purgeExpired(today.add(const Duration(days: 3)));
    expect(bills.files.map((f) => f.name), ['Keep']);
  });

  testWidgets('Home shows totals; chart button appears with income', (
    tester,
  ) async {
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    store
      ..addFolder(bills)
      ..addFile(bills, EntryFile(name: 'Rent', value: 1000));

    await tester.pumpWidget(ExpenseApp(store: store));
    expect(find.text('Monthly Expense'), findsOneWidget);
    expect(find.text('\$1,000'), findsNWidgets(2)); // card + row
    expect(find.text('Rent'), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_rounded), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsNothing);

    store.setIncome(2500);
    await tester.pump();
    expect(find.text('Remaining Income'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('\$1,500'), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pie_chart_rounded));
    await tester.pump();
    expect(find.text('Where your money goes'), findsOneWidget);
  });
}
