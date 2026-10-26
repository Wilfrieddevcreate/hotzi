import 'models.dart';

/// Accès aux données du vendeur. Pour l'instant en local (SQLite) ; une fois le
/// réseau validé, la base passera côté Kotlin pour que le service qui coupe
/// les clients y ait accès même quand l'app est fermée.
abstract interface class HotziRepository {
  Future<List<Plan>> plans();

  /// Crée le forfait s'il n'a pas d'identifiant, sinon le met à jour.
  Future<Plan> savePlan(Plan plan);

  Future<List<Ticket>> tickets();

  Future<List<Sale>> sales();

  /// Crée [quantity] tickets du forfait et note une vente pour chacun, en une
  /// seule opération : jamais de ticket sans vente, ni de vente sans ticket.
  Future<List<Ticket>> sell(Plan plan, int quantity, PaymentMethod payment, DateTime at);

  Future<String?> setting(String key);

  Future<void> saveSetting(String key, String value);
}
