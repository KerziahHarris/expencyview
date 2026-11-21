import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Page Two: pie chart of where the monthly income goes.
/// Only reachable when income has been entered.
class ChartPage extends StatelessWidget {
  const ChartPage({super.key, required this.store});

  final ExpenseStore store;

  static const _palette = [
    Color(0xFF7DD3FC),
    Color(0xFFF9A8D4),
    Color(0xFFFCD34D),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
    Color(0xFF86EFAC),
    Color(0xFFF87171),
    Color(0xFF67E8F9),
  ];

  List<_Slice> _slices(BuildContext context) {
    final slices = <_Slice>[];
    var i = 0;
    for (final f in store.folders) {
      // Only money that actually comes out of income is part of the pie.
      final value = f.incomeContribution;
      if (value <= 0) continue;
      final color = f.type == FolderType.savings
          ? context.colors.savingsGreen.withValues(alpha: 1 - 0.2 * (i % 3))
          : _palette[i % _palette.length];
      slices.add(_Slice(f.name, value, color));
      i++;
    }
    // Unspent income (whatever's left after everything above).
    final spent = slices.fold<double>(0, (s, x) => s + x.value);
    final left = (store.income ?? 0) - spent;
    if (left > 0) {
      slices.add(_Slice('Remaining income', left, context.colors.muted));
    }
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final slices = _slices(context);
    final total = slices.fold<double>(0, (s, x) => s + x.value);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Where your money goes',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, color: context.colors.text),
        ),
        Text(
          'Income ${money(store.income ?? 0)} / month · '
          '${money(store.weeklyIncome ?? 0)} / week',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, fontSize: 16),
        ),
        const SizedBox(height: 24),
        if (total <= 0)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Add some expenses to see the chart.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.muted),
            ),
          )
        else ...[
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _PiePainter(slices, total)),
          ),
          const SizedBox(height: 24),
          for (final s in slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.label,
                      style: TextStyle(
                        color: context.colors.text,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Text(
                    '${money(s.value)}  ·  ${(s.value / total * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          if (store.whatsLeft < 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Spending is over income by ${money(-store.whatsLeft)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.negative),
              ),
            ),
        ],
      ],
    );
  }
}

class _Slice {
  _Slice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices, this.total);

  final List<_Slice> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.18;
    final arcRect = rect.deflate(stroke / 2);
    const gap = 0.02; // radians between slices
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * 2 * math.pi;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      final drawn = slices.length > 1 ? math.max(sweep - gap, 0.001) : sweep;
      canvas.drawArc(arcRect, start, drawn, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => true;
}
