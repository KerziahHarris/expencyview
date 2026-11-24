import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'accessibility.dart';
import 'budget_page.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// What the tour asks about
// ---------------------------------------------------------------------------

/// One line the tour asks about ("Rent", "Car insurance"...).
class TourItem {
  const TourItem(
    this.key,
    this.name,
    this.info,
    this.category, {
    this.yearly = false,
  });

  /// Stable id saved on the item (EntryFile.tourItem), e.g. "housing.rent".
  final String key;
  final String name;

  /// Shown when the little (i) is tapped.
  final String info;

  /// Recommended-budget category it adds to on the Compare tab.
  final String? category;

  /// Asked per year (property tax, registration) and divided by 12.
  final bool yearly;
}

const _rentItems = [
  TourItem(
    'housing.rent.rent',
    'Rent',
    'What you pay your landlord each month.',
    'housing',
  ),
  TourItem(
    'housing.rent.insurance',
    'Renters insurance',
    'Covers your belongings if they are stolen or damaged. Often about '
        '\$10–\$25 a month. Leave blank if you don\'t have it.',
    'housing',
  ),
];

const _ownItems = [
  TourItem(
    'housing.own.mortgage',
    'Mortgage payment',
    'Your monthly home loan payment. If your property tax and insurance are '
        'already included in it, leave those boxes blank.',
    'housing',
  ),
  TourItem(
    'housing.own.tax',
    'Property tax',
    'The tax your city or county charges on your home. Enter what you pay '
        'in a whole year and we\'ll work out the monthly amount for you.',
    'housing',
    yearly: true,
  ),
  TourItem(
    'housing.own.insurance',
    'Homeowners insurance',
    'Protects your home and what\'s in it. Enter the monthly cost.',
    'housing',
  ),
  TourItem(
    'housing.own.hoa',
    'HOA fees',
    'Dues for a homeowners association, if your neighborhood or building '
        'has one.',
    'housing',
  ),
  TourItem(
    'housing.own.maintenance',
    'Home maintenance',
    'Money set aside for repairs and upkeep. A common rule of thumb is about '
        '1% of the home\'s value per year.',
    'housing',
  ),
];

const _utilityItems = [
  TourItem(
    'housing.util.electricity',
    'Electricity',
    'Your electric bill. If it changes through the year, use an average '
        'month.',
    'utilities',
  ),
  TourItem(
    'housing.util.gas',
    'Natural gas',
    'Gas for heating, hot water or cooking, if your home uses it.',
    'utilities',
  ),
  TourItem(
    'housing.util.water',
    'Water & sewer',
    'Your water bill. Some places bill every 2 or 3 months, so divide it '
        'down to one month.',
    'utilities',
  ),
  TourItem(
    'housing.util.trash',
    'Trash & recycling',
    'Garbage pickup, if you pay for it separately.',
    'utilities',
  ),
];

const _needItems = [
  TourItem(
    'needs.groceries',
    'Groceries',
    'Food and drinks you buy to make at home.',
    'groceries',
  ),
  TourItem('needs.phone', 'Phone', 'Your cell phone plan.', 'phone'),
  TourItem('needs.internet', 'Internet', 'Home internet / Wi-Fi.', 'internet'),
  TourItem(
    'needs.toiletries',
    'Toiletries',
    'Toothpaste, soap, shampoo, deodorant and similar.',
    'toiletries',
  ),
  TourItem(
    'needs.personal',
    'Personal care',
    'Haircuts, skin care and grooming.',
    'personal-care',
  ),
  TourItem(
    'needs.household',
    'Household supplies',
    'Toilet paper, paper towels, cleaning supplies, laundry detergent.',
    'household-supplies',
  ),
  TourItem(
    'needs.clothing',
    'Clothing',
    'Clothes and shoes, averaged out to a month.',
    'clothing',
  ),
  TourItem(
    'needs.health',
    'Health insurance',
    'What you pay for health insurance each month (if it comes out of your '
        'paycheck, you can leave this blank).',
    'health-care',
  ),
  TourItem(
    'needs.medical',
    'Medical & prescriptions',
    'Copays, medicine and other medical costs in a typical month.',
    'health-care',
  ),
  TourItem(
    'needs.childcare',
    'Childcare',
    'Daycare, babysitters or after-school care, if you have them.',
    null,
  ),
];

const _carItems = [
  TourItem(
    'transport.car.payment',
    'Car payment',
    'Your monthly car loan or lease payment.',
    'transportation',
  ),
  TourItem(
    'transport.car.insurance',
    'Car insurance',
    'If you pay every 6 months, divide that amount by 6.',
    'transportation',
  ),
  TourItem(
    'transport.car.gas',
    'Gas or charging',
    'Fuel (or charging an electric car) in a typical month.',
    'transportation',
  ),
  TourItem(
    'transport.car.tolls',
    'Tolls',
    'Toll roads and bridges you use regularly.',
    'transportation',
  ),
  TourItem(
    'transport.car.maintenance',
    'Maintenance & repairs',
    'Oil changes, tires and repairs. Setting a little aside each month '
        'helps when something breaks.',
    'transportation',
  ),
  TourItem(
    'transport.car.parking',
    'Parking',
    'Parking at home, work or downtown.',
    'transportation',
  ),
  TourItem(
    'transport.car.registration',
    'Registration',
    'Your yearly car registration or tags. Enter the yearly amount.',
    'transportation',
    yearly: true,
  ),
];

const _commuteItems = [
  TourItem(
    'transport.commute.transit',
    'Transit pass',
    'Bus, train or subway fares or a monthly pass.',
    'transportation',
  ),
  TourItem(
    'transport.commute.rideshare',
    'Rideshare & taxis',
    'Uber, Lyft or taxis in a typical month.',
    'transportation',
  ),
  TourItem(
    'transport.commute.bike',
    'Bike or scooter',
    'Bike-share or scooter rentals and upkeep.',
    'transportation',
  ),
];

const _wantItems = [
  TourItem(
    'wants.dining',
    'Dining out',
    'Restaurants, takeout, delivery and coffee.',
    'dining-out',
  ),
  TourItem(
    'wants.hobbies',
    'Hobbies',
    'Sports, crafts, games and other things you do for fun.',
    'entertainment',
  ),
  TourItem(
    'wants.gifts',
    'Gifts & donations',
    'Birthdays, holidays and giving to charity, averaged to a month.',
    'gifts-donations',
  ),
  TourItem(
    'wants.travel',
    'Travel',
    'Trips and vacations. Divide a yearly travel budget by 12.',
    'miscellaneous',
  ),
];

const _debtItems = [
  TourItem(
    'debt.student',
    'Student loans',
    'Your monthly student loan payment.',
    'extra-debt-payments',
  ),
  TourItem(
    'debt.extra',
    'Extra debt payments',
    'Anything you pay on top of the minimums to clear debt faster.',
    'extra-debt-payments',
  ),
];

const _savingItems = [
  TourItem(
    'savings.emergency',
    'Emergency fund',
    'Money for surprises like a job loss or a big repair. A common goal is '
        '3 to 6 months of expenses.',
    'emergency-fund',
  ),
  TourItem(
    'savings.general',
    'Savings',
    'Saving for goals like a car, a trip or a home.',
    'savings',
  ),
  TourItem(
    'savings.retirement',
    'Retirement',
    'A 401(k), IRA or other retirement savings you pay into yourself.',
    'retirement',
  ),
];

// ---------------------------------------------------------------------------
// Opening the tour
// ---------------------------------------------------------------------------

/// Opens the guided budget tour full screen.
Future<void> startTour(BuildContext context, ExpenseStore store) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TourPage(store: store),
      ),
    );

/// "Edit Budget": explains that single items can be edited directly, and
/// asks before running the whole tour again.
Future<void> confirmEditBudget(BuildContext context, ExpenseStore store) async {
  final hasBudget = store.foldersOf(FolderType.budget).isNotEmpty;
  if (!hasBudget) return startTour(context, store);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit your budget?'),
      content: const Text(
        'This walks you through each part of your budget again, with your '
        'current amounts already filled in.\n\n'
        'Just need to change one or two things? Close this and tap any item '
        'in your Budget folders to edit it on its own.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Start the tour'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) await startTour(context, store);
}

// ---------------------------------------------------------------------------
// Tour state (kept for the whole tour so Back keeps what was typed)
// ---------------------------------------------------------------------------

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

double? _parse(String t) {
  final v = double.tryParse(t.replaceAll(RegExp(r'[,\$ ]'), '').trim());
  return v == null || v <= 0 ? null : v;
}

/// A fixed line with its amount box (and "saved so far" for savings).
class _Line {
  _Line(this.item, {double? value, double? saved, bool withSaved = false})
    : amount = TextEditingController(
        text: value == null ? '' : _fmt(item.yearly ? value * 12 : value),
      ),
      saved = withSaved
          ? TextEditingController(text: saved == null ? '' : _fmt(saved))
          : null;

  final TourItem item;
  final TextEditingController amount;
  final TextEditingController? saved;

  /// Monthly amount entered (yearly items divided by 12), or null.
  double? get monthly {
    final v = _parse(amount.text);
    return v == null ? null : (item.yearly ? v / 12 : v);
  }

  void dispose() {
    amount.dispose();
    saved?.dispose();
  }
}

/// A user-added line ("Other", entertainment, a credit card, a subscription).
class _Custom {
  _Custom({String name = '', double? value})
    : name = TextEditingController(text: name),
      amount = TextEditingController(text: value == null ? '' : _fmt(value));

  final TextEditingController name;
  final TextEditingController amount;
  BillingCycle cycle = BillingCycle.monthly;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _TourData {
  _TourData(this.store) {
    // Income
    frequency = store.payFrequency;
    income = TextEditingController(
      text: store.payAmount == null ? '' : _fmt(store.payAmount!),
    );

    // Housing: owner if any owner lines were saved before.
    final housing = store.tourFolder('housing');
    owns =
        housing?.files.any(
          (f) => f.tourItem?.startsWith('housing.own.') ?? false,
        ) ??
        false;
    rent = _lines(housing, _rentItems);
    own = _lines(housing, _ownItems);
    utilities = _lines(housing, _utilityItems);
    housingOther = _customs(housing, 'housing.other', [
      ..._rentItems,
      ..._ownItems,
      ..._utilityItems,
    ]);

    final needsF = store.tourFolder('needs');
    needs = _lines(needsF, _needItems);
    needsOther = _customs(needsF, 'needs.other', _needItems);

    final transport = store.tourFolder('transport');
    hasCar =
        transport?.files.any(
          (f) => f.tourItem?.startsWith('transport.car.') ?? false,
        ) ??
        false;
    commutes =
        transport?.files.any(
          (f) => f.tourItem?.startsWith('transport.commute.') ?? false,
        ) ??
        false;
    car = _lines(transport, _carItems);
    commute = _lines(transport, _commuteItems);
    transportOther = _customs(transport, 'transport.other', [
      ..._carItems,
      ..._commuteItems,
    ]);

    final wantsF = store.tourFolder('wants');
    wants = _lines(wantsF, _wantItems);
    entertainment = [
      for (final f in wantsF?.files ?? const <EntryFile>[])
        if (f.tourItem == 'wants.ent') _Custom(name: f.name, value: f.value),
    ];
    wantsOther = _customs(
      wantsF,
      'wants.other',
      _wantItems,
      skip: {'wants.ent'},
    );

    final debt = store.tourFolder('debt');
    cards = [
      for (final f in debt?.files ?? const <EntryFile>[])
        if (f.tourItem == 'debt.card') _Custom(name: f.name, value: f.value),
    ];
    hasCards = cards.isNotEmpty ? true : null;
    debtLines = _lines(debt, _debtItems);
    debtOther = _customs(debt, 'debt.other', _debtItems, skip: {'debt.card'});

    final savingsF = store.tourFolder('savings');
    saving = [
      for (final item in _savingItems)
        () {
          final f = _find(savingsF, item.key);
          return _Line(item, value: f?.value, saved: f?.saved, withSaved: true);
        }(),
    ];
  }

  final ExpenseStore store;

  late PayFrequency frequency;
  late final TextEditingController income;

  late bool owns;
  late final List<_Line> rent, own, utilities;
  late final List<_Custom> housingOther;

  late final List<_Line> needs;
  late final List<_Custom> needsOther;

  late bool hasCar, commutes;
  late final List<_Line> car, commute;
  late final List<_Custom> transportOther;

  late final List<_Line> wants;
  late final List<_Custom> entertainment, wantsOther;
  final List<_Custom> subscriptions = [];

  /// null = not answered yet.
  bool? hasCards;
  late final List<_Custom> cards;
  late final List<_Line> debtLines;
  late final List<_Custom> debtOther;
  late final List<_Line> saving;

  static EntryFile? _find(Folder? f, String key) =>
      f?.files.where((e) => e.tourItem == key).firstOrNull;

  static List<_Line> _lines(Folder? f, List<TourItem> items) => [
    for (final item in items) _Line(item, value: _find(f, item.key)?.value),
  ];

  /// Items in the folder that aren't one of the fixed lines show up as
  /// "Other" rows (including ones added later from the home page).
  static List<_Custom> _customs(
    Folder? f,
    String key,
    List<TourItem> fixed, {
    Set<String> skip = const {},
  }) {
    final known = {for (final i in fixed) i.key, ...skip};
    return [
      for (final e in f?.files ?? const <EntryFile>[])
        if (!known.contains(e.tourItem)) _Custom(name: e.name, value: e.value),
    ];
  }

  List<_Line> get allLines => [
    ...rent,
    ...own,
    ...utilities,
    ...needs,
    ...car,
    ...commute,
    ...wants,
    ...debtLines,
    ...saving,
  ];

  List<_Custom> get allCustoms => [
    ...housingOther,
    ...needsOther,
    ...transportOther,
    ...entertainment,
    ...wantsOther,
    ...subscriptions,
    ...cards,
    ...debtOther,
  ];

  void dispose() {
    income.dispose();
    for (final l in allLines) {
      l.dispose();
    }
    for (final c in allCustoms) {
      c.dispose();
    }
  }

  // ---- turning what was typed into items ----

  static List<EntryFile> _fromLines(List<_Line> lines) => [
    for (final l in lines)
      if (l.monthly case final v?)
        EntryFile(
          name: l.item.name,
          value: v,
          category: l.item.category,
          tourItem: l.item.key,
          saved: l.saved == null ? null : _parse(l.saved!.text),
          fromIncome: l.saved != null,
        ),
  ];

  static List<EntryFile> _fromCustoms(
    List<_Custom> rows,
    String key,
    String? category,
  ) => [
    for (final r in rows)
      if (_parse(r.amount.text) case final v?)
        if (r.name.text.trim().isNotEmpty)
          EntryFile(
            name: r.name.text.trim(),
            value: v,
            category: category,
            tourItem: key,
          ),
  ];

  // ---- saving each step ----

  void saveIncome() {
    final v = _parse(income.text);
    if (v == null) return;
    store
      ..setPayFrequency(frequency)
      ..setPayAmount(v);
  }

  void saveHousing() => store.saveTourFolder(
    key: 'housing',
    name: 'Housing',
    type: FolderType.budget,
    items: [
      ..._fromLines(owns ? own : rent),
      ..._fromLines(utilities),
      ..._fromCustoms(housingOther, 'housing.other', 'housing'),
    ],
  );

  void saveNeeds() => store.saveTourFolder(
    key: 'needs',
    name: 'Everyday needs',
    type: FolderType.budget,
    items: [
      ..._fromLines(needs),
      ..._fromCustoms(needsOther, 'needs.other', null),
    ],
  );

  void saveTransport() => store.saveTourFolder(
    key: 'transport',
    name: 'Transportation',
    type: FolderType.budget,
    items: [
      if (hasCar) ..._fromLines(car),
      if (commutes) ..._fromLines(commute),
      ..._fromCustoms(transportOther, 'transport.other', 'transportation'),
    ],
  );

  void saveWants() {
    store.saveTourFolder(
      key: 'wants',
      name: 'Wants',
      type: FolderType.budget,
      items: [
        ..._fromLines(wants),
        ..._fromCustoms(entertainment, 'wants.ent', 'entertainment'),
        ..._fromCustoms(wantsOther, 'wants.other', 'miscellaneous'),
      ],
    );
    // Subscriptions go to the Subscriptions container (not Budget).
    store.addSubscriptions([
      for (final r in subscriptions)
        if (_parse(r.amount.text) case final v?)
          if (r.name.text.trim().isNotEmpty)
            EntryFile(
              name: r.name.text.trim(),
              value: v,
              cycle: r.cycle,
              category: 'entertainment',
              tourItem: 'wants.sub',
            ),
    ]);
    subscriptions.clear(); // added once, even if this step is saved again
  }

  void saveSavingsAndDebt() {
    store.saveTourFolder(
      key: 'debt',
      name: 'Debt',
      type: FolderType.budget,
      items: [
        if (hasCards ?? false)
          ..._fromCustoms(cards, 'debt.card', 'extra-debt-payments'),
        ..._fromLines(debtLines),
        ..._fromCustoms(debtOther, 'debt.other', 'extra-debt-payments'),
      ],
    );
    // Savings go to the Savings container (not Budget).
    store.saveTourFolder(
      key: 'savings',
      name: 'Savings plan',
      type: FolderType.savings,
      items: _fromLines(saving),
    );
  }
}

// ---------------------------------------------------------------------------
// The tour screen
// ---------------------------------------------------------------------------

enum _Step {
  comfort(
    'Make it comfortable',
    'Pick a text size and look that are easy for you to read.',
    'Comfort',
    Icons.accessibility_new,
  ),
  income(
    'Your income',
    'So we can show what\'s left after your budget.',
    'Income',
    Icons.account_balance_wallet_outlined,
  ),
  housing(
    'Housing',
    'Where you live and the bills that come with it.',
    'Housing',
    Icons.home_outlined,
  ),
  needs(
    'Everyday needs',
    'The regular things every household buys.',
    'Needs',
    Icons.shopping_basket_outlined,
  ),
  transport(
    'Getting around',
    'Car costs, transit and rides.',
    'Transportation',
    Icons.directions_car_outlined,
  ),
  wants(
    'Wants',
    'Fun and extras: nice to have, easy to trim.',
    'Wants',
    Icons.celebration_outlined,
  ),
  savings(
    'Savings & debt',
    'Paying your future self, and paying down debt.',
    'Savings & debt',
    Icons.savings_outlined,
  ),
  done(
    'All set!',
    'Here\'s your budget. You can change any item later.',
    'Finish',
    Icons.check_circle_outline,
  );

  const _Step(this.title, this.subtitle, this.short, this.icon);
  final String title;
  final String subtitle;

  /// Name on the "Next: ..." button.
  final String short;
  final IconData icon;

  /// Steps where you fill in amounts (they get the "how to" hint).
  bool get hasAmounts => this != comfort && this != income && this != done;
}

class TourPage extends StatefulWidget {
  const TourPage({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<TourPage> {
  late final _TourData _data = _TourData(widget.store);
  int _step = 0;

  _Step get _current => _Step.values[_step];

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  void _save() {
    switch (_current) {
      case _Step.comfort:
        break; // applied as you change it
      case _Step.income:
        _data.saveIncome();
      case _Step.housing:
        _data.saveHousing();
      case _Step.needs:
        _data.saveNeeds();
      case _Step.transport:
        _data.saveTransport();
      case _Step.wants:
        _data.saveWants();
      case _Step.savings:
        _data.saveSavingsAndDebt();
      case _Step.done:
        break;
    }
  }

  void _next({bool save = true}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (save) _save();
    if (_current == _Step.done) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _exit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the tour?'),
        content: const Text(
          'Steps you finished are already saved. You can come back anytime '
          'with Edit Budget.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final steps = _Step.values.length;
    final isDone = _current == _Step.done;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Leave the tour',
            icon: const Icon(Icons.close),
            onPressed: _exit,
          ),
          title: const Text('Budget tour'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / steps,
                        minHeight: 6,
                        backgroundColor: c.row,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Step ${_step + 1} of $steps',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey(_current),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _StepHeader(step: _current),
                  if (_current.hasAmounts) const _HowTo(),
                  const SizedBox(height: 14),
                  ..._body(),
                ],
              ),
            ),
            // Back · Skip this step · Next
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: c.section,
                  border: Border(top: BorderSide(color: c.cardBorder)),
                ),
                // The main action is big and full width; Back / Skip sit
                // underneath so the next move is always obvious.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _next,
                      iconAlignment: IconAlignment.end,
                      icon: Icon(isDone ? Icons.check : Icons.arrow_forward),
                      label: Text(
                        isDone
                            ? 'Finish'
                            : 'Next: ${_Step.values[_step + 1].short}',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Shrinks to fit with very large text on small phones.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_step > 0)
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: TextButton.icon(
                                onPressed: _back,
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text('Back'),
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        if (!isDone)
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: TextButton(
                                onPressed: () => _next(save: false),
                                child: const Text('Skip this step'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() => switch (_current) {
    _Step.comfort => [
      TextSizeControl(store: widget.store),
      const SizedBox(height: 14),
      ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => AppearanceSwitch(store: widget.store),
      ),
      const SizedBox(height: 14),
      Text(
        'You can change these later in Settings → Accessibility.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: context.colors.muted),
      ),
    ],
    _Step.income => _incomeStep(),
    _Step.housing => _housingStep(),
    _Step.needs => _needsStep(),
    _Step.transport => _transportStep(),
    _Step.wants => _wantsStep(),
    _Step.savings => _savingsStep(),
    _Step.done => _doneStep(),
  };

  // ---- steps ----

  List<Widget> _incomeStep() => [
    _Card(
      title: 'How do you get paid?',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in PayFrequency.values)
              ChoiceChip(
                label: Text(f.label),
                selected: _data.frequency == f,
                showCheckmark: false,
                onSelected: (_) => setState(() => _data.frequency = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('tour-income'),
          controller: _data.income,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            labelText: _data.frequency.amountLabel,
            helperText: _data.frequency.isBalance
                ? 'Money you have right now'
                : 'After taxes',
            prefixText: '\$ ',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _housingStep() => [
    _Card(
      title: 'Do you rent or own your home?',
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.apartment_outlined, size: 18),
              label: Text('I rent'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.house_outlined, size: 18),
              label: Text('I own'),
            ),
          ],
          selected: {_data.owns},
          onSelectionChanged: (s) => setState(() => _data.owns = s.first),
        ),
      ],
    ),
    _Card(
      title: _data.owns ? 'Your home' : 'Your rental',
      children: [for (final l in _data.owns ? _data.own : _data.rent) _row(l)],
    ),
    _Card(
      title: 'Utilities',
      children: [for (final l in _data.utilities) _row(l)],
    ),
    _customCard('Other housing costs', _data.housingOther, 'Other'),
  ];

  List<Widget> _needsStep() => [
    _Card(
      title: 'Everyday needs',
      children: [for (final l in _data.needs) _row(l)],
    ),
    _customCard('Other needs', _data.needsOther, 'Other'),
  ];

  List<Widget> _transportStep() => [
    _Card(
      title: 'How do you get around?',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.directions_car_outlined),
          title: const Text('I own or lease a vehicle'),
          value: _data.hasCar,
          onChanged: (v) => setState(() => _data.hasCar = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.directions_bus_outlined),
          title: const Text('I use transit or rideshare'),
          value: _data.commutes,
          onChanged: (v) => setState(() => _data.commutes = v),
        ),
      ],
    ),
    if (_data.hasCar)
      _Card(
        title: 'Your vehicle',
        children: [for (final l in _data.car) _row(l)],
      ),
    if (_data.commutes)
      _Card(
        title: 'Commuting',
        children: [for (final l in _data.commute) _row(l)],
      ),
    _customCard('Other transportation', _data.transportOther, 'Other'),
  ];

  List<Widget> _wantsStep() {
    final existing = widget.store.subscriptions.files;
    return [
      _Card(title: 'Wants', children: [for (final l in _data.wants) _row(l)]),
      _customCard(
        'Entertainment',
        _data.entertainment,
        'Add entertainment',
        hint: 'Movies, concerts, games, outings...',
        namePlaceholder: 'e.g. Movies',
      ),
      _customCard(
        'Subscriptions',
        _data.subscriptions,
        'Add a subscription',
        hint: existing.isEmpty
            ? 'Streaming, music, apps... These go in your Subscriptions list.'
            : 'Already in Subscriptions: '
                  '${existing.map((f) => f.name).join(', ')}. '
                  'Add any new ones here.',
        namePlaceholder: 'e.g. Netflix',
        withCycle: true,
      ),
      _customCard('Other wants', _data.wantsOther, 'Other'),
    ];
  }

  List<Widget> _savingsStep() {
    final inAYear = _data.saving.fold<double>(
      0,
      (s, l) => s + (_parse(l.saved!.text) ?? 0) + (l.monthly ?? 0) * 12,
    );
    return [
      _Card(
        title: 'Do you have credit cards?',
        children: [
          SegmentedButton<bool>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('No')),
              ButtonSegment(value: true, label: Text('Yes')),
            ],
            selected: {?_data.hasCards},
            onSelectionChanged: (s) => setState(() {
              _data.hasCards = s.isEmpty ? null : s.first;
              if (_data.hasCards == true && _data.cards.isEmpty) {
                _data.cards.add(_Custom());
              }
            }),
          ),
        ],
      ),
      if (_data.hasCards ?? false)
        _customCard(
          'Your credit cards',
          _data.cards,
          'Add a card',
          hint: 'What you pay on each card in a month.',
          namePlaceholder: 'e.g. Visa',
        ),
      _Card(
        title: 'Debt',
        children: [for (final l in _data.debtLines) _row(l)],
      ),
      _customCard('Other debt', _data.debtOther, 'Other'),
      _Card(
        title: 'Savings',
        subtitle: 'These go in your Savings container.',
        children: [
          for (final l in _data.saving) _row(l),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.trending_up,
                size: 18,
                color: context.colors.savingsGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'In a year: ${money(inAYear.roundToDouble())}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.savingsGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> _doneStep() {
    final store = widget.store;
    final c = context.colors;
    final made = [
      for (final key in ['housing', 'needs', 'transport', 'wants', 'debt'])
        ?store.tourFolder(key),
    ];
    final savingsPlan = store.tourFolder('savings');
    final total = made.fold<double>(0, (s, f) => s + f.total);
    return [
      _Card(
        title: 'Your Budget folders',
        children: [
          if (made.isEmpty)
            Text(
              'Nothing added yet. You can run this tour again anytime with '
              'Edit Budget.',
              style: TextStyle(color: c.muted),
            ),
          for (final f in made)
            _summaryRow(f.name, f.total, '${f.files.length} items'),
          if (made.isNotEmpty) ...[
            Divider(color: c.cardBorder),
            _summaryRow('Total per month', total, null, bold: true),
          ],
        ],
      ),
      if (savingsPlan != null)
        _Card(
          title: 'Savings plan',
          children: [
            _summaryRow(
              'Saving per month',
              savingsPlan.total,
              'In a year: ${money(store.savingsInAYear.roundToDouble())}',
            ),
          ],
        ),
      if (store.hasIncome)
        _Card(
          title: 'Want a guide to compare with?',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show the recommended budget'),
              subtitle: const Text(
                'Adds a Budget tab that suggests how to split your income '
                'and compares it with what you entered.',
              ),
              value: store.showRecommended,
              onChanged: (v) => setState(() => store.setShowRecommended(v)),
            ),
            // With the guide on, ask who it's for (it scales groceries,
            // toiletries, clothing... by household size).
            if (store.showRecommended) ...[
              const SizedBox(height: 8),
              Text(
                'How many people live in your household (including you)?',
                style: TextStyle(fontSize: 14, color: context.colors.text),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) => HouseholdStepper(store: store),
              ),
            ],
          ],
        ),
    ];
  }

  // ---- building blocks ----

  Widget _summaryRow(
    String label,
    double amount,
    String? note, {
    bool bold = false,
  }) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: c.text,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                if (note != null)
                  Text(note, style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          Text(
            money(amount.roundToDouble()),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(_Line l) => _AmountRow(
    key: ValueKey(l.item.key),
    line: l,
    onChanged: () => setState(() {}),
  );

  Widget _customCard(
    String title,
    List<_Custom> rows,
    String addLabel, {
    String? hint,
    String namePlaceholder = 'Name',
    bool withCycle = false,
  }) => _Card(
    title: title,
    subtitle: hint,
    children: [
      for (final (i, r) in rows.indexed)
        _CustomRow(
          key: ObjectKey(r),
          row: r,
          withCycle: withCycle,
          namePlaceholder: namePlaceholder,
          id: '$title-$i',
          onRemove: () => setState(() {
            rows.remove(r);
            r.dispose();
          }),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => rows.add(_Custom())),
          icon: const Icon(Icons.add, size: 18),
          label: Text(addLabel),
        ),
      ),
    ],
  );
}

/// Big friendly header for each step: icon, title and what it's about.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.expenseBlue.withValues(alpha: 0.22),
            c.savingsGreen.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.expenseBlue.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, size: 30, color: c.text),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: TextStyle(fontSize: 15, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "What to do" hint on steps with amounts.
class _HowTo extends StatelessWidget {
  const _HowTo();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tip(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.expenseBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
      child: Column(
        children: [
          tip(
            Icons.edit_outlined,
            'Type a monthly amount for what applies to you.',
          ),
          tip(Icons.remove, 'Leave anything that doesn\'t apply blank.'),
          tip(Icons.info_outline, 'Tap ⓘ to see what an item means.'),
        ],
      ),
    );
  }
}

/// A rounded panel with a title, like the containers on home.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: c.section,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Name with an (i) tip, and a "$" box (plus "saved so far" for savings).
class _AmountRow extends StatelessWidget {
  const _AmountRow({super.key, required this.line, required this.onChanged});

  final _Line line;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = line.item;
    final monthly = line.monthly;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: TextStyle(fontSize: 16, color: c.text),
                      ),
                    ),
                    _InfoTip(item.info),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MoneyBox(
                fieldKey: ValueKey('tour-${item.key}'),
                controller: line.amount,
                suffix: item.yearly ? '/ yr' : null,
                onChanged: onChanged,
              ),
            ],
          ),
          if (item.yearly && monthly != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '= ${money(double.parse(monthly.toStringAsFixed(2)))} a month',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: c.expenseBlue),
              ),
            ),
          if (line.saved != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saved so far',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MoneyBox(
                    fieldKey: ValueKey('tour-${item.key}-saved'),
                    controller: line.saved!,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A user-added line: name, amount (and how often, for subscriptions).
class _CustomRow extends StatelessWidget {
  const _CustomRow({
    super.key,
    required this.row,
    required this.onRemove,
    required this.id,
    this.withCycle = false,
    this.namePlaceholder = 'Name',
  });

  final _Custom row;
  final VoidCallback onRemove;

  /// "card title-row number", used for the boxes' keys.
  final String id;
  final bool withCycle;
  final String namePlaceholder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('custom-$id-name'),
              controller: row.name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                isDense: true,
                hintText: namePlaceholder,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MoneyBox(
            fieldKey: ValueKey('custom-$id-amount'),
            controller: row.amount,
            width: 110,
          ),
          if (withCycle) ...[
            const SizedBox(width: 6),
            StatefulBuilder(
              builder: (context, setLocal) => DropdownButton<BillingCycle>(
                value: row.cycle,
                underline: const SizedBox.shrink(),
                items: [
                  for (final c in BillingCycle.values)
                    DropdownMenuItem(value: c, child: Text('/ ${c.short}')),
                ],
                onChanged: (v) => setLocal(() => row.cycle = v ?? row.cycle),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 20, color: context.colors.muted),
          ),
        ],
      ),
    );
  }
}

class _MoneyBox extends StatelessWidget {
  const _MoneyBox({
    required this.controller,
    this.fieldKey,
    this.suffix,
    this.onChanged,
    this.width = 130,
  });

  final TextEditingController controller;
  final Key? fieldKey;
  final String? suffix;
  final VoidCallback? onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        isDense: true,
        prefixText: '\$ ',
        suffixText: suffix,
        hintText: '0',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
      ),
      onChanged: onChanged == null ? null : (_) => onChanged!(),
    ),
  );
}

/// Small (i) that shows a short explanation when tapped.
class _InfoTip extends StatelessWidget {
  const _InfoTip(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.tap,
    showDuration: const Duration(seconds: 8),
    preferBelow: false,
    margin: const EdgeInsets.symmetric(horizontal: 24),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Icon(Icons.info_outline, size: 18, color: context.colors.muted),
    ),
  );
}
