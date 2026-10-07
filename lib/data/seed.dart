import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../logic/dates.dart';
import '../logic/models.dart';
import 'database.dart';

/// A category in the starter budget. [budgetRand] is the monthly budget in
/// whole rand (0 when the brief gives no amount).
class SeedCategory {
  const SeedCategory(this.emoji, this.name, [this.budgetRand = 0]);
  final String emoji;
  final String name;
  final int budgetRand;
}

class SeedGroup {
  const SeedGroup(this.icon, this.name, this.kind, this.categories);
  final String icon;
  final String name;
  final GroupKind kind;
  final List<SeedCategory> categories;
}

/// The default categories and starter budget from Student_Budget_ZAR.xlsx:
/// R4 500 coming in, R4 200 of spending.
const List<SeedGroup> seedGroups = [
  SeedGroup('💰', 'Income', GroupKind.income, [
    SeedCategory('👪', 'Allowance from family', 3000),
    SeedCategory('🎓', 'NSFAS / bursary allowance'),
    SeedCategory('💼', 'Part-time job', 1500),
    SeedCategory('✏️', 'Tutoring & side gigs'),
    SeedCategory('➕', 'Other income'),
  ]),
  SeedGroup('🏠', 'Accommodation', GroupKind.spending, [
    SeedCategory('🏠', 'Rent / res fees'),
    SeedCategory('⚡', 'Electricity – prepaid', 200),
    SeedCategory('💧', 'Water'),
    SeedCategory('📡', 'Wi-Fi'),
    SeedCategory('🧾', 'Res / flat levies & admin fees'),
    SeedCategory('🛡️', 'Contents insurance'),
    SeedCategory('🧺', 'Laundry', 60),
    SeedCategory('🍽️', 'Household items', 50),
    SeedCategory('🛏️', 'Furniture & bedding'),
    SeedCategory('🧽', 'Cleaning supplies', 60),
    SeedCategory('🏘️', 'Other accommodation'),
  ]),
  SeedGroup('🩺', 'Health & insurance', GroupKind.spending, [
    SeedCategory('🏥', 'Medical aid / hospital plan'),
    SeedCategory('📱', 'Phone & laptop insurance'),
    SeedCategory('💊', 'Medication', 80),
    SeedCategory('🦷', 'Doctor & dentist'),
    SeedCategory('👓', 'Glasses & contact lenses'),
  ]),
  SeedGroup('🎓', 'Studies', GroupKind.spending, [
    SeedCategory('🏛️', 'Tuition fees – my share'),
    SeedCategory('📝', 'Registration fees'),
    SeedCategory('📚', 'Textbooks', 200),
    SeedCategory('🖊️', 'Stationery', 60),
    SeedCategory('💻', 'Laptop / device repayment'),
    SeedCategory('🧩', 'Software & apps for studies'),
    SeedCategory('🖨️', 'Printing & photocopies', 80),
    SeedCategory('🔬', 'Course materials & lab kit'),
    SeedCategory('📋', 'Exam & application fees'),
    SeedCategory('🚌', 'Field trips & projects'),
    SeedCategory('📎', 'Other study costs'),
  ]),
  SeedGroup('🛒', 'Groceries & household', GroupKind.spending, [
    SeedCategory('🛒', 'Groceries', 1100),
    SeedCategory('🍱', 'Meal plan / campus food', 200),
  ]),
  SeedGroup('🚕', 'Transport', GroupKind.spending, [
    SeedCategory('🚆', 'Bus / train pass'),
    SeedCategory('🚗', 'Car insurance'),
    SeedCategory('⛽', 'Petrol'),
    SeedCategory('🅿️', 'Parking'),
    SeedCategory('🔧', 'Car service & repairs'),
    SeedCategory('🚕', 'Taxi fares', 400),
    SeedCategory('🚙', 'Uber / Bolt', 100),
    SeedCategory('🚲', 'Bicycle / scooter'),
    SeedCategory('🛣️', 'Other transport'),
  ]),
  SeedGroup('📶', 'Subscriptions & phone', GroupKind.spending, [
    SeedCategory('🏋️', 'Gym'),
    SeedCategory('🎭', 'Clubs & societies', 50),
    SeedCategory('🎧', 'Music streaming', 40),
    SeedCategory('📺', 'Showmax / DStv'),
    SeedCategory('🎬', 'Netflix & other streaming'),
    SeedCategory('📞', 'Airtime / cellphone contract', 50),
    SeedCategory('📶', 'Data bundles', 250),
  ]),
  SeedGroup('🙂', 'Personal & lifestyle', GroupKind.spending, [
    SeedCategory('🍔', 'Eating out & takeaways', 200),
    SeedCategory('🎉', 'Going out & parties', 150),
    SeedCategory('👟', 'Clothes & shoes', 100),
    SeedCategory('🧴', 'Toiletries & personal care', 200),
    SeedCategory('💈', 'Haircuts & grooming', 80),
    SeedCategory('🎨', 'Hobbies'),
    SeedCategory('⛪', 'Church & charity'),
    SeedCategory('☕', 'Coffee & snacks on campus', 80),
    SeedCategory('🎁', 'Gifts & celebrations', 50),
    SeedCategory('🛍️', 'Other personal', 100),
  ]),
  SeedGroup('🤝', 'Family & stokvel', GroupKind.spending, [
    SeedCategory('🏡', 'Money sent home'),
    SeedCategory('🤝', 'Stokvel contribution'),
  ]),
  SeedGroup('🧳', 'Holidays & trips', GroupKind.spending, [
    SeedCategory('🏖️', 'Holiday spending'),
    SeedCategory('✈️', 'Bus or flight home', 200),
    SeedCategory('🏕️', 'Weekends away'),
    SeedCategory('🎡', 'Day trips & outings'),
    SeedCategory('🎟️', 'Other one-off costs'),
  ]),
  SeedGroup('💳', 'Debt repayments', GroupKind.spending, [
    SeedCategory('💳', 'Credit / store card'),
    SeedCategory('🎓', 'Student loan repayment'),
    SeedCategory('🤲', 'Other loan (e.g. family)'),
  ]),
  SeedGroup('👛', 'Personal money', GroupKind.spending, [
    SeedCategory('👛', 'Pocket money'),
  ]),
  SeedGroup('🏦', 'Bank & cash', GroupKind.spending, [
    SeedCategory('🏦', 'Bank fees', 60),
    SeedCategory('🏧', 'Cash withdrawals'),
  ]),
];

/// Default savings goals (all start at R0 with no target).
const List<(String, String)> seedGoals = [
  ('🛟', 'Emergency fund'),
  ('💻', 'Laptop & tech fund'),
  ('🌍', 'Holiday & travel fund'),
  ('🚗', "Driver's licence fund"),
  ('📚', "Next year's textbooks fund"),
  ('🎓', 'Graduation & moving fund'),
];

/// Name of the category the default "Student loan" debt is linked to.
const String studentLoanCategoryName = 'Student loan repayment';

/// Suggested monthly saving for the Emergency fund, shown in onboarding.
const int suggestedEmergencySavingCents = 20000;

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
    String? loanCategoryId;
    var groupOrder = 0;
    for (final g in seedGroups) {
      final groupId = uuid.v4();
      await db.into(db.categoryGroups).insert(CategoryGroupsCompanion.insert(
            id: groupId,
            createdAt: created,
            name: g.name,
            icon: g.icon,
            sortOrder: groupOrder++,
            kind: g.kind,
          ));
      var categoryOrder = 0;
      for (final c in g.categories) {
        final id = uuid.v4();
        if (c.name == studentLoanCategoryName) loanCategoryId = id;
        await db.into(db.categories).insert(CategoriesCompanion.insert(
              id: id,
              createdAt: created,
              name: c.name,
              emoji: c.emoji,
              groupId: groupId,
              monthlyBudget: Value(c.budgetRand * 100),
              sortOrder: categoryOrder++,
            ));
      }
    }
    var goalOrder = 0;
    for (final (emoji, name) in seedGoals) {
      await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
            id: uuid.v4(),
            createdAt: created,
            name: name,
            emoji: emoji,
            sortOrder: Value(goalOrder++),
          ));
    }
    await db.into(db.debts).insert(DebtsCompanion.insert(
          id: uuid.v4(),
          createdAt: created,
          name: 'Student loan',
          startDate: dateOnly(now ?? DateTime.now()),
          linkedCategoryId: Value(loanCategoryId),
        ));
    await db.into(db.settings).insert(SettingsCompanion.insert(id: const Value(1), createdAt: created));
  });
}
