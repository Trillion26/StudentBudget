import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../logic/money.dart';
import 'app_colors.dart';
import 'theme.dart';

/// An inline euro amount field ("€ 1100"). Calls [onChanged] with whole
/// cents whenever the text is a valid amount (empty counts as € 0), so
/// changes save immediately. Keeps what was typed while focused.
class EuroField extends StatefulWidget {
  const EuroField({
    super.key,
    required this.cents,
    required this.onChanged,
    this.semanticLabel,
    this.width = 120,
    this.allowZero = true,
    this.placeholder = '0',
    this.textAlign = TextAlign.right,
  });

  final int cents;
  final ValueChanged<int> onChanged;
  final String? semanticLabel;
  final double? width;
  final bool allowZero;
  final String placeholder;
  final TextAlign textAlign;

  @override
  State<EuroField> createState() => _EuroFieldState();
}

class _EuroFieldState extends State<EuroField> {
  late final TextEditingController _controller = TextEditingController(text: formatAmountForField(widget.cents));
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        // Tidy the text once the field loses focus.
        final parsed = parseAmount(_controller.text, allowZero: widget.allowZero);
        if (parsed.isValid) {
          _controller.text = formatAmountForField(parsed.cents!);
          setState(() => _error = null);
        }
      }
    });
  }

  @override
  void didUpdateWidget(EuroField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.cents != widget.cents) {
      _controller.text = formatAmountForField(widget.cents);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final parsed = parseAmount(text, allowZero: widget.allowZero);
    setState(() => _error = parsed.error);
    if (parsed.isValid && parsed.cents != widget.cents) widget.onChanged(parsed.cents!);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final field = CupertinoTextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))],
      textAlign: widget.textAlign,
      placeholder: widget.placeholder,
      placeholderStyle: AppText.amount.copyWith(color: c.inkSoft.withValues(alpha: 0.6)),
      style: AppText.amount.copyWith(color: c.ink),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Text('€', style: AppText.amount.copyWith(color: c.inkSoft)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _error != null ? c.overText : c.line, width: _error != null ? 1.5 : 1),
      ),
      cursorColor: c.ink,
      onChanged: _changed,
    );
    return Semantics(
      label: widget.semanticLabel,
      hint: _error,
      textField: true,
      child: SizedBox(width: widget.width, child: field),
    );
  }
}
