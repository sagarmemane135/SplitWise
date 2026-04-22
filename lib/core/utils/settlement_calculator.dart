import 'dart:math';

class Settlement {
  const Settlement({required this.fromId, required this.toId, required this.amount});
  final String fromId;
  final String toId;
  final double amount;
}

List<Settlement> calculateOptimalSettlements(Map<String, double> balances) {
  final List<MapEntry<String, double>> creditors = balances.entries
      .where((MapEntry<String, double> e) => e.value > 0.01)
      .toList()
    ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));

  final List<MapEntry<String, double>> debtors = balances.entries
      .where((MapEntry<String, double> e) => e.value < -0.01)
      .toList()
    ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));

  final List<Settlement> settlements = <Settlement>[];

  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    final MapEntry<String, double> creditor = creditors.removeLast();
    final MapEntry<String, double> debtor = debtors.removeAt(0);

    final double debtAbs = debtor.value.abs();
    final double credit = creditor.value;
    final double settledAmount = min(debtAbs, credit);

    if (settledAmount < 0.01) continue;

    settlements.add(Settlement(fromId: debtor.key, toId: creditor.key, amount: settledAmount));

    final double remainingCredit = credit - settledAmount;
    final double remainingDebt = debtAbs - settledAmount;

    if (remainingCredit > 0.01) {
      creditors.add(MapEntry<String, double>(creditor.key, remainingCredit));
      creditors.sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));
    }
    if (remainingDebt > 0.01) {
      debtors.insert(0, MapEntry<String, double>(debtor.key, -remainingDebt));
    }
  }

  return settlements;
}
