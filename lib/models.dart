/// Data model for the expense tracker.
///
/// Mirrors "Expense math":
///   Folders: Expense = [bill.1, bill.2, ...], Saving = [Saving.N],
///            Subscription = [sub.1, ...]
///   Files:   each file's monthly value is added to its folder's total
///   Expense_Total = expenses + subscriptions + savings flagged as an expense
///   Income - Expense_Total = Remaining_Income
library;

enum FolderType {
  expense('Expenses'),
  subscription('Subscriptions'),
  savings('Savings'),

  /// Folders made by the guided tour (Housing, Needs...), shown in the
  /// Budget container at the top of home.
  budget('Budget');

  const FolderType(this.label);

  /// Section title on the home page.
  final String label;

  /// The containers listed under Budget on home, in order (each has its own
  /// show/hide switch in Settings).
  static const containers = [expense, subscription, savings];
}

/// How the user's money comes in. The entered amount is per paycheck
/// (or per year for salary) and is converted to monthly for all the math,
/// using simple months: weekly × 4, bi-weekly × 2.
/// [balance] is different: it is a one-off amount on hand, so nothing is
/// converted and the per-week / per-year breakdowns don't apply.
enum PayFrequency {
  monthly('Monthly', 12, 1, 'Monthly income'),
  weekly('Weekly', 52, 4, 'Weekly paycheck'),
  biweekly('Bi-weekly', 26, 2, 'Paycheck every 2 weeks'),
  salary('Salary', 1, 1 / 12, 'Yearly salary'),
  balance('Current balance', 0, 0, 'Current balance');

  const PayFrequency(this.label, this.perYear, this.perMonth, this.amountLabel);
  final String label;

  /// Paychecks per year (0 for [balance]); used for the yearly total.
  final int perYear;

  /// Paychecks counted per month: 4 weekly, 2 bi-weekly (0 for [balance]).
  final double perMonth;

  /// Label for the amount field in settings.
  final String amountLabel;

  bool get isBalance => this == PayFrequency.balance;
}

/// How often a subscription is charged. Totals are always per month.
enum BillingCycle {
  daily('Daily', 'day', 30),
  weekly('Weekly', 'wk', 4),
  monthly('Monthly', 'mo', 1),
  quarterly('Every 3 months', 'qtr', 1 / 3),
  yearly('Yearly', 'yr', 1 / 12);

  const BillingCycle(this.label, this.short, this.perMonth);
  final String label;

  /// Short suffix shown after a price, e.g. "$9.99 / mo".
  final String short;

  /// How many charges fall in an average month (a month = 30 days or
  /// 4 weeks, matching the pay math).
  final double perMonth;

  /// The choices offered for a regular expense.
  static const forExpenses = [daily, weekly, monthly, yearly];
}

/// Strips the time so day math works in whole calendar days.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

/// A single bill / savings deposit / subscription ("file").
class EntryFile {
  EntryFile({
    String? id,
    required this.name,
    required this.value,
    this.expiresOn,
    this.fromIncome = false,
    this.includeAsMonthlyExpense = false,
    this.paused = false,
    this.cycle = BillingCycle.monthly,
    this.category,
    this.saved,
    this.tourItem,
  }) : id = id ?? newId();

  final String id;
  String name;

  /// Amount per charge ([cycle]); for bills and savings this is monthly.
  double value;

  /// Calendar day this item removes itself. null = keep forever.
  DateTime? expiresOn;

  /// Savings only: this deposit is paid out of income, so it is subtracted
  /// from Remaining Income.
  bool fromIncome;

  /// Savings only: also count this amount toward the monthly expense total.
  bool includeAsMonthlyExpense;

  /// Paused items stay listed but count as $0 everywhere.
  bool paused;

  /// Subscriptions only: how often it is charged.
  BillingCycle cycle;

  /// Recommended-budget category this belongs to (e.g. "utilities"), so the
  /// Compare tab can total real spending per category. null = none.
  String? category;

  /// Savings only: how much has been saved so far (shown next to the item;
  /// used for "in a year").
  double? saved;

  /// Which guided-tour line made this item (e.g. "housing.rent"), so running
  /// the tour again updates it instead of adding a duplicate.
  String? tourItem;

  /// What this item costs in an average month (0 when paused).
  double get monthlyValue => paused ? 0 : value * cycle.perMonth;

  /// Whole calendar days until removal (0 or less = due today / overdue).
  int? daysLeft([DateTime? now]) =>
      expiresOn?.difference(dateOnly(now ?? DateTime.now())).inDays;

  bool isExpired([DateTime? now]) {
    final d = daysLeft(now);
    return d != null && d <= 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'value': value,
    'expiresOn': expiresOn?.toIso8601String(),
    'fromIncome': fromIncome,
    'includeAsMonthlyExpense': includeAsMonthlyExpense,
    'paused': paused,
    'cycle': cycle.name,
    'category': category,
    'saved': saved,
    'tourItem': tourItem,
  };

  factory EntryFile.fromJson(Map<String, dynamic> j) => EntryFile(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    value: (j['value'] as num?)?.toDouble() ?? 0,
    expiresOn: DateTime.tryParse(j['expiresOn'] as String? ?? ''),
    // Older saves had no flag; counting as an expense implied it.
    fromIncome:
        j['fromIncome'] as bool? ??
        (j['includeAsMonthlyExpense'] as bool? ?? false),
    includeAsMonthlyExpense: j['includeAsMonthlyExpense'] as bool? ?? false,
    paused: j['paused'] as bool? ?? false,
    cycle: BillingCycle.values.firstWhere(
      (c) => c.name == j['cycle'],
      orElse: () => BillingCycle.monthly,
    ),
    category: j['category'] as String?,
    saved: (j['saved'] as num?)?.toDouble(),
    tourItem: j['tourItem'] as String?,
  );
}

/// A category ("folder") that holds files.
class Folder {
  Folder({
    String? id,
    required this.name,
    required this.type,
    this.showCostOnMain = true,
    this.showAsSeparateContainer = false,
    this.collapsed = false,
    this.paused = false,
    this.loose = false,
    this.tourKey,
    List<EntryFile>? files,
  }) : id = id ?? newId(),
       files = files ?? [];

  final String id;
  String name;
  FolderType type;

  /// Show this folder's total next to its name on the home page.
  bool showCostOnMain;

  /// Savings only: show this folder as its own summary card at the top.
  bool showAsSeparateContainer;

  bool collapsed;

  /// Paused folders stay visible but count as $0 in every total.
  bool paused;

  /// The hidden list for items added straight to a container (no folder).
  /// Never shown as a folder itself.
  final bool loose;

  /// Which guided-tour step made this folder (e.g. "housing"); lets the tour
  /// find and update it later.
  final String? tourKey;

  final List<EntryFile> files;

  /// Monthly sum of the items that aren't paused (ignores the folder's own
  /// pause, so the header can still show what's on hold).
  double get total => files.fold(0, (sum, f) => sum + f.monthlyValue);

  /// What this folder adds to the Savings total (0 when paused).
  double get savingsContribution =>
      paused || type != FolderType.savings ? 0 : total;

  /// What this folder contributes to Expense_Total.
  double get expenseContribution => paused
      ? 0
      : type != FolderType.savings
      ? total
      : files
            .where((f) => f.includeAsMonthlyExpense)
            .fold(0, (sum, f) => sum + f.monthlyValue);

  /// What this folder takes out of income (for Remaining Income).
  double get incomeContribution => paused
      ? 0
      : type != FolderType.savings
      ? total
      : files
            .where((f) => f.fromIncome || f.includeAsMonthlyExpense)
            .fold(0, (sum, f) => sum + f.monthlyValue);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'showCostOnMain': showCostOnMain,
    'showAsSeparateContainer': showAsSeparateContainer,
    'collapsed': collapsed,
    'paused': paused,
    'loose': loose,
    'tourKey': tourKey,
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory Folder.fromJson(Map<String, dynamic> j) => Folder(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    type: FolderType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => FolderType.expense,
    ),
    showCostOnMain: j['showCostOnMain'] as bool? ?? true,
    showAsSeparateContainer: j['showAsSeparateContainer'] as bool? ?? false,
    collapsed: j['collapsed'] as bool? ?? false,
    paused: j['paused'] as bool? ?? false,
    loose: j['loose'] as bool? ?? false,
    tourKey: j['tourKey'] as String?,
    files: (j['files'] as List? ?? [])
        .map((e) => EntryFile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
