import 'group_member.dart';

class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.members,
  });

  final String id;
  final String name;
  final List<GroupMember> members;

  ExpenseGroup copyWith({
    String? id,
    String? name,
    List<GroupMember>? members,
  }) {
    return ExpenseGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }
}
