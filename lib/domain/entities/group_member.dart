enum MemberRole { admin, member }

class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final MemberRole role;

  GroupMember copyWith({
    String? id,
    String? name,
    MemberRole? role,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }
}
