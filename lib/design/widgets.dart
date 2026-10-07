import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, InkWell, Divider;

import '../logic/budget_month.dart';
import 'app_colors.dart';
import 'theme.dart';

/// True when the phone's text size is large enough that rows should stack
/// instead of sitting side by side.
bool useStackedLayout(BuildContext context) => MediaQuery.textScalerOf(context).scale(17) > 17 * 1.5;

/// A 40 pt rounded tile with an emoji, used at the start of list rows.
class EmojiTile extends StatelessWidget {
  const EmojiTile(this.emoji, {super.key, this.size = 40, this.background});

  final String emoji;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background ?? c.card,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: c.line),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            // Emoji keep a fixed size so the tile never overflows at large text.
            child: MediaQuery.withNoTextScaling(
              child: Text(emoji, style: TextStyle(fontSize: size * 0.5, height: 1.1)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin rounded progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, this.height = 8});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(height)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
        ),
      ),
    );
  }
}

/// A section heading in sentence case.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 8)});

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: AppText.heading.copyWith(color: c.ink)))),
          ?trailing,
        ],
      ),
    );
  }
}

/// A full-width divider indented past the emoji tile.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key, this.indent = 76});

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, indent: indent, color: AppColors.of(context).line);
}

/// Primary action button: ink fill, white text, full width, 52 pt tall.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.color, this.textColor});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          borderRadius: BorderRadius.circular(16),
          color: color ?? c.ink,
          disabledColor: c.line,
          onPressed: onPressed,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(
              color: enabled ? (textColor ?? c.onInk) : c.inkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button: outlined, ink text.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.color, this.expand = true});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final textColor = color ?? c.ink;
    final button = CupertinoButton(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: onPressed == null ? c.inkSoft : textColor, fontWeight: FontWeight.w700),
        ),
      ),
    );
    return Container(
      width: expand ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: button,
    );
  }
}

/// A plain text link-style button ("See everything this month").
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      minimumSize: const Size(44, 44),
      alignment: Alignment.centerLeft,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppText.body.copyWith(color: c.ink, decoration: TextDecoration.underline, decorationColor: c.highlight, decorationThickness: 2),
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon ?? CupertinoIcons.chevron_right, size: 16, color: c.inkSoft),
        ],
      ),
    );
  }
}

/// A tappable row with an emoji tile, a title and subtitle, and a trailing
/// widget. Stacks the trailing widget under the title at large text sizes.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.emoji,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  final String? emoji;
  final Widget? leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  /// Shown under the title row across the full width (e.g. a progress bar).
  final Widget? below;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final stacked = useStackedLayout(context);
    final titleText = Text(title, style: AppText.body.copyWith(color: c.ink));
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleText,
        if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
        if (stacked && trailing != null) ...[const SizedBox(height: 4), trailing!],
      ],
    );
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) leading! else if (emoji != null) EmojiTile(emoji!),
              if (leading != null || emoji != null) const SizedBox(width: 16),
              Expanded(child: textColumn),
              if (!stacked && trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          if (below != null) ...[
            const SizedBox(height: 10),
            Padding(padding: EdgeInsets.only(left: (leading != null || emoji != null) ? 56 : 0), child: below!),
          ],
        ],
      ),
    );
    final row = onTap == null
        ? content
        : Material(type: MaterialType.transparency, child: InkWell(onTap: onTap, child: content));
    if (semanticLabel == null) return row;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: row,
    );
  }
}

/// ‹ October 2026 › — moves by budget month and stops one month ahead.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.latest, required this.onChanged, this.earliest});

  final BudgetMonth month;
  final BudgetMonth latest;
  final BudgetMonth? earliest;
  final ValueChanged<BudgetMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canGoBack = earliest == null || month.isAfter(earliest!);
    final canGoForward = month.isBefore(latest);
    final range = month.rangeLabel;
    return Row(
      children: [
        _arrow(context, CupertinoIcons.chevron_left, 'Previous month', canGoBack ? () => onChanged(month.previous) : null),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(month.label, textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                if (range.isNotEmpty)
                  Text(range, textAlign: TextAlign.center, style: AppText.small.copyWith(color: c.inkSoft)),
              ],
            ),
          ),
        ),
        _arrow(context, CupertinoIcons.chevron_right, 'Next month', canGoForward ? () => onChanged(month.next) : null),
      ],
    );
  }

  Widget _arrow(BuildContext context, IconData icon, String label, VoidCallback? onPressed) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
        onPressed: onPressed,
        child: Icon(icon, color: onPressed == null ? c.line : c.ink, size: 22),
      ),
    );
  }
}

/// A short card used for banners and hints (not for every section).
class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

/// A screen in a tab: paper background and a large left-aligned title.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.slivers, this.trailing, this.showBack = false});

  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: c.paper,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            backgroundColor: c.paper.withValues(alpha: 0.94),
            border: null,
            trailing: trailing,
            automaticallyImplyLeading: showBack,
            previousPageTitle: showBack ? 'Back' : null,
          ),
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 120)),
        ],
      ),
    );
  }
}
