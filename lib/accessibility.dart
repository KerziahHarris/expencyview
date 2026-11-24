import 'package:material_ui/material_ui.dart';

import 'store.dart';
import 'theme.dart';

/// Settings → Accessibility.
class AccessibilityPage extends StatelessWidget {
  const AccessibilityPage({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextSizeControl(store: store),
            const SizedBox(height: 20),
            AppearanceSwitch(store: store),
          ],
        ),
      ),
    );
  }
}

/// Text size slider with a live preview of how the app will look. The size
/// is applied when the slider is let go (so dragging stays smooth).
class TextSizeControl extends StatefulWidget {
  const TextSizeControl({super.key, required this.store});

  final ExpenseStore store;

  @override
  State<TextSizeControl> createState() => _TextSizeControlState();
}

class _TextSizeControlState extends State<TextSizeControl> {
  late double _value = widget.store.textScale;

  static const _steps = 15; // 0.85 → 1.6 in 0.05 steps

  String get _label {
    final pct = (_value * 100).round();
    if (pct < 95) return 'Smaller ($pct%)';
    if (pct <= 105) return 'Standard ($pct%)';
    if (pct <= 125) return 'Large ($pct%)';
    return 'Extra large ($pct%)';
  }

  void _apply(double v) => widget.store.setTextScale(v);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The app's text is already scaled by the saved size; preview by the
    // difference so it shows exactly what the new size will look like.
    final saved = widget.store.textScale;
    final base = MediaQuery.textScalerOf(context).scale(1) / saved;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.section,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.format_size, color: c.expenseBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Text size',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  _label,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: c.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('A', style: TextStyle(fontSize: 14, color: c.muted)),
              Expanded(
                child: Slider(
                  key: const ValueKey('text-size'),
                  value: _value,
                  min: ExpenseStore.minTextScale,
                  max: ExpenseStore.maxTextScale,
                  divisions: _steps,
                  label: '${(_value * 100).round()}%',
                  onChanged: (v) => setState(() => _value = v),
                  onChangeEnd: _apply,
                ),
              ),
              Text('A', style: TextStyle(fontSize: 24, color: c.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Preview', style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 6),
          // Preview at the slider's size.
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(base * _value)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: c.row,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rent',
                          style: TextStyle(fontSize: 17, color: c.text),
                        ),
                        Text(
                          'Housing · due every month',
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '\$1,200',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Changes apply when you let go of the slider.',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _value = ExpenseStore.defaultTextScale);
                  _apply(ExpenseStore.defaultTextScale);
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Light / dark switch, shared by Accessibility and the tour.
class AppearanceSwitch extends StatelessWidget {
  const AppearanceSwitch({super.key, required this.store});

  final ExpenseStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.section,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            store.darkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            color: c.expenseBlue,
          ),
          title: const Text('Dark mode'),
          subtitle: Text(
            store.darkMode
                ? 'On: light text on a dark background'
                : 'Off: light mode',
          ),
          value: store.darkMode,
          onChanged: store.setDarkMode,
        ),
      ),
    );
  }
}
