enum SplitMethod { equal, fixedAmount, percentage }

class ExpensePayer {
  const ExpensePayer({required this.memberId, required this.amount});

  final String memberId;
  final double amount;
}

class ExpenseParticipantShare {
  const ExpenseParticipantShare({required this.memberId, required this.value});

  final String memberId;
  final double value;
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    required this.payers,
    required this.participants,
    required this.splitMethod,
    required this.splitShares,
    required this.date,
    required this.createdBy,
  });

  final String id;
  final String groupId;
  final String title;
  final double totalAmount;
  final List<ExpensePayer> payers;
  final List<String> participants;
  final SplitMethod splitMethod;
  final List<ExpenseParticipantShare> splitShares;
  final DateTime date;
  final String createdBy;
}
