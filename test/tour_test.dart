import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:expensive/main.dart';
import 'package:expensive/models.dart';
import 'package:expensive/store.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Scrolls the tour's list until [finder] is built and visible.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(ListView).last,
    const Offset(0, -250),
  );
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await reveal(tester, f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.textContaining('Next:'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Welcome is a full screen with tour / skip', (tester) async {
    phone(tester);
    final store = ExpenseStore.memory()..seenWelcome = false;
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ExpencyView'), findsOneWidget);
    expect(find.text('A place to view your expenses.'), findsOneWidget);
    // A screen, not a pop-up: nothing to tap behind it.
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Start the guided tour'), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(store.seenWelcome, isTrue);
    expect(find.text('Welcome to ExpencyView'), findsNothing);
  });

  testWidgets('Guided tour builds folders in the right containers', (
    tester,
  ) async {
    phone(tester);
    final store = ExpenseStore.memory()..seenWelcome = false;
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start the guided tour'));
    await tester.pumpAndSettle();

    // 1. Comfort (accessibility).
    expect(find.text('Make it comfortable'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Step 1 of 8'), findsOneWidget);
    await next(tester);

    // 2. Income.
    await type(tester, 'tour-income', '4000');
    await next(tester);
    expect(store.income, 4000);

    // 3. Housing: owner, property tax per year → monthly.
    await tester.tap(find.text('I own'));
    await tester.pumpAndSettle();
    await type(tester, 'tour-housing.own.mortgage', '1500');
    await type(tester, 'tour-housing.own.tax', '2400');
    expect(find.text('= \$200 a month'), findsOneWidget);
    await type(tester, 'tour-housing.util.electricity', '90');
    await next(tester);
    final housing = store.tourFolder('housing')!;
    expect(housing.type, FolderType.budget);
    expect(housing.files.map((f) => f.name), [
      'Mortgage payment',
      'Property tax',
      'Electricity',
    ]);
    expect(housing.total, 1790); // 1500 + 200 + 90

    // 4. Needs: skip this step.
    await tester.tap(find.text('Skip this step'));
    await tester.pumpAndSettle();
    expect(store.tourFolder('needs'), isNull);

    // 5. Transportation: both car and transit.
    await tester.tap(find.text('I own or lease a vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I use transit or rideshare'));
    await tester.pumpAndSettle();
    await type(tester, 'tour-transport.car.gas', '120');
    await type(tester, 'tour-transport.commute.transit', '50');
    await next(tester);
    expect(store.tourFolder('transport')!.total, 170);

    // 6. Wants: a subscription goes to Subscriptions, not Budget.
    await reveal(tester, find.text('Add a subscription'));
    await tester.tap(find.text('Add a subscription'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-Subscriptions-0-name')),
      'Music',
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-Subscriptions-0-amount')),
      '11',
    );
    await type(tester, 'tour-wants.dining', '80');
    await next(tester);
    expect(store.tourFolder('wants')!.files.single.name, 'Dining out');
    expect(store.subscriptions.files.single.name, 'Music');

    // 7. Savings & debt: savings go to the Savings container.
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-Your credit cards-0-name')),
      'Visa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-Your credit cards-0-amount')),
      '60',
    );
    await type(tester, 'tour-savings.emergency', '100');
    await type(tester, 'tour-savings.emergency-saved', '500');
    expect(find.text('In a year: \$1,700'), findsOneWidget); // 500 + 12×100
    await next(tester);
    expect(store.tourFolder('debt')!.files.single.name, 'Visa');
    final plan = store.tourFolder('savings')!;
    expect(plan.type, FolderType.savings);
    expect(plan.files.single.saved, 500);
    expect(store.savingsInAYear, 1700);

    // 8. Done: offer the recommended budget, then finish.
    expect(find.text('All set!'), findsOneWidget);
    await reveal(tester, find.text('Show the recommended budget'));
    await tester.tap(find.text('Show the recommended budget'));
    await tester.pumpAndSettle();
    expect(store.showRecommended, isTrue);
    // Then: who's in the household.
    expect(
      find.text('How many people live in your household (including you)?'),
      findsOneWidget,
    );
    final household = find.byKey(const ValueKey('household-size'));
    await reveal(tester, household);
    await tester.enterText(household, '3');
    await tester.pump();
    expect(store.householdSize, 3);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    // Home: Budget folders (no Savings plan or subscription duplicated).
    expect(find.textContaining('Housing ·'), findsOneWidget);
    await reveal(tester, find.textContaining('Savings plan ·'));
    expect(find.textContaining('Savings plan ·'), findsOneWidget);
    expect(store.foldersOf(FolderType.budget).map((f) => f.tourKey), [
      'housing',
      'transport',
      'wants',
      'debt',
    ]);
    expect(
      find.textContaining('In a year: \$1,700', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Running the tour again updates instead of duplicating', (
    tester,
  ) async {
    phone(tester);
    final store = ExpenseStore.memory()..setPayAmount(3000);
    store.saveTourFolder(
      key: 'housing',
      name: 'Housing',
      type: FolderType.budget,
      items: [
        EntryFile(name: 'Rent', value: 1000, tourItem: 'housing.rent.rent'),
      ],
    );
    await tester.pumpWidget(ExpenseApp(store: store));

    // Edit Budget asks first, and explains single-item editing.
    await tester.tap(find.text('Edit Budget'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tap any item'), findsOneWidget);
    await tester.tap(find.text('Start the tour'));
    await tester.pumpAndSettle();

    await next(tester); // comfort
    await next(tester); // income
    // Rent is prefilled; change it.
    final rent = find.byKey(const ValueKey('tour-housing.rent.rent'));
    await reveal(tester, rent);
    expect(tester.widget<TextField>(rent).controller!.text, '1000');
    await tester.enterText(rent, '1100');
    await next(tester);
    expect(store.foldersOf(FolderType.budget), hasLength(1));
    expect(store.tourFolder('housing')!.files.single.value, 1100);
  });

  testWidgets('Compare totals budget items by category', (tester) async {
    phone(tester);
    final store = ExpenseStore.memory()
      ..setPayAmount(4000)
      ..setShowRecommended(true);
    final housingGuide = store.recommendedLines
        .firstWhere((l) => l.category.id == 'housing')
        .amount
        .roundToDouble();
    store.saveTourFolder(
      key: 'housing',
      name: 'Housing',
      type: FolderType.budget,
      items: [
        EntryFile(name: 'Rent', value: housingGuide + 60, category: 'housing'),
        EntryFile(name: 'Renters insurance', value: 40, category: 'housing'),
      ],
    );
    expect(store.categorySpending('housing'), housingGuide + 100);
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.tap(find.byTooltip('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.text('Over by \$100'), findsOneWidget);
    expect(find.text('1 of 19 categories filled in'), findsOneWidget);
  });

  testWidgets('Accessibility: text size slider with preview', (tester) async {
    phone(tester);
    final store = ExpenseStore.memory();
    expect(store.textScale, 1.1); // a bit larger by default
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Accessibility'));
    await tester.tap(find.text('Accessibility'));
    await tester.pumpAndSettle();
    expect(find.text('Preview'), findsOneWidget);

    // Drag to the far right = the largest size, applied on release.
    await tester.drag(
      find.byKey(const ValueKey('text-size')),
      const Offset(2000, 0),
    );
    await tester.pumpAndSettle();
    expect(store.textScale, ExpenseStore.maxTextScale);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(store.textScale, ExpenseStore.defaultTextScale);
  });

  testWidgets('Expenses can be daily / weekly / yearly; optional breakdown', (
    tester,
  ) async {
    phone(tester);
    final store = ExpenseStore.memory()..setCurrentOnHome(false);
    await tester.pumpWidget(ExpenseApp(store: store));

    await tester.tap(find.text('Add').first); // Other Expenses → New expense
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Coffee');
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5');
    await tester.tap(find.byKey(const ValueKey('cycle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    expect(find.text('Counted as \$150 a month'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.expenseTotal, 150); // 5 × 30
    expect(find.text(' / day'), findsOneWidget);

    // Faded breakdown under Monthly Expense: off by default.
    expect(find.text('\$5 / day'), findsNothing);
    store.setShowCycleCosts(true);
    await tester.pumpAndSettle();
    expect(find.text('\$5 / day'), findsOneWidget);
  });

  testWidgets("What's New? from App Info and the update pop-up", (
    tester,
  ) async {
    phone(tester);
    final store = ExpenseStore.memory()
      ..loadForTest({'payAmount': 3000, 'seenVersion': '1.2'});
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('ExpencyView has been updated'), findsOneWidget);
    await tester.tap(find.text("What's New?"));
    await tester.pumpAndSettle();
    expect(find.text('Guided tour'), findsOneWidget);
    expect(find.textContaining('count'), findsNothing); // no tracking item
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('App Info'));
    await tester.tap(find.text('App Info'));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.3'), findsOneWidget);
    await reveal(tester, find.text("What's New?"));
    await tester.tap(find.text("What's New?"));
    await tester.pumpAndSettle();
    expect(find.text("What's New in 1.3"), findsOneWidget);
  });

  testWidgets('Compare: Edit, type into boxes, Save', (tester) async {
    phone(tester);
    final store = ExpenseStore.memory()
      ..setPayAmount(4000)
      ..setShowRecommended(true);
    store.saveTourFolder(
      key: 'housing',
      name: 'Housing',
      type: FolderType.budget,
      items: [
        EntryFile(name: 'Rent', value: 1000, category: 'housing'),
        EntryFile(name: 'Electricity', value: 80, category: 'utilities'),
      ],
    );
    final rent = store.tourFolder('housing')!.files.first;
    final power = store.tourFolder('housing')!.files.last;
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.tap(find.byTooltip('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.text('people'), findsNothing); // 1 person
    expect(find.text('person'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(ValueKey('edit-${rent.id}')));
    expect(
      tester
          .widget<TextField>(find.byKey(ValueKey('edit-${rent.id}')))
          .controller!
          .text,
      '1000',
    );
    await tester.enterText(find.byKey(ValueKey('edit-${rent.id}')), '1150');
    await tester.enterText(find.byKey(ValueKey('edit-${power.id}')), '');
    await reveal(tester, find.byKey(const ValueKey('edit-new-groceries')));
    await tester.enterText(
      find.byKey(const ValueKey('edit-new-groceries')),
      '300',
    );
    // Nothing changes until Save.
    expect(rent.value, 1000);
    await tester.tap(find.text('Save').first);
    await tester.pumpAndSettle();

    expect(rent.value, 1150);
    expect(store.categorySpending('utilities'), isNull); // cleared = removed
    expect(store.categorySpending('groceries'), 300);
    final mine = store
        .foldersOf(FolderType.budget)
        .firstWhere((f) => f.name == 'My budget');
    expect(mine.files.single.name, 'Groceries');
    // Back to view mode: the boxes are gone.
    expect(find.byKey(ValueKey('edit-${rent.id}')), findsNothing);
  });

  testWidgets('Compare: Cancel throws away edits', (tester) async {
    phone(tester);
    final store = ExpenseStore.memory()
      ..setPayAmount(4000)
      ..setShowRecommended(true);
    store.saveTourFolder(
      key: 'housing',
      name: 'Housing',
      type: FolderType.budget,
      items: [EntryFile(name: 'Rent', value: 1000, category: 'housing')],
    );
    final rent = store.tourFolder('housing')!.files.single;
    await tester.pumpWidget(ExpenseApp(store: store));
    await tester.tap(find.byTooltip('Budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(ValueKey('edit-${rent.id}')));
    await tester.enterText(find.byKey(ValueKey('edit-${rent.id}')), '5');
    await tester.dragUntilVisible(
      find.text('Cancel'),
      find.byType(ListView).last,
      const Offset(0, 250), // back up the page
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(rent.value, 1000);
  });

  testWidgets('Budget container has no "counted" line', (tester) async {
    phone(tester);
    final store = ExpenseStore.memory();
    store.saveTourFolder(
      key: 'housing',
      name: 'Housing',
      type: FolderType.budget,
      items: [EntryFile(name: 'Rent', value: 1000)],
    );
    await tester.pumpWidget(ExpenseApp(store: store));
    expect(find.textContaining('in your totals'), findsNothing);
  });
}
