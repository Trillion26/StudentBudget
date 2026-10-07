import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/budget_store.dart';
import 'data/database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(StudentBudgetApp(store: BudgetStore(AppDatabase.open())));
}
