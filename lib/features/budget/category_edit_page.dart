import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/form_fields.dart';
import '../../design/euro_field.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/models.dart';
import '../../logic/validation.dart';

/// Add or edit a category: name, emoji, group, budget, archive.
class CategoryEditPage extends StatefulWidget {
  const CategoryEditPage({super.key, this.category, this.groupId}) : assert(category != null || groupId != null);

  final BudgetCategory? category;
  final String? groupId;

  @override
  State<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends State<CategoryEditPage> {
  late final TextEditingController _name = TextEditingController(text: widget.category?.name ?? '');
  late String _emoji = widget.category?.emoji ?? '🏷️';
  late String _groupId = widget.category?.groupId ?? widget.groupId!;
  late int _budget = widget.category?.monthlyBudget ?? 0;
  String? _nameError;

  bool get _isNew => widget.category == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final error = store.categoryNameError(_name.text, exceptId: widget.category?.id);
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    if (_isNew) {
      await store.addCategory(groupId: _groupId, name: _name.text, emoji: _emoji, monthlyBudget: _budget);
    } else {
      await store.updateCategory(widget.category!, name: _name.text, emoji: _emoji, groupId: _groupId);
      if (_budget != widget.category!.monthlyBudget) await store.setCategoryBudget(widget.category!.id, _budget);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleArchive() async {
    final store = StoreScope.read(context);
    final archive = !widget.category!.isArchived;
    if (archive) {
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Archive ${widget.category!.name}?'),
          content: const Text('It disappears from your budget and the Add sheet. Past entries stay in History, and you can bring it back any time.'),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await store.setCategoryArchived(widget.category!.id, archive);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final group = data.groupById[_groupId]!;
    final sameKindGroups = data.groups.where((g) => g.kind == group.kind).toList();
    return PageScaffold(
      title: _isNew ? 'New category' : 'Edit category',
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(
            children: [
              LabeledField(
                label: 'Name',
                error: _nameError,
                child: AppTextField(
                  controller: _name,
                  maxLength: Validation.maxNameLength,
                  placeholder: 'e.g. Gas for cooking',
                  semanticLabel: 'Category name',
                  hasError: _nameError != null,
                  autofocus: _isNew,
                  onChanged: (_) => setState(() => _nameError = null),
                ),
              ),
              LabeledField(label: 'Emoji', child: EmojiPicker(value: _emoji, onChanged: (e) => setState(() => _emoji = e))),
              if (sameKindGroups.length > 1)
                LabeledField(
                  label: 'Group',
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showCupertinoModalPopup<String>(
                        context: context,
                        builder: (context) => CupertinoActionSheet(
                          title: const Text('Move to group'),
                          actions: [
                            for (final g in sameKindGroups)
                              CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, g.id), child: Text('${g.icon} ${g.name}')),
                          ],
                          cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        ),
                      );
                      if (picked != null) setState(() => _groupId = picked);
                    },
                    child: NoteBox(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      child: Row(children: [
                        Expanded(child: Text('${group.icon} ${group.name}', style: AppText.body.copyWith(color: c.ink))),
                        Icon(CupertinoIcons.chevron_down, size: 16, color: c.inkSoft),
                      ]),
                    ),
                  ),
                ),
              LabeledField(
                label: group.kind == GroupKind.income ? 'Expected each month' : 'Monthly budget',
                child: EuroField(cents: _budget, width: double.infinity, textAlign: TextAlign.left, semanticLabel: 'Monthly budget', onChanged: (v) => _budget = v),
              ),
              const SizedBox(height: 8),
              PrimaryButton(label: _isNew ? 'Add category' : 'Save', onPressed: _save),
              if (!_isNew) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  label: widget.category!.isArchived ? 'Bring back' : 'Archive category',
                  color: widget.category!.isArchived ? null : c.overText,
                  onPressed: _toggleArchive,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
