import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../domain/entities/activity_log.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../features/collaboration/data/collaboration_transport.dart';

class JoinLinkResult {
  const JoinLinkResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class GroupComment {
  const GroupComment({
    required this.id,
    required this.expenseId,
    required this.authorMemberId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String expenseId;
  final String authorMemberId;
  final String message;
  final DateTime createdAt;
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
  static const String _appStateKey = 'app.state.v1';

  final List<ExpenseGroup> _groups = <ExpenseGroup>[];
  final Map<String, List<ExpenseItem>> _expensesByGroup = <String, List<ExpenseItem>>{};
  final Map<String, List<GroupComment>> _commentsByGroup = <String, List<GroupComment>>{};
  final Map<String, List<ActivityLog>> _activitiesByGroup = <String, List<ActivityLog>>{};
  final Map<String, String> _identityByGroup = <String, String>{};
  final Map<String, String> _joinTokenByGroup = <String, String>{};
  final CollaborationTransport _collaborationTransport = createCollaborationTransport();
  int _idCounter = 0;

  String? _activeGroupId;
  bool _isInitialized = false;
  String? _localProfileUserId;
  String? _localProfileName;
  String? _localCurrencyCode;
  bool _collaborationReady = false;
  bool _isHostingSession = false;
  bool _isConnectingToHost = false;
  bool get isConnectingToHost => _isConnectingToHost;

  bool _isApplyingRemoteSync = false;
  String? _localPeerId;
  String? _connectedHostPeerId;
  String? _pendingInviteGroupId;
  String? _collaborationError;
  final Set<String> _connectedPeerIds = <String>{};
  final Map<String, String> _collaboratorNames = <String, String>{};

  bool get isInitialized => _isInitialized;
  bool get hasLocalProfile => _localProfileName != null && _localProfileUserId != null;
  String? get localProfileName => _localProfileName;
  String? get localProfileUserId => _localProfileUserId;
  String get localCurrencyCode => _localCurrencyCode ?? 'INR';
  bool get collaborationReady => _collaborationReady;
  bool get isHostingSession => _isHostingSession;
  String? get localPeerId => _localPeerId;
  String? get connectedHostPeerId => _connectedHostPeerId;
  String? get collaborationError => _collaborationError;
  List<String> get connectedPeerIds => _connectedPeerIds.toList(growable: false);
  int get connectedPeerCount => _connectedPeerIds.length;
  Map<String, String> get collaboratorNames => Map<String, String>.unmodifiable(_collaboratorNames);

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
    _loadPersistedAppState(prefs.getString(_appStateKey));

    if (_activeGroupId != null && _groupById(_activeGroupId!) == null) {
      _activeGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    }

    _wireCollaborationCallbacks();

    if (kIsWeb) {
      try {
        await _ensureCollaborationReady();
        _isHostingSession = true;
        _connectedHostPeerId = null;
      } catch (e) {
        _collaborationError = 'Peer initialization failed: $e';
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<String?> startCollaborationHost() async {
    if (!hasLocalProfile) {
      return 'Complete local profile setup first.';
    }
    await _ensureCollaborationReady();
    _isHostingSession = true;
    _connectedHostPeerId = null;
    _collaborationError = null;
    notifyListeners();
    return null;
  }

  Future<String?> joinCollaborationHost(String hostPeerId) async {
    if (!hasLocalProfile) {
      return 'Complete local profile setup first.';
    }
    final String trimmed = hostPeerId.trim();
    if (trimmed.isEmpty) {
      return 'Host peer id is required.';
    }

    await _ensureCollaborationReady();
    _isHostingSession = false;
    _connectedHostPeerId = trimmed;
    _collaborationError = null;
    notifyListeners();

    try {
      _isConnectingToHost = true;
      notifyListeners();
      await _collaborationTransport.connect(trimmed);
      return null;
    } catch (e) {
      _collaborationError = e.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
      return _collaborationError;
    } finally {
      _isConnectingToHost = false;
      notifyListeners();
    }
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

    // Sweep all existing groups and update this user's name
    if (_localProfileName != null && _localProfileName != trimmedName) {
      for (int i = 0; i < _groups.length; i++) {
        final ExpenseGroup oldGroup = _groups[i];
        final List<GroupMember> updatedMembers = oldGroup.members.map((GroupMember m) {
          if (m.id == _localProfileUserId) {
            return m.copyWith(name: trimmedName);
          }
          return m;
        }).toList();
        _groups[i] = oldGroup.copyWith(members: updatedMembers);

        _logActivity(
          groupId: oldGroup.id,
          memberId: _localProfileUserId!,
          action: ActivityAction.memberNameChanged,
          description: 'Changed their name from $_localProfileName to $trimmedName',
          skipBroadcasting: true,
        );
      }
    }

    _localProfileName = trimmedName;
    _localCurrencyCode = normalizedCurrency;

    await prefs.setString(_profileUserIdKey, _localProfileUserId!);
    await prefs.setString(_profileNameKey, _localProfileName!);
    await prefs.setString(_profileCurrencyKey, _localCurrencyCode!);

    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
    
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

  List<ActivityLog> get activeGroupActivities {
    if (_activeGroupId == null) {
      return const <ActivityLog>[];
    }
    return List<ActivityLog>.unmodifiable(_activitiesByGroup[_activeGroupId!] ?? const <ActivityLog>[]);
  }

  Map<String, double> get activeGroupBalances {
    if (_activeGroupId == null) return <String, double>{};
    return getBalancesForGroup(_activeGroupId!);
  }

  Map<String, double> getBalancesForGroup(String groupId) {
    final Map<String, double> balances = <String, double>{};
    final ExpenseGroup? group = _groupById(groupId);
    if (group == null) return balances;

    for (final GroupMember member in group.members) {
      balances[member.id] = 0.0;
    }

    final List<ExpenseItem> expenses = _expensesByGroup[groupId] ?? const <ExpenseItem>[];
    for (final ExpenseItem expense in expenses) {
      for (final ExpensePayer payer in expense.payers) {
        balances[payer.memberId] = (balances[payer.memberId] ?? 0.0) + payer.amount;
      }

      for (final ExpenseParticipantShare share in expense.splitShares) {
        double actualOwed = share.value;
        if (expense.splitMethod == SplitMethod.percentage) {
          actualOwed = (share.value / 100.0) * expense.totalAmount;
        }
        balances[share.memberId] = (balances[share.memberId] ?? 0.0) - actualOwed;
      }
    }

    return balances;
  }

  double getUserBalanceForGroup(String groupId) {
    final String? localIdentityId = _identityByGroup[groupId];
    if (localIdentityId == null) return 0.0;

    final Map<String, double> balances = getBalancesForGroup(groupId);
    return balances[localIdentityId] ?? 0.0;
  }

  double get userTotalBalance {
    double total = 0.0;
    for (final ExpenseGroup group in _groups) {
      total += getUserBalanceForGroup(group.id);
    }
    return total;
  }

  List<GroupComment> groupCommentsForExpense(String expenseId) {
    final String? groupId = _activeGroupId;
    if (groupId == null) {
      return const <GroupComment>[];
    }
    return List<GroupComment>.unmodifiable(
      (_commentsByGroup[groupId] ?? const <GroupComment>[])
          .where((GroupComment c) => c.expenseId == expenseId),
    );
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
    _commentsByGroup[groupId] = <GroupComment>[];
    _joinTokenByGroup[groupId] = _newInviteToken();

    _logActivity(
      groupId: groupId,
      memberId: adminId,
      action: ActivityAction.groupCreated,
      description: 'Created the group "$trimmedGroup"',
      skipBroadcasting: true,
    );

    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
    notifyListeners();
    return null;
  }

  String? buildInviteLinkForActiveGroup() {
    final ExpenseGroup? group = activeGroup;
    if (group == null) {
      return null;
    }

    final String? hostPeerId = (_isHostingSession && _localPeerId != null) ? _localPeerId : null;
    if (hostPeerId == null) {
      return null;
    }

    if (kIsWeb) {
      return _buildWebInviteLink(
        groupId: group.id,
        hostPeerId: hostPeerId,
      );
    }

    final Uri nativeUri = Uri(
      scheme: 'splitease',
      host: 'join',
      queryParameters: <String, String>{
        'groupId': group.id,
        'hostPeerId': hostPeerId,
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
        (uri.scheme == 'splitease' && uri.host == 'join') ||
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
    final String? hostPeerId = params['hostPeerId'];
    final String? snapshot = params['snapshot'];
    final String? token = params['token'];

    if (hostPeerId != null && hostPeerId.trim().isNotEmpty) {
      _pendingInviteGroupId = (groupId != null && groupId.isNotEmpty) ? groupId : null;
      _joinHostFromInviteLink(hostPeerId.trim());
      return const JoinLinkResult(
        success: true,
        message: 'Invite opened. Connecting to host and requesting group sync...',
      );
    }

    if (groupId == null || groupId.isEmpty || token == null || token.isEmpty || snapshot == null) {
      return const JoinLinkResult(
        success: false,
        message: 'Invite link is missing host peer details. Ask host to send a fresh link.',
      );
    }

    final ExpenseGroup? synced = _tryHydrateGroupFromSnapshot(
      snapshot,
      groupId,
      token,
      upsertExisting: true,
    );
    if (synced == null) {
      return const JoinLinkResult(
        success: false,
        message: 'Could not restore group from this legacy link. Ask host for a fresh link.',
      );
    }

    _activeGroupId = synced.id;
    if (_localProfileUserId != null) {
      _identityByGroup[synced.id] = _localProfileUserId!;
    }
    _persistAppState();
    notifyListeners();
    return JoinLinkResult(success: true, message: 'Joined "${synced.name}" from legacy snapshot link.');
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
    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
    notifyListeners();
  }

  String? deleteGroup(String groupId) {
    final ExpenseGroup? group = _groupById(groupId);
    if (group == null) return 'Group not found.';

    // Only the admin can delete the group
    if (_localProfileUserId != null) {
      final GroupMember? me = group.members.where((GroupMember m) => m.id == _localProfileUserId).firstOrNull;
      if (me == null || me.role != MemberRole.admin) {
        return 'Only the group admin can delete this group.';
      }
    }

    _groups.removeWhere((ExpenseGroup g) => g.id == groupId);
    _expensesByGroup.remove(groupId);
    _commentsByGroup.remove(groupId);
    _activitiesByGroup.remove(groupId);
    _identityByGroup.remove(groupId);
    _joinTokenByGroup.remove(groupId);

    if (_activeGroupId == groupId) {
      _activeGroupId = _groups.isNotEmpty ? _groups.first.id : null;
    }
    _persistAppState();
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

    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
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
    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
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

    _logActivity(
      groupId: group.id,
      memberId: identity.id,
      action: ActivityAction.expenseAdded,
      description: 'Added expense "${expense.title}" for ${expense.totalAmount.toStringAsFixed(2)}',
    );

    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
    notifyListeners();
    return null;
  }

  String? updateExpense({
    required String id,
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
      return 'Select your identity before editing an expense.';
    }

    final List<ExpenseItem> existing = List<ExpenseItem>.from(_expensesByGroup[group.id] ?? const <ExpenseItem>[]);
    final int index = existing.indexWhere((ExpenseItem e) => e.id == id);
    
    if (index == -1) {
      return 'Expense not found.';
    }
    
    // Preserve the original creator
    final String originalCreatorId = existing[index].createdBy;

    final ExpenseItem updatedExpense = ExpenseItem(
      id: id,
      groupId: group.id,
      title: title,
      totalAmount: totalAmount,
      payers: payers,
      participants: participants,
      splitMethod: splitMethod,
      splitShares: shares,
      date: date,
      createdBy: originalCreatorId,
    );

    existing[index] = updatedExpense;
    _expensesByGroup[group.id] = existing;
    
    _logActivity(
      groupId: group.id,
      memberId: identity.id,
      action: ActivityAction.expenseUpdated,
      description: 'Updated expense "${updatedExpense.title}" to ${updatedExpense.totalAmount.toStringAsFixed(2)}',
    );

    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
    notifyListeners();
    return null;
  }

  String? addComment({required String expenseId, required String message}) {
    final ExpenseGroup? group = activeGroup;
    final GroupMember? identity = activeIdentity;
    if (group == null) {
      return 'No active group selected.';
    }
    if (identity == null) {
      return 'Select your identity before posting a comment.';
    }

    final String trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Comment cannot be empty.';
    }

    final GroupComment comment = GroupComment(
      id: _newId('comment'),
      expenseId: expenseId,
      authorMemberId: identity.id,
      message: trimmed,
      createdAt: DateTime.now(),
    );

    final List<GroupComment> existing = List<GroupComment>.from(
      _commentsByGroup[group.id] ?? const <GroupComment>[],
    )..insert(0, comment);
    _commentsByGroup[group.id] = existing;

    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
    notifyListeners();
    return null;
  }

  void _logActivity({
    required String groupId,
    required String memberId,
    required ActivityAction action,
    required String description,
    bool skipBroadcasting = false,
  }) {
    final ActivityLog log = ActivityLog(
      id: _newId('activity'),
      groupId: groupId,
      memberId: memberId,
      action: action,
      timestamp: DateTime.now(),
      description: description,
    );
    final List<ActivityLog> existing = List<ActivityLog>.from(_activitiesByGroup[groupId] ?? const <ActivityLog>[]);
    existing.insert(0, log);
    _activitiesByGroup[groupId] = existing;
    if (!skipBroadcasting && !_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
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
    final List<ExpenseItem> expenses = _expensesByGroup[group.id] ?? const <ExpenseItem>[];
    final List<GroupComment> comments = _commentsByGroup[group.id] ?? const <GroupComment>[];
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
      'expenses': expenses.map(_expenseToJson).toList(),
      'comments': comments.map(_commentToJson).toList(),
      'activities': (_activitiesByGroup[group.id] ?? const <ActivityLog>[]).map((ActivityLog a) => a.toJson()).toList(),
    };
    return base64Url.encode(utf8.encode(jsonEncode(payload)));
  }

  ExpenseGroup? _tryHydrateGroupFromSnapshot(
    String snapshot,
    String groupId,
    String token, {
    bool upsertExisting = false,
  }) {
    try {
      final String decoded = utf8.decode(base64Url.decode(snapshot));
      final Map<String, dynamic> payload = jsonDecode(decoded) as Map<String, dynamic>;

      if (payload['groupId'] != groupId || payload['token'] != token) {
        return null;
      }

      final String? groupName = payload['groupName'] as String?;
      final List<dynamic>? rawMembers = payload['members'] as List<dynamic>?;
      final List<dynamic> rawExpenses = payload['expenses'] as List<dynamic>? ?? const <dynamic>[];
      final List<dynamic> rawComments = payload['comments'] as List<dynamic>? ?? const <dynamic>[];
      final List<dynamic> rawActivities = payload['activities'] as List<dynamic>? ?? const <dynamic>[];
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

      final List<ExpenseItem> expenses = <ExpenseItem>[];
      for (final dynamic raw in rawExpenses) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final ExpenseItem? item = _expenseFromJson(raw);
        if (item != null) {
          expenses.add(item);
        }
      }

      final List<GroupComment> comments = <GroupComment>[];
      for (final dynamic raw in rawComments) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final GroupComment? item = _commentFromJson(raw);
        if (item != null) {
          comments.add(item);
        }
      }

      final ExpenseGroup hydrated = ExpenseGroup(
        id: groupId,
        name: groupName,
        members: members,
      );

      final ExpenseGroup? existing = _groupById(groupId);
      if (existing == null) {
        _groups.add(hydrated);
      } else if (upsertExisting) {
        _replaceGroup(hydrated);
      }

      if (existing == null || upsertExisting) {
        // Merge expenses: keep local ones + add any new ones from the remote snapshot
        // This prevents the host's richer list from being overwritten by a stale guest snapshot
        final List<ExpenseItem> currentLocal = List<ExpenseItem>.from(_expensesByGroup[groupId] ?? const <ExpenseItem>[]);
        final Set<String> localIds = currentLocal.map((ExpenseItem e) => e.id).toSet();
        final List<ExpenseItem> incomingNew = expenses.where((ExpenseItem e) => !localIds.contains(e.id)).toList();
        // Also update existing expenses that may have been edited remotely
        final Map<String, ExpenseItem> incomingById = <String, ExpenseItem>{
          for (final ExpenseItem e in expenses) e.id: e,
        };
        final List<ExpenseItem> merged = currentLocal.map((ExpenseItem local) {
          final ExpenseItem? remote = incomingById[local.id];
          // Prefer whichever was more recently dated
          if (remote != null && remote.date.isAfter(local.date)) return remote;
          return local;
        }).toList();
        merged.addAll(incomingNew);
        // Sort descending by date
        merged.sort((ExpenseItem a, ExpenseItem b) => b.date.compareTo(a.date));
        _expensesByGroup[groupId] = merged;

        // Merge comments similarly
        final List<GroupComment> currentComments = List<GroupComment>.from(_commentsByGroup[groupId] ?? const <GroupComment>[]);
        final Set<String> localCommentIds = currentComments.map((GroupComment c) => c.id).toSet();
        final List<GroupComment> newComments = comments.where((GroupComment c) => !localCommentIds.contains(c.id)).toList();
        currentComments.addAll(newComments);
        currentComments.sort((GroupComment a, GroupComment b) => b.createdAt.compareTo(a.createdAt));
        _commentsByGroup[groupId] = currentComments;

        final List<ActivityLog> activities = <ActivityLog>[];
        for (final dynamic raw in rawActivities) {
          if (raw is! Map<String, dynamic>) continue;
          final ActivityLog? item = ActivityLog.fromJson(raw);
          if (item != null) activities.add(item);
        }
        if (activities.isNotEmpty) {
          _activitiesByGroup[groupId] = activities;
        }
      }
      _joinTokenByGroup[groupId] = token;
      _persistAppState();
      return hydrated;
    } catch (_) {
      return null;
    }
  }

  String _buildWebInviteLink({
    required String groupId,
    required String hostPeerId,
  }) {
    final Uri base = Uri.base;
    final String origin = '${base.scheme}://${base.authority}';
    final List<String> nonEmptySegments =
        base.pathSegments.where((String segment) => segment.isNotEmpty).toList();
    final String appBasePath = nonEmptySegments.isEmpty ? '/' : '/${nonEmptySegments.first}/';
    return '$origin$appBasePath#/join?groupId=$groupId&hostPeerId=$hostPeerId';
  }

  Future<void> _joinHostFromInviteLink(String hostPeerId) async {
    final String? error = await joinCollaborationHost(hostPeerId);
    if (error != null) {
      _collaborationError = error;
      notifyListeners();
    }
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

  Future<void> _ensureCollaborationReady() async {
    if (_collaborationReady) {
      return;
    }
    _localPeerId = await _collaborationTransport.initPeer();
    _collaborationReady = true;
    notifyListeners();
  }

  void _wireCollaborationCallbacks() {
    _collaborationTransport.onPeerOpen = (String peerId) {
      _localPeerId = peerId;
      _collaborationReady = true;
      notifyListeners();
    };

    _collaborationTransport.onConnectionOpen = (String peerId) {
      _connectedPeerIds.add(peerId);
      if (!_isHostingSession && _localProfileName != null) {
        _collaborationTransport.sendTo(peerId, <String, dynamic>{
          'type': 'JOIN_REQUEST',
          'name': _localProfileName,
          'groupId': _pendingInviteGroupId,
        });
      }
      _broadcastPresence();
      notifyListeners();
    };

    _collaborationTransport.onConnectionClosed = (String peerId) {
      _connectedPeerIds.remove(peerId);
      _collaboratorNames.remove(peerId);
      _broadcastPresence();
      notifyListeners();
    };

    _collaborationTransport.onError = (String error) {
      _collaborationError = error;
      notifyListeners();
    };

    _collaborationTransport.onMessage = (CollaborationMessage message) {
      _handleCollaborationMessage(message);
    };
  }

  void _handleCollaborationMessage(CollaborationMessage message) {
    final String type = (message.payload['type'] ?? '').toString();
    if (type == 'JOIN_REQUEST' && _isHostingSession) {
      final String name = (message.payload['name'] ?? '').toString().trim();
      final String? groupId = (message.payload['groupId'] ?? '').toString().trim().isEmpty
          ? null
          : (message.payload['groupId'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        _autoApproveJoinRequest(message.fromPeerId, name, groupId);
      }
      return;
    }

    if (type == 'JOIN_REJECT' && !_isHostingSession) {
      _collaborationError = (message.payload['reason'] ?? 'Join was rejected.').toString();
      notifyListeners();
      return;
    }

    if (type == 'GROUP_SYNC' || type == 'GROUP_UPDATE') {
      _applyRemoteGroupSync(message.payload);
      if (_isHostingSession && type == 'GROUP_UPDATE') {
        _broadcastActiveGroupUpdate();
      }
      return;
    }

    if (type == 'COLLABORATOR_PRESENCE') {
      final Map<String, dynamic>? namesRaw = message.payload['collaborators'] as Map<String, dynamic>?;
      if (namesRaw != null) {
        _collaboratorNames
          ..clear()
          ..addAll(namesRaw.map((String key, dynamic value) => MapEntry<String, String>(key, value.toString())));
        notifyListeners();
      }
    }
  }

  void _applyRemoteGroupSync(Map<String, dynamic> payload) {
    final String groupId = (payload['groupId'] ?? '').toString();
    final String token = (payload['token'] ?? '').toString();
    final String snapshot = (payload['snapshot'] ?? '').toString();
    final String assignedName = (payload['assignedMemberName'] ?? '').toString();

    if (groupId.isEmpty || token.isEmpty || snapshot.isEmpty) {
      return;
    }

    _isApplyingRemoteSync = true;
    try {
      final ExpenseGroup? group = _tryHydrateGroupFromSnapshot(
        snapshot,
        groupId,
        token,
        upsertExisting: true,
      );
      if (group != null) {
        _activeGroupId = group.id;

        // Re-establish identity by assigned name (for initial GROUP_SYNC)
        // or fallback to the local profile name (for subsequent GROUP_UPDATE refreshes)
        final String nameToMatch = assignedName.isNotEmpty ? assignedName : (_localProfileName ?? '');
        if (nameToMatch.isNotEmpty && _identityByGroup[group.id] == null) {
          for (final GroupMember member in group.members) {
            if (member.name.trim().toLowerCase() == nameToMatch.trim().toLowerCase()) {
              _identityByGroup[group.id] = member.id;
              break;
            }
          }
        }

        _persistAppState();
        _pendingInviteGroupId = null;
        notifyListeners();
      }
    } finally {
      _isApplyingRemoteSync = false;
    }
  }

  void _autoApproveJoinRequest(String peerId, String requestedName, String? requestedGroupId) {
    ExpenseGroup? group;
    if (requestedGroupId != null && requestedGroupId.isNotEmpty) {
      group = _groupById(requestedGroupId);
    }
    group ??= activeGroup;
    if (group == null) {
      _collaborationTransport.sendTo(peerId, <String, dynamic>{
        'type': 'JOIN_REJECT',
        'reason': 'No active group available on host.',
      });
      return;
    }

    GroupMember? existingMember;
    for (final GroupMember member in group.members) {
      if (member.name.trim().toLowerCase() == requestedName.trim().toLowerCase()) {
        existingMember = member;
        break;
      }
    }

    ExpenseGroup effectiveGroup = group;
    if (existingMember == null) {
      final GroupMember newMember = GroupMember(
        id: _newId('member'),
        name: requestedName,
        role: MemberRole.member,
      );
      final List<GroupMember> members = List<GroupMember>.from(group.members)..add(newMember);
      effectiveGroup = group.copyWith(members: members);
      _replaceGroup(effectiveGroup);
      existingMember = newMember;
      
      _logActivity(
        groupId: effectiveGroup.id,
        memberId: newMember.id,
        action: ActivityAction.memberJoined,
        description: 'Joined the group via an invite link',
        skipBroadcasting: true,
      );
      
      _persistAppState();
    }

    final String token = _joinTokenByGroup.putIfAbsent(effectiveGroup.id, _newInviteToken);
    final String snapshot = _encodeGroupSnapshot(effectiveGroup, token);
    _collaborationTransport.sendTo(peerId, <String, dynamic>{
      'type': 'GROUP_SYNC',
      'groupId': effectiveGroup.id,
      'token': token,
      'snapshot': snapshot,
      'assignedMemberName': existingMember.name,
      'hostPeerId': _localPeerId,
      'collaborators': _collaboratorNames,
    });

    _collaboratorNames[peerId] = existingMember.name;
    _broadcastActiveGroupUpdate();
    _broadcastPresence();
    notifyListeners();
  }

  void _broadcastActiveGroupUpdate() {
    if (_connectedPeerIds.isEmpty) {
      return;
    }
    final ExpenseGroup? group = activeGroup;
    if (group == null) {
      return;
    }
    final String token = _joinTokenByGroup.putIfAbsent(group.id, _newInviteToken);
    final String snapshot = _encodeGroupSnapshot(group, token);
    _collaborationTransport.broadcast(<String, dynamic>{
      'type': 'GROUP_UPDATE',
      'groupId': group.id,
      'token': token,
      'snapshot': snapshot,
    });
  }

  void _broadcastPresence() {
    if (_connectedPeerIds.isEmpty) {
      return;
    }
    _collaborationTransport.broadcast(<String, dynamic>{
      'type': 'COLLABORATOR_PRESENCE',
      'collaborators': _collaboratorNames,
      'hostPeerId': _localPeerId,
    });
  }

  void _persistAppState() {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      final Map<String, dynamic> payload = <String, dynamic>{
        'activeGroupId': _activeGroupId,
        'groups': _groups.map(_groupToJson).toList(),
        'identityByGroup': _identityByGroup,
        'joinTokenByGroup': _joinTokenByGroup,
        'expensesByGroup': _expensesByGroup.map(
          (String key, List<ExpenseItem> value) => MapEntry<String, dynamic>(
            key,
            value.map(_expenseToJson).toList(),
          ),
        ),
        'commentsByGroup': _commentsByGroup.map(
          (String key, List<GroupComment> value) => MapEntry<String, dynamic>(
            key,
            value.map(_commentToJson).toList(),
          ),
        ),
        'activitiesByGroup': _activitiesByGroup.map(
          (String key, List<ActivityLog> value) => MapEntry<String, dynamic>(
            key,
            value.map((ActivityLog a) => a.toJson()).toList(),
          ),
        ),
      };
      prefs.setString(_appStateKey, jsonEncode(payload));
    });
  }

  void _loadPersistedAppState(String? raw) {
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final Map<String, dynamic> payload = jsonDecode(raw) as Map<String, dynamic>;
      _activeGroupId = payload['activeGroupId'] as String?;

      _groups.clear();
      final List<dynamic> groupList = payload['groups'] as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic item in groupList) {
        if (item is Map<String, dynamic>) {
          final ExpenseGroup? group = _groupFromJson(item);
          if (group != null) {
            _groups.add(group);
          }
        }
      }

      _identityByGroup
        ..clear()
        ..addAll((payload['identityByGroup'] as Map<String, dynamic>? ?? const <String, dynamic>{})
            .map((String key, dynamic value) => MapEntry<String, String>(key, value.toString())));

      _joinTokenByGroup
        ..clear()
        ..addAll((payload['joinTokenByGroup'] as Map<String, dynamic>? ?? const <String, dynamic>{})
            .map((String key, dynamic value) => MapEntry<String, String>(key, value.toString())));

      _expensesByGroup.clear();
      final Map<String, dynamic> expensesMap =
          payload['expensesByGroup'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      expensesMap.forEach((String groupId, dynamic rawItems) {
        final List<ExpenseItem> items = <ExpenseItem>[];
        if (rawItems is List<dynamic>) {
          for (final dynamic rawItem in rawItems) {
            if (rawItem is Map<String, dynamic>) {
              final ExpenseItem? item = _expenseFromJson(rawItem);
              if (item != null) {
                items.add(item);
              }
            }
          }
        }
        _expensesByGroup[groupId] = items;
      });

      _commentsByGroup.clear();
      final Map<String, dynamic> commentsMap =
          payload['commentsByGroup'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      commentsMap.forEach((String groupId, dynamic rawItems) {
        final List<GroupComment> items = <GroupComment>[];
        if (rawItems is List<dynamic>) {
          for (final dynamic rawItem in rawItems) {
            if (rawItem is Map<String, dynamic>) {
              final GroupComment? item = _commentFromJson(rawItem);
              if (item != null) {
                items.add(item);
              }
            }
          }
        }
        _commentsByGroup[groupId] = items;
      });

      _activitiesByGroup.clear();
      final Map<String, dynamic> activitiesMap =
          payload['activitiesByGroup'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      activitiesMap.forEach((String groupId, dynamic rawItems) {
        final List<ActivityLog> items = <ActivityLog>[];
        if (rawItems is List<dynamic>) {
          for (final dynamic rawItem in rawItems) {
            if (rawItem is Map<String, dynamic>) {
              final ActivityLog? item = ActivityLog.fromJson(rawItem);
              if (item != null) {
                items.add(item);
              }
            }
          }
        }
        _activitiesByGroup[groupId] = items;
      });
    } catch (_) {
      _groups.clear();
      _identityByGroup.clear();
      _joinTokenByGroup.clear();
      _expensesByGroup.clear();
      _commentsByGroup.clear();
      _activitiesByGroup.clear();
      _activeGroupId = null;
    }
  }

  Map<String, dynamic> _groupToJson(ExpenseGroup group) {
    return <String, dynamic>{
      'id': group.id,
      'name': group.name,
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
  }

  ExpenseGroup? _groupFromJson(Map<String, dynamic> raw) {
    final String? id = raw['id'] as String?;
    final String? name = raw['name'] as String?;
    final List<dynamic>? memberList = raw['members'] as List<dynamic>?;
    if (id == null || name == null || memberList == null) {
      return null;
    }

    final List<GroupMember> members = <GroupMember>[];
    for (final dynamic memberRaw in memberList) {
      if (memberRaw is! Map<String, dynamic>) {
        continue;
      }
      final String? memberId = memberRaw['id'] as String?;
      final String? memberName = memberRaw['name'] as String?;
      final String? roleString = memberRaw['role'] as String?;
      if (memberId == null || memberName == null || roleString == null) {
        continue;
      }
      members.add(
        GroupMember(
          id: memberId,
          name: memberName,
          role: roleString == MemberRole.admin.name ? MemberRole.admin : MemberRole.member,
        ),
      );
    }
    if (members.isEmpty) {
      return null;
    }

    return ExpenseGroup(id: id, name: name, members: members);
  }

  Map<String, dynamic> _expenseToJson(ExpenseItem item) {
    return <String, dynamic>{
      'id': item.id,
      'groupId': item.groupId,
      'title': item.title,
      'totalAmount': item.totalAmount,
      'date': item.date.toIso8601String(),
      'createdBy': item.createdBy,
      'splitMethod': item.splitMethod.name,
      'payers': item.payers
          .map(
            (ExpensePayer payer) => <String, dynamic>{
              'memberId': payer.memberId,
              'amount': payer.amount,
            },
          )
          .toList(),
      'participants': item.participants,
      'splitShares': item.splitShares
          .map(
            (ExpenseParticipantShare share) => <String, dynamic>{
              'memberId': share.memberId,
              'value': share.value,
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> _commentToJson(GroupComment item) {
    return <String, dynamic>{
      'id': item.id,
      'expenseId': item.expenseId,
      'authorMemberId': item.authorMemberId,
      'message': item.message,
      'createdAt': item.createdAt.toIso8601String(),
    };
  }

  ExpenseItem? _expenseFromJson(Map<String, dynamic> raw) {
    final String? id = raw['id'] as String?;
    final String? groupId = raw['groupId'] as String?;
    final String? title = raw['title'] as String?;
    final num? totalAmount = raw['totalAmount'] as num?;
    final String? dateString = raw['date'] as String?;
    final String? createdBy = raw['createdBy'] as String?;
    final String? splitMethodString = raw['splitMethod'] as String?;
    final List<dynamic>? rawPayers = raw['payers'] as List<dynamic>?;
    final List<dynamic>? rawParticipants = raw['participants'] as List<dynamic>?;
    final List<dynamic>? rawShares = raw['splitShares'] as List<dynamic>?;

    if (id == null ||
        groupId == null ||
        title == null ||
        totalAmount == null ||
        dateString == null ||
        createdBy == null ||
        splitMethodString == null ||
        rawPayers == null ||
        rawParticipants == null ||
        rawShares == null) {
      return null;
    }

    final DateTime? date = DateTime.tryParse(dateString);
    if (date == null) {
      return null;
    }

    SplitMethod splitMethod = SplitMethod.equal;
    if (splitMethodString == SplitMethod.fixedAmount.name) {
      splitMethod = SplitMethod.fixedAmount;
    } else if (splitMethodString == SplitMethod.percentage.name) {
      splitMethod = SplitMethod.percentage;
    }

    final List<ExpensePayer> payers = <ExpensePayer>[];
    for (final dynamic rawPayer in rawPayers) {
      if (rawPayer is! Map<String, dynamic>) {
        continue;
      }
      final String? memberId = rawPayer['memberId'] as String?;
      final num? amount = rawPayer['amount'] as num?;
      if (memberId == null || amount == null) {
        continue;
      }
      payers.add(ExpensePayer(memberId: memberId, amount: amount.toDouble()));
    }

    final List<String> participants = rawParticipants.map((dynamic e) => e.toString()).toList();

    final List<ExpenseParticipantShare> shares = <ExpenseParticipantShare>[];
    for (final dynamic rawShare in rawShares) {
      if (rawShare is! Map<String, dynamic>) {
        continue;
      }
      final String? memberId = rawShare['memberId'] as String?;
      final num? value = rawShare['value'] as num?;
      if (memberId == null || value == null) {
        continue;
      }
      shares.add(ExpenseParticipantShare(memberId: memberId, value: value.toDouble()));
    }

    return ExpenseItem(
      id: id,
      groupId: groupId,
      title: title,
      totalAmount: totalAmount.toDouble(),
      payers: payers,
      participants: participants,
      splitMethod: splitMethod,
      splitShares: shares,
      date: date,
      createdBy: createdBy,
    );
  }

  GroupComment? _commentFromJson(Map<String, dynamic> raw) {
    final String? id = raw['id'] as String?;
    final String? expenseId = raw['expenseId'] as String?;
    final String? authorMemberId = raw['authorMemberId'] as String?;
    final String? message = raw['message'] as String?;
    final String? createdAtRaw = raw['createdAt'] as String?;
    if (id == null ||
        expenseId == null ||
        authorMemberId == null ||
        message == null ||
        createdAtRaw == null) {
      return null;
    }

    final DateTime? createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      return null;
    }

    return GroupComment(
      id: id,
      expenseId: expenseId,
      authorMemberId: authorMemberId,
      message: message,
      createdAt: createdAt,
    );
  }

  String _newId(String prefix) {
    _idCounter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }
}
