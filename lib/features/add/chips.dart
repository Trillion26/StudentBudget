import 'package:flutter/cupertino.dart';

import '../../design/app_colors.dart';
import '../../design/theme.dart';

/// One item in the emoji chip grid.
class ChipItem {
  const ChipItem({required this.id, required this.emoji, required this.label});
  final String id;
  final String emoji;
  final String label;
}

/// A tappable emoji chip ("🛒 Groceries").
class EmojiChip extends StatelessWidget {
  const EmojiChip({super.key, required this.item, required this.selected, required this.onTap});

  final ChipItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.ink : c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? c.ink : c.line, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MediaQuery.withNoTextScaling(child: Text(item.emoji, style: const TextStyle(fontSize: 18))),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.label,
                  style: AppText.small.copyWith(color: selected ? c.onInk : c.ink, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrapping grid of [EmojiChip]s.
class ChipGrid extends StatelessWidget {
  const ChipGrid({super.key, required this.items, required this.selectedId, required this.onSelected});

  final List<ChipItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          EmojiChip(item: item, selected: item.id == selectedId, onTap: () => onSelected(item.id)),
      ],
    );
  }
}

/// The four kinds as a segmented control. Shows as a 2×2 grid when the
/// text is too large for one row.
class KindSegments<T> extends StatelessWidget {
  const KindSegments({super.key, required this.values, required this.labels, required this.selected, required this.onChanged});

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final large = MediaQuery.textScalerOf(context).scale(15) > 15 * 1.25;
    Widget segment(int i) {
      final isSelected = values[i] == selected;
      return Semantics(
        button: true,
        selected: isSelected,
        label: labels[i],
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(values[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? c.card : null,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1))] : null,
            ),
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              style: AppText.small.copyWith(color: isSelected ? c.ink : c.inkSoft, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
        ),
      );
    }

    final children = [for (var i = 0; i < values.length; i++) segment(i)];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.line.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(13)),
      child: large
          ? Column(
              children: [
                for (var row = 0; row < children.length; row += 2)
                  Row(children: [
                    Expanded(child: children[row]),
                    if (row + 1 < children.length) Expanded(child: children[row + 1]),
                  ]),
              ],
            )
          : Row(children: [for (final child in children) Expanded(child: child)]),
    );
  }
}
