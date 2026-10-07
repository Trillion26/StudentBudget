import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView, ReorderableDragStartListener;

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/form_fields.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/money.dart';
import '../../logic/validation.dart';
import 'category_edit_page.dart';

/// Rename a group, change its emoji, reorder its categories and see
/// archived ones. Also used to add a new group (when [group] is null).
class GroupEditPage extends StatefulWidget {
  const GroupEditPage({super.key, this.group});

  final CategoryGroup? group;

  @override
  State<GroupEditPage> createState() => _GroupEditPageState();
}

class _GroupEditPageState extends State<GroupEditPage> {
  late final TextEditingController _name = TextEditingController(text: widget.group?.name ?? '');
  late String _icon = widget.group?.icon ?? '📦';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    final error = Validation.name(_name.text, thing: 'the group');
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final store = StoreScope.read(context);
    final navigator = Navigator.of(context);
    if (widget.group == null) {
      final group = await store.addGroup(name: _name.text, icon: _icon);
      navigator.pushReplacement(CupertinoPageRoute<void>(builder: (_) => GroupEditPage(group: group)));
    } else {
      await store.updateGroup(store.data.groupById[widget.group!.id]!, name: _name.text, icon: _icon);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final group = widget.group == null ? null : data.groupById[widget.group!.id];
    final active = group == null ? <BudgetCategory>[] : data.categoriesIn(group.id);
    final archived = group == null ? <BudgetCategory>[] : data.categoriesIn(group.id, includeArchived: true).where((c) => c.isArchived).toList();

    return PageScaffold(
      title: group == null ? 'New group' : 'Edit group',
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(children: [
            LabeledField(
              label: 'Group name',
              error: _error,
              child: AppTextField(
                controller: _name,
                maxLength: Validation.maxNameLength,
                placeholder: 'e.g. Pets',
                semanticLabel: 'Group name',
                hasError: _error != null,
                autofocus: group == null,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            LabeledField(label: 'Emoji', child: EmojiPicker(value: _icon, onChanged: (e) => setState(() => _icon = e))),
            PrimaryButton(label: group == null ? 'Add group' : 'Save name and emoji', onPressed: _saveDetails),
          ]),
        ),
        if (group != null) ...[
          SliverToBoxAdapter(
            child: SectionTitle(
              'Categories',
              trailing: Text('Drag ≡ to reorder', style: AppText.small.copyWith(color: c.inkSoft)),
            ),
          ),
          SliverToBoxAdapter(
            child: ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                final ids = active.map((c) => c.id).toList();
                ids.insert(newIndex, ids.removeAt(oldIndex));
                store.reorderCategories(ids);
              },
              children: [
                for (final (i, cat) in active.indexed)
                  Container(
                    key: ValueKey(cat.id),
                    color: c.paper,
                    child: ListRow(
                      emoji: cat.emoji,
                      title: cat.name,
                      subtitle: Text(
                        cat.monthlyBudget == 0 ? 'No budget' : '${formatRand(cat.monthlyBudget)} a month',
                        style: AppText.small.copyWith(color: c.inkSoft),
                      ),
                      onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => CategoryEditPage(category: cat))),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: Semantics(
                          label: 'Drag to reorder ${cat.name}',
                          child: SizedBox(width: 44, height: 44, child: Icon(CupertinoIcons.line_horizontal_3, color: c.inkSoft)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: LinkButton(
              label: 'Add a category',
              icon: CupertinoIcons.plus,
              onPressed: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => CategoryEditPage(groupId: group.id))),
            ),
          ),
          if (archived.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionTitle('Archived')),
            SliverList.list(children: [
              for (final cat in archived)
                ListRow(
                  emoji: cat.emoji,
                  title: cat.name,
                  subtitle: Text('Hidden from your budget and the Add sheet', style: AppText.small.copyWith(color: c.inkSoft)),
                  trailing: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(44, 44),
                    onPressed: () => store.setCategoryArchived(cat.id, false),
                    child: Text('Bring back', style: AppText.small.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ],
        ],
      ],
    );
  }
}
