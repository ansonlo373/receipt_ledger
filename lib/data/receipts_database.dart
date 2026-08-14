import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'receipts_database.g.dart';

class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get merchant => text()();

  IntColumn get amountYen => integer()();

  DateTimeColumn get date => dateTime()();

  TextColumn get category => text()();

  TextColumn get notes => text().nullable()();
}

@DriftDatabase(tables: [Receipts])
class ReceiptsDatabase extends _$ReceiptsDatabase {
  ReceiptsDatabase() : super(_openConnection());

  ReceiptsDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'receipts.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
