import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';

class JoinLinkResult {
  const JoinLinkResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class AppStateScope extends StatefulWidget {
  const AppStateScope({super.key, required this.child});

  final Widget child;

  static AppStateController of(BuildContext context) {
    final _AppStateInherited? inherited =
        context.dependOnInheritedWidgetOfExactType<_AppStateInherited>();
    assert(inherited != null, 'AppStateScope not found in widget tree.');
    return inherited!.controller;
  }

  @override
  State<AppStateScope> createState() => _AppStateScopeState();
}

class _AppStateScopeState extends State<AppStateScope> {
  late final AppStateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppStateController()
      ..initialize();
  }

  @override
  Widget build(BuildContext context) {
    return _AppStateInherited(controller: _controller, child: widget.child);
  }
}

class _AppStateInherited extends InheritedNotifier<AppStateController> {
  const _AppStateInherited({required this.controller, required super.child})
      : super(notifier: controller);

  final AppStateController controller;
}

class AppStateController extends ChangeNotifier {
  static const String _profileNameKey = 'profile.displayName';
  static const String _profileCurrencyKey = 'profile.currencyCode';
  static const String _profileUserIdKey = 'profile.userId';

  final List<ExpenseGroup> _groups = <ExpenseGroup>[];
  final Map<String, List<ExpenseItem>> _expensesByGroup = <String, List<ExpenseItem>>{};
  final Map<String, String> _identityByGroup = <String, String>{};
  final Map<String, String> _joinTokenByGroup = <String, String>{};
  int _idCounter = 0;

  String? _activeGroupId;
  bool _isInitialized = false;
  String? _localProfileUserId;
  String? _localProfileName;
  String? _localCurrencyCode;

  bool get isInitialized => _isInitialized;
  bool get hasLocalProfile => _localProfileName != null && _localProfileUserId != null;
  String? get localProfileName => _localProfileName;
  String? get localProfileUserId => _localProfileUserId;
  String get localCurrencyCode => _localCurrencyCode ?? 'INR';

  List<ExpenseGroup> get groups => List<ExpenseGroup>.unmodifiable(_groups);

  String? get activeGroupId => _activeGroupId;

  ExpenseGroup? get activeGroup {
    if (_activeGroupId == null) {
      return null;
    }
    for (final ExpenseGroup group in _groups) {
      if (group.id == _activeGroupId) {
        return group;
      }
    }
    return null;
  }

  GroupMember? get activeIdentity {
    final ExpenseGroup? group = activeGroup;
    if (group == null) {
      return null;
    }
    final String? selectedId = _identityByGroup[group.id];
    if (selectedId == null) {
      return null;
    }
    for (final GroupMember member in group.members) {
      if (member.id == selectedId) {
        return member;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _localProfileUserId = prefs.getString(_profileUserIdKey);
    _localProfileName = prefs.getString(_profileNameKey);
    _localCurrencyCode = prefs.getString(_profileCurrencyKey);

    _isInitialized = true;
    notifyListeners();
  }

  Future<String?> saveLocalProfile({
    required String displayName,
    required String currencyCode,
  }) async {
    final String trimmedName = displayName.trim();
    final String normalizedCurrency = currencyCode.trim().toUpperCase();

    if (trimmedName.isEmpty) {
      return 'Display name is required.';
    }
    if (normalizedCurrency.length < 3 || normalizedCurrency.length > 5) {
      return 'Enter a valid currency code like INR or USD.';
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _localProfileUserId ??= _newId('user');
    _localProfileName = trimmedName;
    _localCurrencyCode = normalizedCurrency;

    await prefs.setString(_profileUserIdKey, _localProfileUserId!);
    await prefs.setString(_profileNameKey, _localProfileName!);
    await prefs.setString(_profileCurrencyKey, _localCurrencyCode!);

    notifyListeners();
    return null;
  }

  List<ExpenseItem> get activeGroupExpenses {
    final String? groupId = _activeGroupId;
    if (groupId == null) {
      return const <ExpenseItem>[];
    }
    return List<ExpenseItem>.unmodifiable(_expensesByGroup[groupId] ?? const <ExpenseItem>[]);
  }

  bool hasDuplicateMemberName(ExpenseGroup group, String name) {
    final String normalized = name.trim().toLowerCase();
    for (final GroupMember member in group.members) {
      if (member.name.trim().toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  String? createGroup({required String groupName}) {
    if (!hasLocalProfile) {
      return 'Complete local profile setup first.';
    }

    final String trimmedGroup = groupName.trim();
    if (trimmedGroup.isEmpty) {
      return 'Group name is required.';
    }

    for (final ExpenseGroup group in _groups) {
      if (group.name.trim().toLowerCase() == trimmedGroup.toLowerCase()) {
        return 'A group with this name already exists.';
      }
    }

    final String groupId = _newId('group');
    final String adminId = _localProfileUserId!;
    _groups.add(
      ExpenseGroup(
        id: groupId,
        name: trimmedGroup,
        members: <GroupMember>[
          GroupMember(id: adminId, name: _localProfileName!, role: MemberRole.admin),
        ],
      ),
    );
    _activeGroupId = groupId;
    _identityByGroup[groupId] = adminId;
    _expensesByGroup[groupId] = <ExpenseItem>[];
    _joinTokenByGroup[groupId] = _newInviteToken();
    notifyListeners();
    return null;
  }

  String? buildInviteLinkForActiveGroup() {
    final ExpenseGroup? group = activeGroup;
    if (group == null) {
      return null;
    }

    final String token = _joinTokenByGroup.putIfAbsent(group.id, _newInviteToken);
    final String snapshot = _encodeGroupSnapshot(group, token);
    if (kIsWeb) {
      return _buildWebInviteLink(groupId: group.id, token: token, snapshot: snapshot);
    }

    final Uri nativeUri = Uri(
      scheme: 'splitwise',
      host: 'join',
      queryParameters: <String, String>{
        'groupId': group.id,
        'token': token,
        'snapshot': snapshot,
      },
    );
    return nativeUri.toString();
  }

  JoinLinkResult joinGroupViaLink(String rawLink) {
    if (!hasLocalProfile) {
      return const JoinLinkResult(
        success: false,
        message: 'Complete local profile setup first.',
      );
    }

    final String trimmed = rawLink.trim();
    if (trimmed.isEmpty) {
      return const JoinLinkResult(
        success: false,
        message: 'Invite link is required.',
      );
    }

    late final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return const JoinLinkResult(
        success: false,
        message: 'Invalid link format.',
      );
    }

    final bool isJoinInFragment = uri.fragment.startsWith('/join');
    final bool isSupportedLink =
        (uri.scheme == 'splitwise' && uri.host == 'join') ||
        ((uri.scheme == 'https' || uri.scheme == 'http') &&
            (uri.path.contains('join') || isJoinInFragment));
    if (!isSupportedLink) {
      return const JoinLinkResult(
        success: false,
        message: 'Unsupported invite link.',
      );
    }

    final Map<String, String> params = _extractJoinParams(uri);
    final String? groupId = params['groupId'];
    final String? token = params['token'];
    final String? snapshot = params['snapshot'];
    if (groupId == null || groupId.isEmpty || token == null || token.isEmpty) {
      return const JoinLinkResult(
        success: false,
        message: 'Invite link is missing required details.',
      );
    }

    ExpenseGroup? group = _groupById(groupId);
    if (group == null && snapshot != null && snapshot.isNotEmpty) {
      group = _tryHydrateGroupFromSnapshot(snapshot, groupId, token);
    }
    if (group == null) {
      return const JoinLinkResult(
        success: false,
        message: 'This group was not found. Ask host to send a fresh invite link.',
      );
    }

    final String? expectedToken = _joinTokenByGroup[group.id];
    if (expectedToken == null || expectedToken != token) {
      return const JoinLinkResult(
        success: false,
        message: 'Invite token is invalid or expired.',
      );
    }

    final String localUserId = _localProfileUserId!;
    final String localName = _localProfileName!;

    GroupMember? existingById;
    for (final GroupMember member in group.members) {
      if (member.id == localUserId) {
        existingById = member;
        break;
      }
    }

    if (existingById == null) {
      for (final GroupMember member in group.members) {
        final bool sameName = member.name.trim().toLowerCase() == localName.trim().toLowerCase();
        if (sameName && member.id != localUserId) {
          return const JoinLinkResult(
            success: false,
            message:
                'A different member with the same name already exists in this group. Rename your local profile and try again.',
          );
        }
      }

      final List<GroupMember> updatedMembers = List<GroupMember>.from(group.members)
        ..add(
          GroupMember(
            id: localUserId,
            name: localName,
            role: MemberRole.member,
          ),
        );
      _replaceGroup(group.copyWith(members: updatedMembers));
    }

    _activeGroupId = group.id;
    _identityByGroup[group.id] = localUserId;
    notifyListeners();

    return JoinLinkResult(
      success: true,
      message: 'Joined "${group.name}" as $localName.',
    );
  }

  void setActiveGroup(String groupId) {
    _activeGroupId = groupId;
    final ExpenseGroup? group = activeGroup;
    if (group != null && group.members.isNotEmpty) {
      String fallbackMemberId = group.members.first.id;
      if (_localProfileUserId != null) {
        for (final GroupMember member in group.members) {
          if (member.id == _localProfileUserId) {
            fallbackMemberId = member.id;
            break;
          }
        }
      }
      _identityByGroup[groupId] = fallbackMemberId;
    }
    notifyListeners();
  }

  String? deleteGroup(String groupId) {
    if (_groups.length <= 1) {
      return 'At least one group must exist.';
    }

    _groups.removeWhere((ExpenseGroup group) => group.id == groupId);
    _expensesByGroup.remove(groupId);
    _identityByGroup.remove(groupId);

    if (_activeGroupId == groupId && _groups.isNotEmpty) {
      _activeGroupId = _groups.first.id;
    }
    notifyListeners();
    return null;
  }

  String? addMember(String name) {
    final ExpenseGroup? group = activeGroup;
    if (group == null) {
      return 'Select a group first.';
    }

    return 'Manual member creation is disabled. Members must join via invite link.';
  }

  String? removeMember(String memberId) {
    final ExpenseGroup? group = activeGroup;
    if (group == null) {
      return 'Select a group first.';
    }

    GroupMember? target;
    for (final GroupMember member in group.members) {
      if (member.id == memberId) {
        target = member;
      }
    }
    if (target == null) {
      return 'Member not found.';
    }

    final bool hasReference = _isMemberUsedInGroupExpenses(group.id, memberId);
    if (hasReference) {
      return 'Cannot delete this member because they are used in expenses.';
    }

    final int adminCount = group.members.where((GroupMember m) => m.role == MemberRole.admin).length;
    if (target.role == MemberRole.admin && adminCount <= 1) {
      return 'Cannot remove the last admin.';
    }

    final List<GroupMember> updated =
        group.members.where((GroupMember member) => member.id != memberId).toList();
    _replaceGroup(group.copyWith(members: updated));

    if (_identityByGroup[group.id] == memberId && updated.isNotEmpty) {
      _identityByGroup[group.id] = updated.first.id;
    }

    notifyListeners();
    return null;
  }

  void selectIdentity(String memberId) {
    final ExpenseGroup? group = activeGroup;
    if (group == null) {
      return;
    }
    if (_localProfileUserId != null && memberId != _localProfileUserId) {
      return;
    }
    _identityByGroup[group.id] = memberId;
    notifyListeners();
  }

  String? createExpense({
    required String title,
    required double totalAmount,
    required DateTime date,
    required SplitMethod splitMethod,
    required List<ExpensePayer> payers,
    required List<String> participants,
    required List<ExpenseParticipantShare> shares,
  }) {
    final ExpenseGroup? group = activeGroup;
    final GroupMember? identity = activeIdentity;
    if (group == null) {
      return 'No active group selected.';
    }
    if (identity == null) {
      return 'Select your identity before creating an expense.';
    }

    final ExpenseItem expense = ExpenseItem(
      id: _newId('expense'),
      groupId: group.id,
      title: title,
      totalAmount: totalAmount,
      payers: payers,
      participants: participants,
      splitMethod: splitMethod,
      splitShares: shares,
      date: date,
      createdBy: identity.id,
    );

    final List<ExpenseItem> existing = List<ExpenseItem>.from(_expensesByGroup[group.id] ?? const <ExpenseItem>[])
      ..insert(0, expense);
    _expensesByGroup[group.id] = existing;
    notifyListeners();
    return null;
  }

  bool _isMemberUsedInGroupExpenses(String groupId, String memberId) {
    final List<ExpenseItem> expenses = _expensesByGroup[groupId] ?? const <ExpenseItem>[];
    for (final ExpenseItem expense in expenses) {
      if (expense.createdBy == memberId) {
        return true;
      }
      for (final ExpensePayer payer in expense.payers) {
        if (payer.memberId == memberId) {
          return true;
        }
      }
      for (final String participantId in expense.participants) {
        if (participantId == memberId) {
          return true;
        }
      }
    }
    return false;
  }

  void _replaceGroup(ExpenseGroup updatedGroup) {
    final int index = _groups.indexWhere((ExpenseGroup group) => group.id == updatedGroup.id);
    if (index >= 0) {
      _groups[index] = updatedGroup;
    }
  }

  ExpenseGroup? _groupById(String groupId) {
    for (final ExpenseGroup group in _groups) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  String _newInviteToken() {
    return _newId('invite').replaceAll('invite-', '');
  }

  String _encodeGroupSnapshot(ExpenseGroup group, String token) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'groupId': group.id,
      'groupName': group.name,
      'token': token,
      'members': group.members
          .map(
            (GroupMember member) => <String, dynamic>{
              'id': member.id,
              'name': member.name,
              'role': member.role.name,
            },
          )
          .toList(),
    };
    return base64Url.encode(utf8.encode(jsonEncode(payload)));
  }

  ExpenseGroup? _tryHydrateGroupFromSnapshot(String snapshot, String groupId, String token) {
    try {
      final String decoded = utf8.decode(base64Url.decode(snapshot));
      final Map<String, dynamic> payload = jsonDecode(decoded) as Map<String, dynamic>;

      if (payload['groupId'] != groupId || payload['token'] != token) {
        return null;
      }

      final String? groupName = payload['groupName'] as String?;
      final List<dynamic>? rawMembers = payload['members'] as List<dynamic>?;
      if (groupName == null || groupName.trim().isEmpty || rawMembers == null) {
        return null;
      }

      final List<GroupMember> members = <GroupMember>[];
      for (final dynamic raw in rawMembers) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final String? id = raw['id'] as String?;
        final String? name = raw['name'] as String?;
        final String? roleStr = raw['role'] as String?;
        if (id == null || name == null || roleStr == null) {
          continue;
        }

        MemberRole role = MemberRole.member;
        if (roleStr == MemberRole.admin.name) {
          role = MemberRole.admin;
        }
        members.add(GroupMember(id: id, name: name, role: role));
      }

      if (members.isEmpty) {
        return null;
      }

      final ExpenseGroup hydrated = ExpenseGroup(
        id: groupId,
        name: groupName,
        members: members,
      );
      _groups.add(hydrated);
      _expensesByGroup[groupId] = <ExpenseItem>[];
      _joinTokenByGroup[groupId] = token;
      return hydrated;
    } catch (_) {
      return null;
    }
  }

  String _buildWebInviteLink({
    required String groupId,
    required String token,
    required String snapshot,
  }) {
    final Uri base = Uri.base;
    final String origin = '${base.scheme}://${base.authority}';
    final List<String> nonEmptySegments =
        base.pathSegments.where((String segment) => segment.isNotEmpty).toList();
    final String appBasePath = nonEmptySegments.isEmpty ? '/' : '/${nonEmptySegments.first}/';
    return '$origin$appBasePath#/join?groupId=$groupId&token=$token&snapshot=$snapshot';
  }

  Map<String, String> _extractJoinParams(Uri uri) {
    if (uri.queryParameters.isNotEmpty) {
      return uri.queryParameters;
    }

    final String fragment = uri.fragment;
    final int questionIndex = fragment.indexOf('?');
    if (questionIndex < 0 || questionIndex == fragment.length - 1) {
      return const <String, String>{};
    }

    final String queryPart = fragment.substring(questionIndex + 1);
    return Uri(query: queryPart).queryParameters;
  }

  String _newId(String prefix) {
    _idCounter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }
}
