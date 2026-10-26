import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'repository.dart';
import 'ticket_codes.dart';

class SqliteRepository implements HotziRepository {
  SqliteRepository._(this._db);

  final Database _db;

  static Future<SqliteRepository> open() async {
    final db = await openDatabase(
      join(await getDatabasesPath(), 'hotzi.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
    );
    return SqliteRepository._(db);
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE plans(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          duration_minutes INTEGER NOT NULL,
          price_fcfa INTEGER NOT NULL,
          active INTEGER NOT NULL DEFAULT 1,
          description TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE tickets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT NOT NULL UNIQUE,
          plan_id INTEGER REFERENCES plans(id),
          plan_name TEXT NOT NULL,
          duration_minutes INTEGER NOT NULL,
          price_fcfa INTEGER NOT NULL,
          status TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          activated_at INTEGER,
          expires_at INTEGER,
          client_id TEXT
        )''')
      ..execute('''
        CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ticket_id INTEGER NOT NULL REFERENCES tickets(id),
          sold_at INTEGER NOT NULL,
          amount_fcfa INTEGER NOT NULL,
          payment_method TEXT NOT NULL
        )''')
      ..execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    for (final plan in demoPlans(DateTime.now())) {
      batch.insert('plans', plan.toRow());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Plan>> plans() async =>
      (await _db.query('plans', orderBy: 'duration_minutes, id')).map(Plan.fromRow).toList();

  @override
  Future<Plan> savePlan(Plan plan) async {
    if (plan.id == null) {
      final id = await _db.insert('plans', plan.toRow());
      return plan.copyWith(id: id);
    }
    await _db.update('plans', plan.toRow(), where: 'id = ?', whereArgs: [plan.id]);
    return plan;
  }

  @override
  Future<List<Ticket>> tickets() async =>
      (await _db.query('tickets', orderBy: 'created_at DESC, id DESC')).map(Ticket.fromRow).toList();

  @override
  Future<List<Sale>> sales() async =>
      (await _db.query('sales', orderBy: 'sold_at DESC, id DESC')).map(Sale.fromRow).toList();

  @override
  Future<List<Ticket>> sell(Plan plan, int quantity, PaymentMethod payment, DateTime at) {
    return _db.transaction((txn) async {
      final created = <Ticket>[];
      for (var i = 0; i < quantity; i++) {
        final ticket = Ticket(
          code: await _uniqueCode(txn),
          planId: plan.id,
          planName: plan.name,
          durationMinutes: plan.durationMinutes,
          priceFcfa: plan.priceFcfa,
          createdAt: at,
        );
        final id = await txn.insert('tickets', ticket.toRow());
        await txn.insert('sales', Sale(ticketId: id, soldAt: at, amountFcfa: plan.priceFcfa, payment: payment).toRow());
        created.add(ticket.copyWith(id: id));
      }
      return created;
    });
  }

  Future<String> _uniqueCode(Transaction txn) async {
    while (true) {
      final code = TicketCodes.generate();
      final taken = await txn.query('tickets', columns: ['id'], where: 'code = ?', whereArgs: [code], limit: 1);
      if (taken.isEmpty) return code;
    }
  }

  @override
  Future<String?> setting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  @override
  Future<void> saveSetting(String key, String value) =>
      _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
