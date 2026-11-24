import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'budget.dart';
import 'models.dart';

/// Current app version, shown on App Info.
const appVersion = '1.3';

/// What kind of release [appVersion] is, shown next to it on App Info
/// (e.g. 'Hotfix'); empty for a regular release.
const appReleaseNote = '';

/// The release whose "what's new" pop-up existing users get once. Hotfixes
/// don't change it, so they don't bring the pop-up back.
const noticeVersion = '1.3';

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

  /// The amount every total on home is measured against: monthly income
  /// (weekly × 4, bi-weekly × 2, salary ÷ 12), or the current balance as-is.
  double? get income => payAmount == null
      ? null
      : usesBalance
      ? payAmount
      : payAmount! * payFrequency.perMonth;

  /// Income per week: a month is counted as 4 weeks (null in balance mode).
  double? get weeklyIncome =>
      income == null || usesBalance ? null : income! / 4;

  /// Real income per year: every paycheck (weekly × 52, bi-weekly × 26)
  /// (null in balance mode).
  double? get yearlyIncome => payAmount == null || usesBalance
      ? null
      : payAmount! * payFrequency.perYear;

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

  /// The user's budget folders (from the guided tour) on home, and whether
  /// they count in totals.
  bool currentOnHome = true;
  bool currentCounts = true;

  /// Accessibility: text size multiplier (1.0 = designed size). Slightly
  /// larger by default for readability on small screens.
  double textScale = defaultTextScale;
  static const defaultTextScale = 1.1;
  static const minTextScale = 0.85;
  static const maxTextScale = 1.6;

  /// Settings toggle: show "Remaining Income" (income - expenses) on home.
  bool showWhatsLeft = true;

  /// Settings toggle (off by default): under Monthly Expense, also show the
  /// daily / weekly / yearly costs in their own amounts.
  bool showCycleCosts = false;

  /// Settings toggle: dark (default, the original look) or light mode.
  bool darkMode = false;

  /// False until a first-time user has seen (or dismissed) the welcome
  /// pop-up. Existing saves count as seen.
  bool seenWelcome = true;

  /// The app version whose "what's new" pop-up this user has seen. Saves from
  /// before 1.2 have none, so existing users get the update pop-up once.
  String? seenVersion = noticeVersion;

  /// True when an existing user hasn't seen this version's update pop-up.
  bool get needsUpdateNotice => seenWelcome && seenVersion != noticeVersion;

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

  /// True when the budget folders are on home and set to count.
  bool get currentIsCounted => currentOnHome && currentCounts;

  /// Budget folders only count when [currentIsCounted]; everything else
  /// always counts.
  bool countsInTotals(Folder f) =>
      f.type != FolderType.budget || currentIsCounted;

  /// What the user really spends in a recommended category, from every item
  /// tagged with it (budget folders, savings plan, subscriptions...).
  /// null when nothing is tagged with it.
  double? categorySpending(String categoryId) {
    double? sum;
    for (final f in folders) {
      if (f.paused) continue;
      for (final file in f.files) {
        if (file.category == categoryId) {
          sum = (sum ?? 0) + file.monthlyValue;
        }
      }
    }
    return sum;
  }

  /// Every active item tagged with [categoryId], with the folder it's in
  /// (what the Compare tab's Edit mode lets you change).
  List<(Folder, EntryFile)> categoryItems(String categoryId) => [
    for (final f in folders)
      if (!f.paused)
        for (final file in f.files)
          if (file.category == categoryId && !file.paused) (f, file),
  ];

  /// Saves the Compare tab's Edit mode in one go:
  /// [items] new monthly amounts for existing items (null or 0 = remove it),
  /// [added] amounts for categories that had no items yet; these go in a
  /// "My budget" folder.
  void applyCompareEdits({
    required Map<EntryFile, double?> items,
    required Map<String, double> added,
  }) {
    items.forEach((file, monthly) {
      final folder = folders.firstWhere((f) => f.files.contains(file));
      if (monthly == null || monthly <= 0) {
        folder.files.remove(file);
      } else {
        file.value = monthly / file.cycle.perMonth;
      }
    });
    if (added.isNotEmpty) {
      var mine = folders
          .where(
            (f) =>
                f.type == FolderType.budget &&
                f.tourKey == null &&
                f.name == 'My budget',
          )
          .firstOrNull;
      if (mine == null) {
        mine = Folder(name: 'My budget', type: FolderType.budget);
        folders.add(mine);
      }
      added.forEach((id, monthly) {
        final cat = budgetCategories.firstWhere((c) => c.id == id);
        mine!.files.add(
          EntryFile(name: cat.name, value: monthly, category: id),
        );
      });
    }
    // Budget folders emptied by the edit are removed.
    folders.removeWhere((f) => f.type == FolderType.budget && f.files.isEmpty);
    _changed();
  }

  /// Savings after a year: what's saved so far plus 12 months of deposits,
  /// across the Savings container (paused items/folders add no deposits).
  double get savingsInAYear => folders
      .where((f) => f.type == FolderType.savings)
      .expand((f) => f.files.map((file) => (f, file)))
      .fold(
        0,
        (sum, e) =>
            sum +
            (e.$2.saved ?? 0) +
            (e.$1.paused ? 0 : e.$2.monthlyValue * 12),
      );

  /// The Budget container on home is shown when either budget folder is.
  bool get showsBudgetSection =>
      currentOnHome || (showRecommended && recommendedOnHome && hasIncome);

  // ---------- Guided tour ----------

  /// The folder a tour step made, if any.
  Folder? tourFolder(String key) =>
      folders.where((f) => f.tourKey == key).firstOrNull;

  /// Saves one tour step: replaces that step's folder items with [items]
  /// (creating the folder if needed, removing it when empty).
  void saveTourFolder({
    required String key,
    required String name,
    required FolderType type,
    required List<EntryFile> items,
  }) {
    final existing = tourFolder(key);
    if (items.isEmpty) {
      if (existing != null) folders.remove(existing);
    } else if (existing == null) {
      folders.add(Folder(name: name, type: type, tourKey: key, files: items));
    } else {
      existing.files
        ..clear()
        ..addAll(items);
    }
    _changed();
  }

  /// Adds subscriptions entered in the tour to the Subscriptions container.
  void addSubscriptions(List<EntryFile> items) {
    if (items.isEmpty) return;
    subscriptions.files.addAll(items);
    _changed();
  }

  /// Expense_Total: expenses + subscriptions + savings flagged as expenses
  /// (+ the recommended budget when it is set to count).
  double get expenseTotal =>
      folders
          .where(countsInTotals)
          .fold<double>(0, (sum, f) => sum + f.expenseContribution) +
      recommendedContribution;

  /// Total going toward savings each month.
  double get savingsTotal =>
      folders.fold(0, (sum, f) => sum + f.savingsContribution);

  bool get hasIncome => income != null && income! > 0;

  /// Remaining_Income = Income - Expense_Total - savings paid from income.
  double get whatsLeft => (income ?? 0) - incomeUsed;

  /// Remaining Income per week (a month counted as 4 weeks). Not meaningful
  /// in balance mode.
  double get whatsLeftWeekly => whatsLeft / 4;

  /// Everything paid out of income: expenses + savings flagged "from income".
  double get incomeUsed =>
      folders
          .where(countsInTotals)
          .fold<double>(0, (sum, f) => sum + f.incomeContribution) +
      recommendedContribution;

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
    monthly == null || usesBalance ? monthly : monthly / payFrequency.perMonth,
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

  void setTextScale(double v) {
    textScale = v.clamp(minTextScale, maxTextScale);
    _changed();
  }

  /// Switches one recommended line on/off for the totals.
  void setRecommendedLineOn(String id, bool on) {
    on ? recommendedOff.remove(id) : recommendedOff.add(id);
    _changed();
  }

  void markWelcomeSeen() {
    seenWelcome = true;
    seenVersion = noticeVersion;
    _changed();
  }

  void markUpdateSeen() {
    seenVersion = noticeVersion;
    _changed();
  }

  /// Erases everything on this device and starts over like a new user
  /// (the welcome pop-up shows again).
  Future<void> clearAllData() async {
    _fromJson(const {});
    seenWelcome = false;
    seenVersion = noticeVersion;
    notifyListeners();
    await _prefs?.remove(_key);
  }

  void setDarkMode(bool v) {
    darkMode = v;
    _changed();
  }

  void setShowCycleCosts(bool v) {
    showCycleCosts = v;
    _changed();
  }

  /// Costs in Monthly Expense that aren't charged monthly, added up per
  /// cycle in their own amounts (e.g. daily → $5 a day). Paused items and
  /// savings are left out.
  Map<BillingCycle, double> get cycleCosts {
    final out = <BillingCycle, double>{};
    for (final f in folders) {
      if (f.paused || f.type == FolderType.savings || !countsInTotals(f)) {
        continue;
      }
      for (final file in f.files) {
        if (file.paused || file.cycle == BillingCycle.monthly) continue;
        out[file.cycle] = (out[file.cycle] ?? 0) + file.value;
      }
    }
    return {for (final c in BillingCycle.values) c: ?out[c]};
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
    'showCycleCosts': showCycleCosts,
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
    'textScale': textScale,
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
    showCycleCosts = j['showCycleCosts'] as bool? ?? false;
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
    textScale = ((j['textScale'] as num?)?.toDouble() ?? defaultTextScale)
        .clamp(minTextScale, maxTextScale);
    folders
      ..clear()
      ..addAll(
        (j['folders'] as List? ?? []).map(
          (e) => Folder.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _migrateLegacyBudget(j['actualSpending'] as Map?);
    _normalizeSubscriptions();
  }

  /// Before 1.3 the budget was one amount per category. Turn those into a
  /// "My budget" folder so nothing is lost (and Compare still adds up).
  void _migrateLegacyBudget(Map? legacy) {
    if (legacy == null || legacy.isEmpty) return;
    if (folders.any((f) => f.type == FolderType.budget)) return;
    // Old combined categories map onto their new, separate ones.
    const renamed = {
      'phone-internet': ('phone', 'Phone & internet'),
      'toiletries-personal-care': ('toiletries', 'Toiletries & personal care'),
      'emergency-fund-savings': ('emergency-fund', 'Emergency fund & savings'),
      'retirement-extra-debt-payments': (
        'retirement',
        'Retirement & extra debt payments',
      ),
    };
    final items = <EntryFile>[];
    for (final e in legacy.entries) {
      final id = e.key as String;
      final amount = (e.value as num).toDouble();
      if (amount <= 0) continue;
      final known = budgetCategories.where((c) => c.id == id).firstOrNull;
      final (newId, name) = renamed[id] ?? (id, known?.name ?? id);
      items.add(EntryFile(name: name, value: amount, category: newId));
    }
    if (items.isEmpty) return;
    folders.add(
      Folder(name: 'My budget', type: FolderType.budget, files: items),
    );
  }

  /// Every container has one hidden "loose" list for items added straight
  /// to it (no folder). Subscriptions only ever use that list, so any older
  /// subscription folders are merged into it (keeping every item; paused
  /// folders pause their items so totals don't change).
  void _normalizeSubscriptions() {
    for (final t in FolderType.containers) {
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
