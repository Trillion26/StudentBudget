import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../app_info.dart';
import '../../app_scope.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// Asks for Face ID / Touch ID / passcode. Returns true when unlocked.
/// Returns null when this device can't lock apps (no passcode set, or
/// running on a computer without Windows Hello).
Future<bool?> authenticate(String reason) async {
  if (kIsWeb) return null;
  final auth = LocalAuthentication();
  try {
    if (!await auth.isDeviceSupported()) return null;
    return await auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
  } catch (_) {
    return false;
  }
}

/// When app lock is on: asks for Face ID / passcode on launch and after
/// 2 minutes in the background, and hides the screen in the app switcher.
class AppLock extends StatefulWidget {
  const AppLock({super.key, required this.child});

  final Widget child;

  /// How long the app may sit in the background before locking again.
  static const timeout = Duration(minutes: 2);

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _locked = false;
  bool _covered = false;
  bool _checkedLaunch = false;
  bool _authenticating = false;
  DateTime? _backgroundedAt;

  bool get _enabled {
    final store = StoreScope.read(context);
    return store.isReady && store.data.settings.appLockEnabled;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.of(context);
    if (!_checkedLaunch && store.isReady) {
      _checkedLaunch = true;
      if (store.data.settings.appLockEnabled) {
        _locked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
      }
    }
    if (store.isReady && !store.data.settings.appLockEnabled && (_locked || _covered)) {
      _locked = false;
      _covered = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authenticating || !_enabled) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
        if (!_covered) setState(() => _covered = true);
      case AppLifecycleState.resumed:
        final away = _backgroundedAt == null ? Duration.zero : DateTime.now().difference(_backgroundedAt!);
        _backgroundedAt = null;
        setState(() {
          _covered = false;
          if (away >= AppLock.timeout) _locked = true;
        });
        if (_locked) _unlock();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    setState(() => _authenticating = true);
    final result = await authenticate('Unlock $appName');
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      // null: the device can't lock apps any more (e.g. passcode removed).
      if (result != false) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showCover = _locked || _covered;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Keep the app's semantics hidden while locked.
        ExcludeSemantics(excluding: showCover, child: widget.child),
        if (showCover) Positioned.fill(child: _LockCover(locked: _locked, busy: _authenticating, onUnlock: _unlock)),
      ],
    );
  }
}

class _LockCover extends StatelessWidget {
  const _LockCover({required this.locked, required this.busy, required this.onUnlock});

  final bool locked;
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ColoredBox(
      color: c.paper,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(CupertinoIcons.lock_fill, size: 48, color: c.ink),
              const SizedBox(height: 16),
              Text(appName, textAlign: TextAlign.center, style: AppText.title.copyWith(color: c.ink)),
              if (locked) ...[
                const SizedBox(height: 8),
                Text('Locked to keep your budget private.', textAlign: TextAlign.center, style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
                const SizedBox(height: 32),
                PrimaryButton(label: busy ? 'Unlocking…' : 'Unlock', onPressed: busy ? null : onUnlock),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
