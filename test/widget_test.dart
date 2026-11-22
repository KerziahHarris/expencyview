import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:expensive/main.dart';
import 'package:expensive/budget.dart';
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
    // Simple months: weekly × 4, bi-weekly × 2; per year counts every check.
    expect(store.weeklyIncome, closeTo(1000, 0.001));
    expect(store.income, closeTo(4000, 0.001));
    expect(store.yearlyIncome, 52000);

    store.setPayFrequency(PayFrequency.biweekly);
    expect(store.weeklyIncome, closeTo(500, 0.001));
    expect(store.income, closeTo(2000, 0.001));
    expect(store.yearlyIncome, 26000);

    store
      ..setPayFrequency(PayFrequency.salary)
      ..setPayAmount(48000);
    expect(store.income, closeTo(4000, 0.001));
    expect(store.weeklyIncome, closeTo(1000, 0.001));
    expect(store.yearlyIncome, 48000);

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

  test('Subscriptions are normalized to monthly and count as expenses', () {
    final store = ExpenseStore.memory();
    final subs = store.subscriptions;
    store
      ..addFile(subs, EntryFile(name: 'Music', value: 10))
      ..addFile(
        subs,
        EntryFile(name: 'Cloud', value: 120, cycle: BillingCycle.yearly),
      )
      ..addFile(
        subs,
        EntryFile(name: 'Box', value: 30, cycle: BillingCycle.quarterly),
      )
      ..setIncome(1000);
    expect(store.expenseTotal, closeTo(30, 0.001)); // 10 + 10 + 10
    expect(store.whatsLeft, closeTo(970, 0.001));
  });

  test('Paused items are left out, the rest of the folder still counts', () {
    final store = ExpenseStore.memory();
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    final gym = EntryFile(name: 'Gym', value: 50);
    store
      ..addFolder(bills)
      ..addFile(bills, EntryFile(name: 'Rent', value: 1000))
      ..addFile(bills, gym);
    expect(store.expenseTotal, 1050);
    store.toggleFilePaused(gym);
    expect(store.expenseTotal, 1000);
    expect(bills.total, 1000);
  });

  test('Current balance replaces income, no weekly figures', () {
    final store = ExpenseStore.memory();
    expect(store.payFrequency, PayFrequency.monthly); // default
    final bills = Folder(name: 'Bills', type: FolderType.expense);
    store
      ..addFolder(bills)
      ..addFile(bills, EntryFile(name: 'Rent', value: 800))
      ..setPayFrequency(PayFrequency.balance)
      ..setPayAmount(2500);
    expect(store.income, 2500);
    expect(store.weeklyIncome, isNull);
    expect(store.yearlyIncome, isNull);
    expect(store.whatsLeft, 1700);
  });

  test('Recommended budget adds up and grows per-person costs', () {
    final one = recommendedBudget(4000, 1);
    final four = recommendedBudget(4000, 4);
    double sum(List<BudgetLine> l) => l.fold(0, (s, x) => s + x.amount);
    expect(sum(one), closeTo(4000, 0.01));
    expect(sum(four), closeTo(4000, 0.01));
    double groceries(List<BudgetLine> l) =>
        l.firstWhere((x) => x.category.name == 'Groceries').amount;
    double housing(List<BudgetLine> l) =>
        l.firstWhere((x) => x.category.name == 'Housing').amount;
    expect(groceries(four), greaterThan(groceries(one)));
    expect(housing(four), lessThan(housing(one)));
  });

  test('Recommended budget only counts when every switch is on', () {
    final store = ExpenseStore.memory()..setIncome(3000);
    store
      ..setShowRecommended(true)
      ..setRecommendedCounts(true);
    expect(store.expenseTotal, 0); // not on home yet
    store.setRecommendedOnHome(true);
    expect(store.expenseTotal, closeTo(3000, 0.01));
    store.setRecommendedCounts(false);
    expect(store.expenseTotal, 0); // guide only
  });

  test('Switched-off recommended lines are not counted', () {
    final store = ExpenseStore.memory()
      ..setIncome(3000)
      ..setShowRecommended(true)
      ..setRecommendedOnHome(true)
      ..setRecommendedCounts(true);
    final housing = store.recommendedLines.firstWhere(
      (l) => l.category.name == 'Housing',
    );
    expect(store.expenseTotal, closeTo(3000, 0.01));
    store.setRecommendedLineOn(housing.category.id, false);
    expect(store.expenseTotal, closeTo(3000 - housing.amount, 0.01));
    store.setRecommendedLineOn(housing.category.id, true);
    expect(store.expenseTotal, closeTo(3000, 0.01));
  });

  test('Current budget only counts when its switches are on', () {
    final store = ExpenseStore.memory()
      ..setIncome(3000)
      ..setShowRecommended(true)
      ..setActualSpending('housing', 1200)
      ..setActualSpending('groceries', 300);
    expect(store.currentBudget.map((e) => e.$1.name), ['Housing', 'Groceries']);
    expect(store.currentOnHome, isTrue); // on by default
    expect(store.recommendedOnHome, isFalse); // off by default
    expect(store.currentCounts, isTrue); // counted by default
    expect(store.expenseTotal, 1500);
    store.setCurrentCounts(false);
    expect(store.expenseTotal, 0);
    store.setCurrentCounts(true);
    expect(store.expenseTotal, 1500);
    store.setCurrentOnHome(false);
    expect(store.expenseTotal, 0); // hidden folders never count
    store.setCurrentOnHome(true);
    expect(store.whatsLeft, 1500);
  });

  test('Old subscription folders are merged into one list', () {
    final store = ExpenseStore.memory();
    final saved = {
      'folders': [
        {
          'name': 'Streaming',
          'type': 'subscription',
          'files': [
            {'name': 'Music', 'value': 10},
          ],
        },
        {
          'name': 'Apps',
          'type': 'subscription',
          'paused': true,
          'files': [
            {'name': 'Notes', 'value': 5},
          ],
        },
      ],
    };
    store.loadForTest(saved);
    expect(store.foldersOf(FolderType.subscription), isEmpty); // no folders
    expect(
      store.folders.where((f) => f.type == FolderType.subscription),
      hasLength(1),
    );
    expect(store.subscriptions.files.map((f) => f.name), ['Music', 'Notes']);
    expect(store.expenseTotal, 10); // the paused folder's item stays paused
  });

  test('Turning off the recommended budget turns off its folder too', () {
    final store = ExpenseStore.memory()
      ..setIncome(3000)
      ..setShowRecommended(true)
      ..setRecommendedOnHome(true);
    store.setShowRecommended(false);
    expect(store.recommendedOnHome, isFalse);
    // Turning it back on doesn't bring the folder back by itself.
    store.setShowRecommended(true);
    expect(store.recommendedOnHome, isFalse);
  });

  test('A hotfix does not bring the update pop-up back', () {
    final store = ExpenseStore.memory()
      ..loadForTest({'payAmount': 3000, 'seenVersion': '1.2'});
    expect(appVersion, '1.2.1');
    expect(store.needsUpdateNotice, isFalse);
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
