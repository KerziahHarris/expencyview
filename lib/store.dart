import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'budget.dart';
import 'models.dart';

/// Current app version (shown on App Info; drives the update pop-up).
const appVersion = '1.2';

/// App state + persistence. Widgets listen to it with ListenableBuilder.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore._(this._prefs) {
    _normalizeSubscriptions();
  }

  static const _key = 'expense_tracker_v1';
  final SharedPreferences? _prefs;

  final List<Folder> folders = [];

  /// Amount the user entered: monthly income (default), one paycheck
  /// (weekly / bi-weekly), the yearly salary, or a current balance.
  /// null = not entered yet.
  double? payAmount;

  PayFrequency payFrequency = PayFrequency.monthly;

  /// True when a current balance is used instead of a recurring income.
  bool get usesBalance => payFrequency.isBalance;

  double? get _yearly => payAmount == null || usesBalance
      ? null
      : payAmount! * payFrequency.perYear;

  /// The amount every total on home is measured against: monthly income, or
  /// the current balance as-is.
  double? get income => usesBalance
      ? payAmount
      : _yearly == null
      ? null
      : _yearly! / 12;

  /// Income per week (null in balance mode).
  double? get weeklyIncome => _yearly == null ? null : _yearly! / 52;

  /// Income per year (null in balance mode).
  double? get yearlyIncome => _yearly;

  /// Which home-page containers are shown (Settings switches).
  final Map<FolderType, bool> _showSection = {
    for (final t in FolderType.values) t: true,
  };
  bool showsSection(FolderType t) => _showSection[t] ?? true;

  /// Recommended budget: Budget tab on/off, household size, and whether it
  /// also appears as a read-only folder on home (counted or guide-only).
  bool showRecommended = false;
  int householdSize = 1;
  bool recommendedOnHome = false;
  bool recommendedCounts = false;

  /// Recommended lines switched off on home (by category id); they don't
  /// count even when the recommended budget is counted.
  final Set<String> recommendedOff = {};

  /// Current budget folder on home (built from [actualSpending]) and
  /// whether it counts in totals.
  bool currentOnHome = true;
  bool currentCounts = true;

  /// What the user says they really spend per month, by category id
  /// (Budget tab → Compare). Missing = not filled in.
  final Map<String, double> actualSpending = {};

  /// Settings toggle: show "Remaining Income" (income - expenses) on home.
  bool showWhatsLeft = true;

  /// Settings toggle: dark (default, the original look) or light mode.
  bool darkMode = false;

  /// False until a first-time user has seen (or dismissed) the welcome
  /// pop-up. Existing saves count as seen.
  bool seenWelcome = true;

  /// The app version whose "what's new" pop-up this user has seen. Saves from
  /// before 1.2 have none, so existing users get the update pop-up once.
  String? seenVersion = appVersion;

  /// True when an existing user hasn't seen this version's update pop-up.
  bool get needsUpdateNotice => seenWelcome && seenVersion != appVersion;

  static Future<ExpenseStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = ExpenseStore._(prefs);
    final raw = prefs.getString(_key);
    // First time on this device: welcome pop-up (not the update one).
    if (raw == null) store.seenWelcome = false;
    if (raw != null) {
      try {
        store._fromJson(jsonDecode(raw) as Map<String, dynamic>);
        store.purgeExpired();
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
      }
    }
    return store;
  }

  /// Loads saved data into this store (tests only).
  @visibleForTesting
  void loadForTest(Map<String, dynamic> json) => _fromJson(json);

  /// In-memory store for tests.
  @visibleForTesting
  factory ExpenseStore.memory() => ExpenseStore._(null);

  // ---------- Math (see "Expense math") ----------

  /// Recommended budget lines for the current income and household.
  List<BudgetLine> get recommendedLines =>
      hasIncome ? recommendedBudget(income!, householdSize) : const [];

  /// True when the recommended folder is on home and set to count.
  bool get recommendedIsCounted =>
      showRecommended && recommendedOnHome && recommendedCounts && hasIncome;

  /// What the recommended folder adds to totals (0 unless counted; lines
  /// switched off on home are skipped).
  double get recommendedContribution => recommendedIsCounted
      ? recommendedLines
            .where((l) => !recommendedOff.contains(l.category.id))
            .fold(0, (sum, l) => sum + l.amount)
      : 0;

  /// The user's own budget: categories with an amount entered, in the
  /// standard category order.
  List<(BudgetCategory, double)> get currentBudget => [
    for (final c in budgetCategories)
      if (actualSpending[c.id] case final amount?) (c, amount),
  ];

  /// True when the current-budget folder is on home and set to count.
  bool get currentIsCounted => currentOnHome && currentCounts;

  /// What the current-budget folder adds to totals (0 unless counted).
  double get currentContribution =>
      currentIsCounted ? currentBudget.fold(0, (sum, e) => sum + e.$2) : 0;

  /// The Budget container on home is shown when either budget folder is.
  bool get showsBudgetSection =>
      currentOnHome || (showRecommended && recommendedOnHome && hasIncome);

  /// Expense_Total: expenses + subscriptions + savings flagged as expenses
  /// (+ the recommended budget when it is set to count).
  double get expenseTotal =>
      folders.fold<double>(0, (sum, f) => sum + f.expenseContribution) +
      recommendedContribution +
      currentContribution;

  /// Total going toward savings each month.
  double get savingsTotal =>
      folders.fold(0, (sum, f) => sum + f.savingsContribution);

  bool get hasIncome => income != null && income! > 0;

  /// Remaining_Income = Income - Expense_Total - savings paid from income.
  double get whatsLeft => (income ?? 0) - incomeUsed;

  /// Remaining Income spread over a week (monthly × 12 ÷ 52). Not meaningful
  /// in balance mode.
  double get whatsLeftWeekly => whatsLeft * 12 / 52;

  /// Everything paid out of income: expenses + savings flagged "from income".
  double get incomeUsed =>
      folders.fold<double>(0, (sum, f) => sum + f.incomeContribution) +
      recommendedContribution +
      currentContribution;

  /// The real (visible) folders in a container.
  Iterable<Folder> foldersOf(FolderType t) =>
      folders.where((f) => f.type == t && !f.loose);

  /// A container's monthly total: its loose items plus every folder that
  /// isn't paused.
  double containerTotal(FolderType t) => folders
      .where((f) => f.type == t && !f.paused)
      .fold(0, (sum, f) => sum + f.total);

  // ---------- Mutations ----------

  void addFolder(Folder f) {
    folders.add(f);
    _changed();
  }

  void updateFolder() => _changed();

  void deleteFolder(Folder f) {
    folders.remove(f);
    _changed();
  }

  void togglePaused(Folder f) {
    f.paused = !f.paused;
    _changed();
  }

  void toggleFilePaused(EntryFile f) {
    f.paused = !f.paused;
    _changed();
  }

  void toggleCollapsed(Folder f) {
    f.collapsed = !f.collapsed;
    _changed();
  }

  void addFile(Folder folder, EntryFile file) {
    folder.files.add(file);
    _changed();
  }

  void deleteFile(Folder folder, EntryFile file) {
    folder.files.remove(file);
    _changed();
  }

  /// Removes every file whose "remove after" day has arrived.
  void purgeExpired([DateTime? now]) {
    var removed = false;
    for (final folder in folders) {
      final before = folder.files.length;
      folder.files.removeWhere((f) => f.isExpired(now));
      removed |= folder.files.length != before;
    }
    if (removed) _changed();
  }

  /// Sets the paycheck / salary amount in the current [payFrequency].
  void setPayAmount(double? value) {
    payAmount = value;
    _changed();
  }

  /// Keeps the entered amount; only its meaning (per week, per 2 weeks,
  /// per year) changes.
  void setPayFrequency(PayFrequency f) {
    payFrequency = f;
    _changed();
  }

  /// Sets income from a monthly figure (converted to the current frequency;
  /// used as-is in balance mode).
  void setIncome(double? monthly) => setPayAmount(
    monthly == null || usesBalance
        ? monthly
        : monthly * 12 / payFrequency.perYear,
  );

  void setShowSection(FolderType t, bool v) {
    _showSection[t] = v;
    _changed();
  }

  void setShowRecommended(bool v) {
    showRecommended = v;
    // Turning the recommended budget off also turns off its home folder.
    if (!v) recommendedOnHome = false;
    _changed();
  }

  void setHouseholdSize(int n) {
    householdSize = n.clamp(1, maxHousehold);
    _changed();
  }

  void setRecommendedOnHome(bool v) {
    recommendedOnHome = v;
    _changed();
  }

  void setRecommendedCounts(bool v) {
    recommendedCounts = v;
    _changed();
  }

  void setCurrentOnHome(bool v) {
    currentOnHome = v;
    _changed();
  }

  void setCurrentCounts(bool v) {
    currentCounts = v;
    _changed();
  }

  /// Replaces all entered spending at once (the "Add budget" pop-up).
  void setAllActualSpending(Map<String, double> amounts) {
    actualSpending
      ..clear()
      ..addAll(amounts);
    _changed();
  }

  /// Switches one recommended line on/off for the totals.
  void setRecommendedLineOn(String id, bool on) {
    on ? recommendedOff.remove(id) : recommendedOff.add(id);
    _changed();
  }

  /// Saves what the user spends in a category; null clears it.
  void setActualSpending(String id, double? amount) {
    if (amount == null) {
      actualSpending.remove(id);
    } else {
      actualSpending[id] = amount;
    }
    _changed();
  }

  void markWelcomeSeen() {
    seenWelcome = true;
    seenVersion = appVersion;
    _changed();
  }

  void markUpdateSeen() {
    seenVersion = appVersion;
    _changed();
  }

  /// Erases everything on this device and starts over like a new user
  /// (the welcome pop-up shows again).
  Future<void> clearAllData() async {
    _fromJson(const {});
    seenWelcome = false;
    seenVersion = appVersion;
    notifyListeners();
    await _prefs?.remove(_key);
  }

  void setDarkMode(bool v) {
    darkMode = v;
    _changed();
  }

  void setShowWhatsLeft(bool v) {
    showWhatsLeft = v;
    _changed();
  }

  // ---------- Persistence ----------

  void _changed() {
    notifyListeners();
    _prefs?.setString(_key, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
    'payAmount': payAmount,
    'payFrequency': payFrequency.name,
    'showWhatsLeft': showWhatsLeft,
    'darkMode': darkMode,
    'seenWelcome': seenWelcome,
    'seenVersion': seenVersion,
    'showSections': {for (final e in _showSection.entries) e.key.name: e.value},
    'showRecommended': showRecommended,
    'householdSize': householdSize,
    'recommendedOnHome': recommendedOnHome,
    'recommendedCounts': recommendedCounts,
    'recommendedOff': recommendedOff.toList(),
    'currentOnHome': currentOnHome,
    'currentCounts': currentCounts,
    'actualSpending': actualSpending,
    'folders': folders.map((f) => f.toJson()).toList(),
  };

  void _fromJson(Map<String, dynamic> j) {
    // Start from defaults so anything missing from [j] is reset.
    payAmount = null;
    payFrequency = PayFrequency.monthly;
    for (final t in FolderType.values) {
      _showSection[t] = true;
    }
    final legacyMonthly = (j['income'] as num?)?.toDouble();
    if (j.containsKey('payAmount')) {
      payAmount = (j['payAmount'] as num?)?.toDouble();
      payFrequency = PayFrequency.values.firstWhere(
        (f) => f.name == j['payFrequency'],
        orElse: () => PayFrequency.monthly,
      );
    } else if (legacyMonthly != null) {
      // Older saves stored a monthly income.
      payFrequency = PayFrequency.monthly;
      payAmount = legacyMonthly;
    }
    showWhatsLeft = j['showWhatsLeft'] as bool? ?? true;
    darkMode = j['darkMode'] as bool? ?? false;
    seenWelcome = j['seenWelcome'] as bool? ?? true;
    seenVersion = j['seenVersion'] as String?;
    final sections = j['showSections'] as Map? ?? const {};
    for (final t in FolderType.values) {
      _showSection[t] = sections[t.name] as bool? ?? true;
    }
    showRecommended = j['showRecommended'] as bool? ?? false;
    householdSize = (j['householdSize'] as num?)?.toInt() ?? 1;
    recommendedOnHome = j['recommendedOnHome'] as bool? ?? false;
    recommendedCounts = j['recommendedCounts'] as bool? ?? false;
    currentOnHome = j['currentOnHome'] as bool? ?? true;
    currentCounts = j['currentCounts'] as bool? ?? true;
    recommendedOff
      ..clear()
      ..addAll((j['recommendedOff'] as List? ?? const []).cast<String>());
    actualSpending
      ..clear()
      ..addAll({
        for (final e in (j['actualSpending'] as Map? ?? const {}).entries)
          e.key as String: (e.value as num).toDouble(),
      });
    folders
      ..clear()
      ..addAll(
        (j['folders'] as List? ?? []).map(
          (e) => Folder.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _normalizeSubscriptions();
  }

  /// Every container has one hidden "loose" list for items added straight
  /// to it (no folder). Subscriptions only ever use that list, so any older
  /// subscription folders are merged into it (keeping every item; paused
  /// folders pause their items so totals don't change).
  void _normalizeSubscriptions() {
    for (final t in FolderType.values) {
      final group = folders
          .where(
            (f) => f.type == t && (f.loose || t == FolderType.subscription),
          )
          .toList();
      if (group.length == 1 && group.first.loose && !group.first.paused) {
        continue;
      }
      final merged = Folder(name: t.label, type: t, loose: true);
      for (final f in group) {
        for (final file in f.files) {
          if (f.paused) file.paused = true;
          merged.files.add(file);
        }
        folders.remove(f);
      }
      folders.add(merged);
    }
  }

  /// The hidden list of items added straight to a container.
  Folder looseOf(FolderType t) =>
      folders.firstWhere((f) => f.type == t && f.loose);

  /// The single list every subscription lives in.
  Folder get subscriptions => looseOf(FolderType.subscription);
}
