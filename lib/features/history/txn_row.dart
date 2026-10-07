import 'package:flutter/cupertino.dart';

import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/dates.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';

/// One transaction in a list: emoji tile, what it was, and the amount.
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.txn, required this.data, this.onTap, this.showDate = false});

  final Txn txn;
  final AppData data;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final title = data.describe(txn);
    final goal = txn.goalId == null ? null : data.goalById[txn.goalId];
    final details = <String>[
      if (txn.kind == TxnKind.toSavings) 'Saved',
      if (txn.kind == TxnKind.fromSavings) 'From savings${goal != null ? ' · ${goal.name}' : ''}',
      if (txn.kind == TxnKind.income) 'Received',
      if (txn.note.isNotEmpty) txn.note,
      if (showDate) shortDate(txn.date),
    ];
    final amountText = switch (txn.kind) {
      TxnKind.income => '+${formatRand(txn.amount)}',
      TxnKind.expense => formatRand(txn.amount),
      TxnKind.toSavings => formatRand(txn.amount),
      TxnKind.fromSavings => formatRand(txn.amount),
    };
    final amountColor = switch (txn.kind) {
      TxnKind.income => c.incomeText,
      TxnKind.toSavings => c.ink,
      _ => c.ink,
    };
    final kindWords = switch (txn.kind) {
      TxnKind.income => 'received',
      TxnKind.expense => 'spent',
      TxnKind.toSavings => 'saved',
      TxnKind.fromSavings => 'taken from savings',
    };
    return ListRow(
      emoji: data.emojiFor(txn),
      title: title,
      subtitle: details.isEmpty
          ? null
          : Text(details.join(' · '), style: AppText.small.copyWith(color: c.inkSoft)),
      trailing: Text(amountText, style: AppText.amount.copyWith(color: amountColor)),
      onTap: onTap,
      semanticLabel: '$title, ${formatRand(txn.amount)} $kindWords'
          '${txn.note.isNotEmpty ? ', ${txn.note}' : ''}, ${shortDate(txn.date)}',
    );
  }
}
