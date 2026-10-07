import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:student_budget/data/budget_store.dart';
import 'package:student_budget/data/database.dart';

/// A fixed "now" for tests: Wednesday 7 October 2026, 10:00.
final DateTime testNow = DateTime(2026, 10, 7, 10);

/// A store backed by a fresh in-memory database, seeded with the starter
/// budget. [clock] can be changed by the test to move time.
Future<BudgetStore> createTestStore({DateTime Function()? clock}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(NativeDatabase.memory());
  final store = BudgetStore(db, clock: clock ?? () => testNow);
  await store.init();
  return store;
}
