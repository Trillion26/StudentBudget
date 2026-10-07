import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// The database file lives in the app's documents folder on the phone.
QueryExecutor openConnection() => driftDatabase(name: 'student_budget');
