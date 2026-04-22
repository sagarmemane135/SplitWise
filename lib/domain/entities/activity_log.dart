enum ActivityAction {
  groupCreated,
  memberJoined,
  memberNameChanged,
  expenseAdded,
  expenseUpdated,
  expenseDeleted,
  settlementRecorded
}

class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.groupId,
    required this.memberId,
    required this.action,
    required this.timestamp,
    required this.description,
  });

  final String id;
  final String groupId;
  final String memberId;
  final ActivityAction action;
  final DateTime timestamp;
  final String description;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'groupId': groupId,
      'memberId': memberId,
      'action': action.name,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }

  static ActivityLog? fromJson(Map<String, dynamic> json) {
    if (json['id'] == null ||
        json['groupId'] == null ||
        json['memberId'] == null ||
        json['action'] == null ||
        json['timestamp'] == null ||
        json['description'] == null) {
      return null;
    }

    final DateTime? ts = DateTime.tryParse(json['timestamp'].toString());
    if (ts == null) return null;

    ActivityAction parsedAction;
    try {
      parsedAction = ActivityAction.values.firstWhere((e) => e.name == json['action']);
    } catch (_) {
      parsedAction = ActivityAction.expenseAdded; // fallback
    }

    return ActivityLog(
      id: json['id'].toString(),
      groupId: json['groupId'].toString(),
      memberId: json['memberId'].toString(),
      action: parsedAction,
      timestamp: ts,
      description: json['description'].toString(),
    );
  }
}
