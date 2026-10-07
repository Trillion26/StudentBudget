import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../design/app_colors.dart';
import '../../design/rand_field.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/money.dart';

/// Amount fields for each income category ("What comes in each month?").
/// Changes save immediately. Used by onboarding and the Overview empty state.
class IncomeFields extends StatelessWidget {
  const IncomeFields({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final stacked = useStackedLayout(context);
    final categories = data.activeIncomeCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, cat) in categories.indexed) ...[
          if (i > 0) const RowDivider(indent: 56),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Flex(
              direction: stacked ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                if (stacked)
                  Row(children: [EmojiTile(cat.emoji), const SizedBox(width: 16), Expanded(child: Text(cat.name, style: AppText.body.copyWith(color: c.ink)))])
                else ...[
                  EmojiTile(cat.emoji),
                  const SizedBox(width: 16),
                  Expanded(child: Text(cat.name, style: AppText.body.copyWith(color: c.ink))),
                ],
                if (stacked) const SizedBox(height: 8) else const SizedBox(width: 12),
                RandField(
                  key: ValueKey('income-${cat.id}'),
                  cents: cat.monthlyBudget,
                  width: stacked ? double.infinity : 130,
                  semanticLabel: '${cat.name}, monthly amount',
                  onChanged: (cents) => store.setCategoryBudget(cat.id, cents),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Total each month: ${formatRand(data.plannedIncome)}',
          style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// A page with just the income fields, opened from Overview's empty state.
class IncomeSetupPage extends StatelessWidget {
  const IncomeSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PageScaffold(
      title: 'Monthly income',
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(
            children: [
              Text(
                'Roughly how much comes in each month? Leave a line empty if it doesn\'t apply to you.',
                style: AppText.bodyRegular.copyWith(color: c.inkSoft),
              ),
              const SizedBox(height: 12),
              const IncomeFields(),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ],
    );
  }
}
