import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'theme.dart';

/// A labelled text field used on edit pages.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.error, this.help});

  final String label;
  final Widget child;
  final String? error;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.small.copyWith(color: c.inkSoft)),
          const SizedBox(height: 6),
          child,
          if (error != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: AppText.small.copyWith(color: c.overText)))
          else if (help != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(help!, style: AppText.small.copyWith(color: c.inkSoft))),
        ],
      ),
    );
  }
}

/// A plain text input styled like the rest of the app.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.semanticLabel,
    this.hasError = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? placeholder;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? semanticLabel;
  final bool hasError;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      label: semanticLabel,
      textField: true,
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLength: maxLength,
        keyboardType: keyboardType,
        autofocus: autofocus,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
        style: AppText.bodyRegular.copyWith(color: c.ink),
        placeholderStyle: AppText.bodyRegular.copyWith(color: c.inkSoft.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasError ? c.overText : c.line, width: hasError ? 1.5 : 1),
        ),
        cursorColor: c.ink,
      ),
    );
  }
}

/// Suggested emoji plus a field to type any other emoji.
class EmojiPicker extends StatefulWidget {
  const EmojiPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const suggestions = [
    '🛒', '🍔', '☕', '🍱', '🚕', '🚙', '⛽', '🚆', '🏠', '⚡', '💧', '📶', '📞', '📚', '🖊️', '💻',
    '🎓', '💊', '🩺', '👟', '🧴', '💈', '🎉', '🎬', '🎧', '🏋️', '🎁', '⛪', '🤝', '🏡', '✈️', '🏖️',
    '💳', '🏦', '🏧', '👛', '💰', '💼', '🐷', '🛟', '🌍', '🚗', '🧺', '🧽', '🐶', '👶', '🎮', '📦',
  ];

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  late final TextEditingController _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in EmojiPicker.suggestions)
              Semantics(
                button: true,
                selected: e == widget.value,
                label: 'Emoji $e',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => widget.onChanged(e),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == widget.value ? c.highlight : c.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: e == widget.value ? c.ink : c.line),
                    ),
                    child: MediaQuery.withNoTextScaling(child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppTextField(
          controller: _custom,
          placeholder: 'Or type any emoji',
          semanticLabel: 'Type any emoji',
          onChanged: (text) {
            final chars = text.characters;
            if (chars.isNotEmpty) widget.onChanged(chars.last);
          },
        ),
      ],
    );
  }
}
