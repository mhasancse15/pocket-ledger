import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/drift/database.dart';


/// Provides singleton instance of the Drift database
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
