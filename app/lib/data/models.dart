/// Vie d'un ticket : disponible, puis en cours, puis terminé (ou annulé).
enum TicketStatus {
  available('Disponible'),
  active('En cours'),
  expired('Terminé'),
  revoked('Annulé');

  const TicketStatus(this.label);
  final String label;
}

/// Moyen de paiement noté par le vendeur. Hotzi ne le vérifie pas.
enum PaymentMethod {
  cash('Espèces'),
  mobileMoney('Mobile Money'),
  other('Autre');

  const PaymentMethod(this.label);
  final String label;
}

class Plan {
  const Plan({
    this.id,
    required this.name,
    required this.durationMinutes,
    required this.priceFcfa,
    this.active = true,
    this.description = '',
    required this.createdAt,
  });

  final int? id;
  final String name;
  final int durationMinutes;
  final int priceFcfa;
  final bool active;
  final String description;
  final DateTime createdAt;

  Plan copyWith({int? id, String? name, int? durationMinutes, int? priceFcfa, bool? active, String? description}) =>
      Plan(
        id: id ?? this.id,
        name: name ?? this.name,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        priceFcfa: priceFcfa ?? this.priceFcfa,
        active: active ?? this.active,
        description: description ?? this.description,
        createdAt: createdAt,
      );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'duration_minutes': durationMinutes,
    'price_fcfa': priceFcfa,
    'active': active ? 1 : 0,
    'description': description,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory Plan.fromRow(Map<String, Object?> row) => Plan(
    id: row['id'] as int,
    name: row['name'] as String,
    durationMinutes: row['duration_minutes'] as int,
    priceFcfa: row['price_fcfa'] as int,
    active: row['active'] == 1,
    description: (row['description'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );
}

/// Un ticket garde une copie du nom, de la durée et du prix de son forfait :
/// modifier le forfait ensuite ne change pas un ticket déjà vendu.
class Ticket {
  const Ticket({
    this.id,
    required this.code,
    required this.planId,
    required this.planName,
    required this.durationMinutes,
    required this.priceFcfa,
    this.status = TicketStatus.available,
    required this.createdAt,
    this.activatedAt,
    this.expiresAt,
    this.clientId,
  });

  final int? id;

  /// Code normalisé, sans tiret : « K7QM4XPA ».
  final String code;
  final int? planId;
  final String planName;
  final int durationMinutes;
  final int priceFcfa;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String? clientId;

  Ticket copyWith({int? id}) => Ticket(
    id: id ?? this.id,
    code: code,
    planId: planId,
    planName: planName,
    durationMinutes: durationMinutes,
    priceFcfa: priceFcfa,
    status: status,
    createdAt: createdAt,
    activatedAt: activatedAt,
    expiresAt: expiresAt,
    clientId: clientId,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'code': code,
    'plan_id': planId,
    'plan_name': planName,
    'duration_minutes': durationMinutes,
    'price_fcfa': priceFcfa,
    'status': status.name,
    'created_at': createdAt.millisecondsSinceEpoch,
    'activated_at': activatedAt?.millisecondsSinceEpoch,
    'expires_at': expiresAt?.millisecondsSinceEpoch,
    'client_id': clientId,
  };

  factory Ticket.fromRow(Map<String, Object?> row) => Ticket(
    id: row['id'] as int,
    code: row['code'] as String,
    planId: row['plan_id'] as int?,
    planName: row['plan_name'] as String,
    durationMinutes: row['duration_minutes'] as int,
    priceFcfa: row['price_fcfa'] as int,
    status: TicketStatus.values.byName(row['status'] as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    activatedAt: _date(row['activated_at']),
    expiresAt: _date(row['expires_at']),
    clientId: row['client_id'] as String?,
  );

  static DateTime? _date(Object? millis) => millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);
}

/// Vente notée par le vendeur. Le montant est celui saisi, pas un paiement vérifié.
class Sale {
  const Sale({this.id, required this.ticketId, required this.soldAt, required this.amountFcfa, required this.payment});

  final int? id;
  final int ticketId;
  final DateTime soldAt;
  final int amountFcfa;
  final PaymentMethod payment;

  Map<String, Object?> toRow() => {
    'id': id,
    'ticket_id': ticketId,
    'sold_at': soldAt.millisecondsSinceEpoch,
    'amount_fcfa': amountFcfa,
    'payment_method': payment.name,
  };

  factory Sale.fromRow(Map<String, Object?> row) => Sale(
    id: row['id'] as int,
    ticketId: row['ticket_id'] as int,
    soldAt: DateTime.fromMillisecondsSinceEpoch(row['sold_at'] as int),
    amountFcfa: row['amount_fcfa'] as int,
    payment: PaymentMethod.values.byName(row['payment_method'] as String),
  );
}

/// Forfaits de démonstration du cahier des charges, modifiables par le vendeur.
List<Plan> demoPlans(DateTime now) => [
  Plan(name: 'Mini', durationMinutes: 30, priceFcfa: 50, createdAt: now),
  Plan(name: 'Standard', durationMinutes: 60, priceFcfa: 100, createdAt: now),
  Plan(name: 'Confort', durationMinutes: 6 * 60, priceFcfa: 300, createdAt: now),
  Plan(name: 'Journée', durationMinutes: 24 * 60, priceFcfa: 500, createdAt: now),
];
