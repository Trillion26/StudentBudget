import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../logic/models.dart';
import 'database.dart';

/// A category in the starter budget. [budgetEuros] is the monthly budget in
/// whole euros (0 leaves it for the household to fill in).
class SeedCategory {
  const SeedCategory(this.emoji, this.name, [this.budgetEuros = 0]);
  final String emoji;
  final String name;
  final int budgetEuros;
}

class SeedGroup {
  const SeedGroup(this.icon, this.name, this.kind, this.categories);
  final String icon;
  final String name;
  final GroupKind kind;
  final List<SeedCategory> categories;
}

/// Categories named "… – Partner 1" or "… – Partner 2" are renamed when the
/// partners' names are set (see BudgetStore.setPartnerNames).
const String partner1Suffix = ' – Partner 1';
const String partner2Suffix = ' – Partner 2';

/// The default categories for a Dutch household with children and a
/// mortgage. Budgets start at € 0 so the household fills in its own.
const List<SeedGroup> seedGroups = [
  SeedGroup('💶', 'Income', GroupKind.income, [
    SeedCategory('💼', 'Salary$partner1Suffix'),
    SeedCategory('💼', 'Salary$partner2Suffix'),
    SeedCategory('👶', 'Child benefit (kinderbijslag)'),
    SeedCategory('🧒', 'Child budget (kindgebonden budget)'),
    SeedCategory('🏫', 'Childcare allowance (toeslag)'),
    SeedCategory('🧾', 'Tax refund'),
    SeedCategory('➕', 'Other income'),
  ]),
  SeedGroup('🏠', 'Housing & utilities', GroupKind.spending, [
    SeedCategory('🏠', mortgageCategoryName),
    SeedCategory('⚡', 'Energy (gas & electricity)'),
    SeedCategory('💧', 'Water'),
    SeedCategory('📡', 'Internet & TV'),
    SeedCategory('🏛️', 'Municipal taxes'),
    SeedCategory('🌊', 'Water board tax'),
    SeedCategory('🛡️', 'Home & contents insurance'),
    SeedCategory('⚖️', 'Liability & legal insurance'),
    SeedCategory('🔧', 'Maintenance & repairs'),
    SeedCategory('🛋️', 'Furniture & household items'),
  ]),
  SeedGroup('🩺', 'Health', GroupKind.spending, [
    SeedCategory('🏥', 'Health insurance$partner1Suffix'),
    SeedCategory('🏥', 'Health insurance$partner2Suffix'),
    SeedCategory('💶', 'Deductible (eigen risico)'),
    SeedCategory('🦷', 'Dentist & physio'),
    SeedCategory('💊', 'Pharmacy'),
  ]),
  SeedGroup('👶', 'Children & childcare', GroupKind.spending, [
    SeedCategory('🧸', 'Childcare (kinderopvang)'),
    SeedCategory('🍼', 'Nappies & baby food'),
    SeedCategory('👕', "Kids' clothes & shoes"),
    SeedCategory('🎒', 'School & activities'),
    SeedCategory('🧩', 'Toys & books'),
    SeedCategory('🧑‍🍼', 'Babysitter'),
  ]),
  SeedGroup('🛒', 'Groceries & household', GroupKind.spending, [
    SeedCategory('🛒', 'Groceries'),
    SeedCategory('🧴', 'Drugstore'),
    SeedCategory('🧽', 'Cleaning products'),
  ]),
  SeedGroup('🚗', 'Transport', GroupKind.spending, [
    SeedCategory('🚗', 'Car insurance'),
    SeedCategory('🧾', 'Road tax'),
    SeedCategory('⛽', 'Fuel & charging'),
    SeedCategory('🔧', 'Car maintenance & APK'),
    SeedCategory('🅿️', 'Parking'),
    SeedCategory('🚆', 'Public transport'),
    SeedCategory('🚲', 'Bikes'),
  ]),
  SeedGroup('📱', 'Sport, subs & phones', GroupKind.spending, [
    SeedCategory('📱', 'Phone$partner1Suffix'),
    SeedCategory('📱', 'Phone$partner2Suffix'),
    SeedCategory('🎬', 'Streaming'),
    SeedCategory('🏋️', 'Sport & gym'),
    SeedCategory('📰', 'Other subscriptions'),
  ]),
  SeedGroup('🙂', 'Personal & lifestyle', GroupKind.spending, [
    SeedCategory('👗', 'Clothes & shoes'),
    SeedCategory('🍽️', 'Eating out & takeaway'),
    SeedCategory('🎉', 'Going out'),
    SeedCategory('💈', 'Hairdresser & care'),
    SeedCategory('🎁', 'Gifts & celebrations'),
    SeedCategory('🎨', 'Hobbies'),
    SeedCategory('💝', 'Charity'),
  ]),
  SeedGroup('🐾', 'Pets', GroupKind.spending, [
    SeedCategory('🥫', 'Pet food'),
    SeedCategory('🩺', 'Vet'),
    SeedCategory('🛡️', 'Pet insurance'),
  ]),
  SeedGroup('🧳', 'Holidays & trips', GroupKind.spending, [
    SeedCategory('🏖️', 'Holiday'),
    SeedCategory('🏕️', 'Weekends away'),
    SeedCategory('🎡', 'Days out'),
  ]),
  SeedGroup('💳', 'Loans', GroupKind.spending, [
    SeedCategory('🎓', 'Student loan (DUO)'),
    SeedCategory('🚙', 'Car loan'),
    SeedCategory('💳', 'Other loans'),
  ]),
  SeedGroup('👛', 'Personal money', GroupKind.spending, [
    SeedCategory('👛', 'Pocket money$partner1Suffix'),
    SeedCategory('👛', 'Pocket money$partner2Suffix'),
  ]),
  SeedGroup('🏦', 'Bank & other', GroupKind.spending, [
    SeedCategory('🏦', 'Bank fees'),
    SeedCategory('🧾', 'Other costs'),
  ]),
];

/// Default savings goals (all start at € 0 with no target).
const List<(String, String)> seedGoals = [
  ('🛟', 'Emergency buffer'),
  ('🏖️', 'Holiday fund'),
  ('👶', "Kids' savings"),
  ('🔨', 'Home improvements'),
  ('🚗', 'Next car'),
  ('📈', 'Investments'),
];

/// The category that mortgage payments are logged in.
const String mortgageCategoryName = 'Mortgage';

/// Suggested monthly saving for the Emergency buffer, shown in onboarding.
const int suggestedEmergencySavingCents = 10000;

/// Writes the starter data. Does nothing if the settings row already exists.
Future<void> seedIfEmpty(AppDatabase db, {DateTime? now}) async {
  final existing = await db.select(db.settings).getSingleOrNull();
  if (existing != null) return;
  await seedDefaults(db, now: now);
}

/// Writes the starter data into an empty database.
Future<void> seedDefaults(AppDatabase db, {DateTime? now}) async {
  const uuid = Uuid();
  final created = (now ?? DateTime.now()).toUtc();
  await db.transaction(() async {
    var groupOrder = 0;
    for (final g in seedGroups) {
      final groupId = uuid.v4();
      await db
          .into(db.categoryGroups)
          .insert(
            CategoryGroupsCompanion.insert(
              id: groupId,
              createdAt: created,
              name: g.name,
              icon: g.icon,
              sortOrder: groupOrder++,
              kind: g.kind,
            ),
          );
      var categoryOrder = 0;
      for (final c in g.categories) {
        final id = uuid.v4();
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: id,
                createdAt: created,
                name: c.name,
                emoji: c.emoji,
                groupId: groupId,
                monthlyBudget: Value(c.budgetEuros * 100),
                sortOrder: categoryOrder++,
              ),
            );
      }
    }
    var goalOrder = 0;
    for (final (emoji, name) in seedGoals) {
      await db
          .into(db.savingsGoals)
          .insert(
            SavingsGoalsCompanion.insert(
              id: uuid.v4(),
              createdAt: created,
              name: name,
              emoji: emoji,
              sortOrder: Value(goalOrder++),
            ),
          );
    }
    await db.into(db.settings).insert(SettingsCompanion.insert(id: const Value(1), createdAt: created));
  });
}
