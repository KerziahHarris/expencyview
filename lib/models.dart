/// Data model for the expense tracker.
///
/// Mirrors "Expense math":
///   Folders: Expense = [bill.1, bill.2, ...], Saving = [Saving.N]
///   Files:   each file's value is added to its folder's total
///   Expense_Total = expenses + savings flagged as a monthly expense
///   Income - Expense_Total = Remaining_Income
library;

enum FolderType { expense, savings }

/// How often the user is paid. The entered amount is per paycheck
/// (or per year for salary) and is converted to monthly for all the math.
enum PayFrequency {
  weekly('Weekly', 52, 'Weekly paycheck'),
  biweekly('Bi-weekly', 26, 'Paycheck every 2 weeks'),
  monthly('Monthly', 12, 'Monthly income'),
  salary('Salary', 1, 'Yearly salary');

  const PayFrequency(this.label, this.perYear, this.amountLabel);
  final String label;

  /// Paychecks per year.
  final int perYear;

  /// Label for the amount field in settings.
  final String amountLabel;
}

/// Strips the time so day math works in whole calendar days.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

/// A single bill / savings deposit ("file").
class EntryFile {
  EntryFile({
    String? id,
    required this.name,
    required this.value,
    this.expiresOn,
    this.fromIncome = false,
    this.includeAsMonthlyExpense = false,
  }) : id = id ?? newId();

  final String id;
  String name;
  double value;

  /// Calendar day this item removes itself. null = keep forever.
  DateTime? expiresOn;

  /// Savings only: this deposit is paid out of income, so it is subtracted
  /// from Remaining Income.
  bool fromIncome;

  /// Savings only: also count this amount toward the monthly expense total.
  bool includeAsMonthlyExpense;

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

  final List<EntryFile> files;

  /// Sum of the items, whether or not the folder is paused.
  double get total => files.fold(0, (sum, f) => sum + f.value);

  /// What this folder adds to the Savings total (0 when paused).
  double get savingsContribution =>
      paused || type != FolderType.savings ? 0 : total;

  /// What this folder contributes to Expense_Total.
  double get expenseContribution => paused
      ? 0
      : type == FolderType.expense
      ? total
      : files
            .where((f) => f.includeAsMonthlyExpense)
            .fold(0, (sum, f) => sum + f.value);

  /// What this folder takes out of income (for Remaining Income).
  double get incomeContribution => paused
      ? 0
      : type == FolderType.expense
      ? total
      : files
            .where((f) => f.fromIncome || f.includeAsMonthlyExpense)
            .fold(0, (sum, f) => sum + f.value);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'showCostOnMain': showCostOnMain,
    'showAsSeparateContainer': showAsSeparateContainer,
    'collapsed': collapsed,
    'paused': paused,
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory Folder.fromJson(Map<String, dynamic> j) => Folder(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    type: j['type'] == 'savings' ? FolderType.savings : FolderType.expense,
    showCostOnMain: j['showCostOnMain'] as bool? ?? true,
    showAsSeparateContainer: j['showAsSeparateContainer'] as bool? ?? false,
    collapsed: j['collapsed'] as bool? ?? false,
    paused: j['paused'] as bool? ?? false,
    files: (j['files'] as List? ?? [])
        .map((e) => EntryFile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
