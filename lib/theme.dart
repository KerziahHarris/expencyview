import 'package:material_ui/material_ui.dart';

/// The app's color palette. There is one for dark mode (the original mockup
/// colors) and one for light mode; widgets read the active one with
/// `context.colors`, so they repaint when the mode changes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.section,
    required this.card,
    required this.cardBorder,
    required this.pill,
    required this.row,
    required this.expenseBlue,
    required this.savingsGreen,
    required this.leftAmber,
    required this.negative,
    required this.muted,
    required this.homeButton,
    required this.onHomeButton,
    required this.text,
    required this.textSecondary,
  });

  /// Page background.
  final Color background;

  /// Panels (Expenses / Savings sections, income strip, info boxes).
  final Color section;

  /// Summary card fill and its outer ring.
  final Color card;
  final Color cardBorder;

  /// Bottom sheets, menus and the unselected round nav button.
  final Color pill;

  /// A single bill / savings row.
  final Color row;

  final Color expenseBlue;
  final Color savingsGreen;
  final Color leftAmber;
  final Color negative;
  final Color muted;

  /// Selected round nav button and the icon drawn on it.
  final Color homeButton;
  final Color onHomeButton;

  /// Main and secondary text.
  final Color text;
  final Color textSecondary;

  static const dark = AppColors(
    background: Color(0xFF212226),
    section: Color(0xFF2A2B30),
    card: Color(0xFF6C7072),
    cardBorder: Color(0xFF3A3D3F),
    pill: Color(0xFF424242),
    row: Color(0xFF36383D),
    expenseBlue: Color(0xFF7DD3FC),
    savingsGreen: Color(0xFF64FFDA),
    leftAmber: Color(0xFFFFD180),
    negative: Color(0xFFFF8A80),
    muted: Color(0xFF8A8D90),
    homeButton: Color(0xFFA6A6A6),
    onHomeButton: Color(0xFF000000),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
  );

  /// Same layout, light surfaces; accents are darker so they stay readable.
  static const light = AppColors(
    background: Color(0xFFF3F4F6),
    section: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFDCDFE4),
    pill: Color(0xFFFFFFFF),
    row: Color(0xFFF1F3F5),
    expenseBlue: Color(0xFF0284C7),
    savingsGreen: Color(0xFF0F8A7E),
    leftAmber: Color(0xFFB45309),
    negative: Color(0xFFDC2626),
    muted: Color(0xFF6B7280),
    homeButton: Color(0xFF374151),
    onHomeButton: Color(0xFFFFFFFF),
    text: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 ? this : other ?? this;
}

extension AppColorsContext on BuildContext {
  /// The active palette (dark or light).
  AppColors get colors => AppColors.of(this);
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.expenseBlue,
    brightness: brightness,
  ).copyWith(surface: c.background);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    extensions: [c],
  );
}

/// Formats a number as $1,234.56 (drops ".00" for whole amounts, like the mockup).
String money(double v) {
  final negative = v < 0;
  final cents = (v.abs() * 100).round();
  final whole = cents ~/ 100;
  final frac = cents % 100;
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final fracStr = frac == 0 ? '' : '.${frac.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}\$$buf$fracStr';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Dec 21, 2026"
String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
