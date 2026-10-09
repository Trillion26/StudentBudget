import 'package:flutter/cupertino.dart';

import '../../app_info.dart';
import '../../app_scope.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/toast.dart';
import '../../design/widgets.dart';
import '../../logic/dates.dart';
import '../../logic/validation.dart';
import '../lock/app_lock.dart';
import 'backup_actions.dart';

String ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) { 1 => '${day}st', 2 => '${day}nd', 3 => '${day}rd', _ => '${day}th' };
}

/// A wheel to pick the budget month start day (1–28).
Future<int?> pickStartDay(BuildContext context, int current) async {
  final c = AppColors.of(context);
  var picked = current;
  final ok = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => Container(
      color: c.card,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          CupertinoButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppText.body.copyWith(color: c.ink))),
          CupertinoButton(onPressed: () => Navigator.pop(context, true), child: Text('Done', style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800))),
        ]),
        SizedBox(
          height: 216,
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: FixedExtentScrollController(initialItem: current - 1),
            onSelectedItemChanged: (i) => picked = i + 1,
            children: [for (var d = 1; d <= 28; d++) Center(child: Text('The ${ordinal(d)} of each month'))],
          ),
        ),
      ]),
    ),
  );
  return ok == true ? picked : null;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _editNames(BuildContext context) async {
    final store = StoreScope.read(context);
    final toast = ToastHost.of(context);
    final s = store.data.settings;
    final one = TextEditingController(text: s.partner1Name);
    final two = TextEditingController(text: s.partner2Name);
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Your names'),
        content: Column(children: [
          const SizedBox(height: 12),
          CupertinoTextField(controller: one, placeholder: 'Partner 1', maxLength: Validation.maxPersonNameLength, autofocus: true),
          const SizedBox(height: 8),
          CupertinoTextField(controller: two, placeholder: 'Partner 2', maxLength: Validation.maxPersonNameLength),
        ]),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await store.setPartnerNames(one.text, two.text);
      } on ArgumentError catch (e) {
        toast.show('${e.message}');
      }
    }
    one.dispose();
    two.dispose();
  }

  Future<void> _toggleLock(BuildContext context, bool enable) async {
    final store = StoreScope.read(context);
    final toast = ToastHost.of(context);
    if (!enable) {
      await store.setAppLockEnabled(false);
      return;
    }
    final result = await authenticate('Turn on app lock for $appName');
    if (result == null) {
      toast.show('This device can\'t lock apps. Set a passcode in your phone\'s settings first.');
    } else if (result) {
      await store.setAppLockEnabled(true);
      toast.show('App lock is on.');
    }
  }

  Future<void> _pickCsvYear(BuildContext context) async {
    final year = await pickExportYear(context, message: 'Exports every transaction in that year as a CSV file for Excel or Google Sheets.');
    if (year != null && context.mounted) await exportCsv(context, year);
  }

  Future<void> _pickExcelYear(BuildContext context) async {
    final year = await pickExportYear(context, message: 'Exports a dashboard with charts, every month, every transaction, and your goals and debts.');
    if (year != null && context.mounted) await exportExcel(context, year);
  }

  Future<void> _reset(BuildContext context) async {
    final store = StoreScope.read(context);
    final first = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset all data?'),
        content: const Text('This deletes every entry, goal, debt and budget on this phone and starts again with the starter budget.'),
        actions: [
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Are you sure?'),
        content: const Text("This can't be undone. Save a backup first if you might want this data again."),
        actions: [
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(context, false), child: const Text('Keep my data')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('Delete everything')),
        ],
      ),
    );
    if (second != true || !context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await store.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.data.settings;
    final c = AppColors.of(context);
    final lastBackup = s.lastBackupAt == null ? 'Never' : shortDate(s.lastBackupAt!.toLocal());
    final chevron = Icon(CupertinoIcons.chevron_right, color: c.inkSoft, size: 18);

    return PageScaffold(
      title: 'Settings',
      showBack: true,
      slivers: [
        SliverList.list(children: [
          const SectionTitle('Household', padding: EdgeInsets.fromLTRB(20, 8, 20, 4)),
          ListRow(
            emoji: '👫',
            title: '${s.partner1Name} & ${s.partner2Name}',
            subtitle: Text('Names used for "who paid" and in category names', style: AppText.small.copyWith(color: c.inkSoft)),
            trailing: chevron,
            onTap: () => _editNames(context),
          ),
          const SectionTitle('Budget month'),
          ListRow(
            emoji: '📅',
            title: 'Starts on the ${ordinal(s.budgetMonthStartDay)}',
            subtitle: Text('Salary on the 25th? Start your budget month then.', style: AppText.small.copyWith(color: c.inkSoft)),
            trailing: chevron,
            onTap: () async {
              final day = await pickStartDay(context, s.budgetMonthStartDay);
              if (day != null) await store.setBudgetMonthStartDay(day);
            },
          ),
          const SectionTitle('Privacy'),
          ListRow(
            emoji: '🔒',
            title: 'App lock',
            subtitle: Text('Face ID or passcode when you open the app', style: AppText.small.copyWith(color: c.inkSoft)),
            trailing: CupertinoSwitch(
              value: s.appLockEnabled,
              activeTrackColor: c.ink,
              onChanged: (v) => _toggleLock(context, v),
            ),
          ),
          const SectionTitle('Backups'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Your budget only lives on this phone. If the app was installed with SideStore or AltStore, it can be lost when the app '
              'expires or is reinstalled, so save a backup every week or two. Last backup: $lastBackup.',
              style: AppText.small.copyWith(color: c.inkSoft),
            ),
          ),
          ListRow(emoji: '💾', title: 'Save backup', subtitle: Text('To Files, iCloud Drive, Google Drive, WhatsApp or email', style: AppText.small.copyWith(color: c.inkSoft)), trailing: chevron, onTap: () => saveBackup(context)),
          const RowDivider(),
          ListRow(emoji: '📥', title: 'Restore backup', subtitle: Text('Replace everything with a backup file', style: AppText.small.copyWith(color: c.inkSoft)), trailing: chevron, onTap: () => restoreBackup(context)),
          const RowDivider(),
          ListRow(emoji: '📈', title: 'Export to Excel', subtitle: Text("A year's overview with charts, as an .xlsx file", style: AppText.small.copyWith(color: c.inkSoft)), trailing: chevron, onTap: () => _pickExcelYear(context)),
          const RowDivider(),
          ListRow(emoji: '📊', title: 'Export CSV', subtitle: Text("A year's transactions for Excel or Google Sheets", style: AppText.small.copyWith(color: c.inkSoft)), trailing: chevron, onTap: () => _pickCsvYear(context)),
          const SectionTitle('Start again'),
          ListRow(
            emoji: '🗑️',
            title: 'Reset all data',
            subtitle: Text('Delete everything and go back to the starter budget', style: AppText.small.copyWith(color: c.overText)),
            onTap: () => _reset(context),
          ),
          const SectionTitle('About'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$appName, version $appVersion', style: AppText.body.copyWith(color: c.ink)),
              const SizedBox(height: 4),
              Text('Your data never leaves this phone unless you export it.', style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
              const SizedBox(height: 4),
              Text('Free and open source. No accounts, no ads, no tracking.', style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
            ]),
          ),
        ]),
      ],
    );
  }
}
