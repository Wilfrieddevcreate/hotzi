import 'package:flutter/services.dart';

import 'models.dart';
import 'repository.dart';

/// Données enregistrées côté Kotlin (bibliothèque `net`), pour que le service
/// qui coupe les clients les lise même quand l'app est fermée.
class NativeRepository implements HotziRepository {
  static const _channel = MethodChannel('hotzi/data');

  Future<List<Map<String, Object?>>> _rows(String method, [Object? arguments]) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(method, arguments) ?? const [];
    return [for (final row in rows) row.cast<String, Object?>()];
  }

  @override
  Future<List<Plan>> plans() async => (await _rows('plans')).map(Plan.fromRow).toList();

  @override
  Future<Plan> savePlan(Plan plan) async {
    final row = await _channel.invokeMapMethod<String, Object?>('savePlan', plan.toRow());
    return Plan.fromRow(row!);
  }

  @override
  Future<List<Ticket>> tickets() async => (await _rows('tickets')).map(Ticket.fromRow).toList();

  @override
  Future<List<Sale>> sales() async => (await _rows('sales')).map(Sale.fromRow).toList();

  @override
  Future<List<Ticket>> sell(Plan plan, int quantity, PaymentMethod payment, DateTime at) async {
    final rows = await _rows('sell', {
      'plan_id': plan.id,
      'quantity': quantity,
      'payment': payment.name,
      'at': at.millisecondsSinceEpoch,
    });
    return rows.map(Ticket.fromRow).toList();
  }

  @override
  Future<String?> setting(String key) => _channel.invokeMethod<String>('setting', {'key': key});

  @override
  Future<void> saveSetting(String key, String value) =>
      _channel.invokeMethod<void>('saveSetting', {'key': key, 'value': value});
}
