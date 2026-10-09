import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/data/database.dart';

/// A fixed "now" for tests: Wednesday 7 October 2026, 10:00.
final DateTime testNow = DateTime(2026, 10, 7, 10);

/// An example household plan in whole euros: € 4.500 coming in and
/// € 4.200 of planned spending. The starter budget itself is all zeros.
const Map<String, int> examplePlanEuros = {
  'Salary – Partner 1': 2500,
  'Salary – Partner 2': 2000,
  'Mortgage': 1400,
  'Groceries': 700,
  'Childcare (kinderopvang)': 600,
  'Health insurance – Partner 1': 150,
  'Health insurance – Partner 2': 150,
  'Energy (gas & electricity)': 180,
  'Fuel & charging': 150,
  'Eating out & takeaway': 150,
  'Clothes & shoes': 120,
  'Pocket money – Partner 1': 100,
  'Pocket money – Partner 2': 100,
  'Car insurance': 80,
  'Municipal taxes': 70,
  'Internet & TV': 60,
  'Road tax': 50,
  'Days out': 50,
  'Water': 30,
  'Phone – Partner 1': 20,
  'Phone – Partner 2': 20,
  'Streaming': 20,
};

/// A store backed by a fresh in-memory database, seeded with the starter
/// budget. With [examplePlan] (the default) the budgets in
/// [examplePlanEuros] are filled in. [clock] can be changed by the test to
/// move time.
Future<BudgetStore> createTestStore({DateTime Function()? clock, bool examplePlan = true}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(NativeDatabase.memory());
  final store = BudgetStore(db, clock: clock ?? () => testNow);
  await store.init();
  if (examplePlan) await setExamplePlan(store);
  return store;
}

Future<void> setExamplePlan(BudgetStore store) => store.setCategoryBudgets({
  for (final entry in examplePlanEuros.entries)
    store.data.categories.firstWhere((c) => c.name == entry.key).id: entry.value * 100,
});
