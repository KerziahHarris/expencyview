import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// App state + persistence. Widgets listen to it with ListenableBuilder.
class ExpenseStore extends ChangeNotifier {
  ExpenseStore._(this._prefs);

  static const _key = 'expense_tracker_v1';
  final SharedPreferences? _prefs;

  final List<Folder> folders = [];

  /// Amount the user entered: one paycheck (weekly / bi-weekly) or the yearly
  /// salary. null = not entered yet.
  double? payAmount;

  PayFrequency payFrequency = PayFrequency.biweekly;

  double? get _yearly =>
      payAmount == null ? null : payAmount! * payFrequency.perYear;

  /// Monthly income (what every total on home is measured against).
  double? get income => _yearly == null ? null : _yearly! / 12;

  /// Income per week.
  double? get weeklyIncome => _yearly == null ? null : _yearly! / 52;

  /// Income per year.
  double? get yearlyIncome => _yearly;

  /// Settings toggle: show "Remaining Income" (income - expenses) on home.
  bool showWhatsLeft = true;

  /// Settings toggle: dark (default, the original look) or light mode.
  bool darkMode = true;

  static Future<ExpenseStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = ExpenseStore._(prefs);
    final raw = prefs.getString(_key);
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

  /// In-memory store for tests.
  @visibleForTesting
  factory ExpenseStore.memory() => ExpenseStore._(null);

  // ---------- Math (see "Expense math") ----------

  /// Expense_Total: all expense files + savings files flagged as expenses.
  double get expenseTotal =>
      folders.fold(0, (sum, f) => sum + f.expenseContribution);

  /// Total going toward savings each month.
  double get savingsTotal =>
      folders.fold(0, (sum, f) => sum + f.savingsContribution);

  bool get hasIncome => income != null && income! > 0;

  /// Remaining_Income = Income - Expense_Total - savings paid from income.
  double get whatsLeft => (income ?? 0) - incomeUsed;

  /// Remaining Income spread over a week (monthly × 12 ÷ 52).
  double get whatsLeftWeekly => whatsLeft * 12 / 52;

  /// Everything paid out of income: expenses + savings flagged "from income".
  double get incomeUsed =>
      folders.fold(0, (sum, f) => sum + f.incomeContribution);

  Iterable<Folder> foldersOf(FolderType t) => folders.where((f) => f.type == t);

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

  /// Sets income from a monthly figure (converted to the current frequency).
  void setIncome(double? monthly) => setPayAmount(
    monthly == null ? null : monthly * 12 / payFrequency.perYear,
  );

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
    'folders': folders.map((f) => f.toJson()).toList(),
  };

  void _fromJson(Map<String, dynamic> j) {
    final legacyMonthly = (j['income'] as num?)?.toDouble();
    if (j.containsKey('payAmount')) {
      payAmount = (j['payAmount'] as num?)?.toDouble();
      payFrequency = PayFrequency.values.firstWhere(
        (f) => f.name == j['payFrequency'],
        orElse: () => PayFrequency.biweekly,
      );
    } else if (legacyMonthly != null) {
      // Older saves stored a monthly income.
      payFrequency = PayFrequency.monthly;
      payAmount = legacyMonthly;
    }
    showWhatsLeft = j['showWhatsLeft'] as bool? ?? true;
    darkMode = j['darkMode'] as bool? ?? true;
    folders
      ..clear()
      ..addAll(
        (j['folders'] as List? ?? []).map(
          (e) => Folder.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
  }
}
