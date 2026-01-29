import 'package:sqflite/sqflite.dart';

/// Represents a single migration step for a table schema.
///
/// Each step upgrades a table to the given [version] when executed.
class MigrationStep {
  const MigrationStep(this.version, this.runner);

  /// Target schema version after this step runs.
  final int version;

  /// Executes the migration logic using the provided database executor.
  final Future<void> Function(DatabaseExecutor executor) runner;
}
