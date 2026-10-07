import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import 'app_colors.dart';
import 'theme.dart';

/// Shows short messages ("Added R85,50 to Groceries") with an optional
/// Undo button above the tab bar. Wraps the whole app so every screen and
/// sheet can use it.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  static ToastHostState of(BuildContext context) =>
      context.findAncestorStateOfType<ToastHostState>() ?? (throw StateError('No ToastHost above this context'));

  /// Shows [message] for 4 seconds, with an Undo button when [onUndo] is set.
  static void show(BuildContext context, String message, {VoidCallback? onUndo}) =>
      of(context).show(message, onUndo: onUndo);

  @override
  State<ToastHost> createState() => ToastHostState();
}

class _Toast {
  _Toast(this.message, this.onUndo, this.id);
  final String message;
  final VoidCallback? onUndo;
  final int id;
}

class ToastHostState extends State<ToastHost> {
  _Toast? _toast;
  Timer? _timer;
  int _counter = 0;

  /// How long a toast stays up.
  static const duration = Duration(seconds: 4);

  void show(String message, {VoidCallback? onUndo}) {
    _timer?.cancel();
    setState(() => _toast = _Toast(message, onUndo, ++_counter));
    _timer = Timer(duration, hide);
    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(view, message, Directionality.of(context));
    }
  }

  void hide() {
    _timer?.cancel();
    if (mounted) setState(() => _toast = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toast = _toast;
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: AnimatedSwitcher(
            duration: MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : const Duration(milliseconds: 200),
            child: toast == null ? const SizedBox.shrink() : _ToastView(key: ValueKey(toast.id), toast: toast, onUndo: () {
              hide();
              toast.onUndo?.call();
            }),
          ),
        ),
      ],
    );
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({super.key, required this.toast, required this.onUndo});

  final _Toast toast;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(toast.message, style: AppText.body.copyWith(color: c.onInk)),
              ),
            ),
            if (toast.onUndo != null)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(44, 44),
                onPressed: onUndo,
                child: Text(
                  'Undo',
                  style: AppText.body.copyWith(
                    // Yellow reads well on the dark toast (light mode); the
                    // dark-mode toast is light, so Undo uses dark text there.
                    color: c.onInk.computeLuminance() > 0.5 ? c.highlight : c.onInk,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: c.highlight,
                    decorationThickness: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
