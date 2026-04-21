import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../features/collaboration/data/collaboration_transport.dart';

class JoinLinkResult {
  const JoinLinkResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class PendingJoinRequest {
  const PendingJoinRequest({
    required this.peerId,
    required this.requestedName,
    this.groupId,
  });

  final String peerId;
  final String requestedName;
  final String? groupId;
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
  bool _isApplyingRemoteSync = false;
  String? _localPeerId;
  String? _connectedHostPeerId;
  String? _pendingInviteGroupId;
  String? _collaborationError;
  final Set<String> _connectedPeerIds = <String>{};
  final Map<String, String> _collaboratorNames = <String, String>{};
  final List<PendingJoinRequest> _pendingJoinRequests = <PendingJoinRequest>[];

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
  List<PendingJoinRequest> get pendingJoinRequests =>
      List<PendingJoinRequest>.unmodifiable(_pendingJoinRequests);
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
      await _collaborationTransport.connect(trimmed);
      return null;
    } catch (e) {
      _collaborationError = e.toString();
      notifyListeners();
      return 'Failed to connect to host peer.';
    }
  }

  void approveJoinRequest(String peerId) {
    if (!_isHostingSession) {
      return;
    }
    final PendingJoinRequest? request = _pendingJoinRequests
        .where((PendingJoinRequest r) => r.peerId == peerId)
        .cast<PendingJoinRequest?>()
        .firstWhere((PendingJoinRequest? r) => r != null, orElse: () => null);
    if (request == null) {
      return;
    }

    ExpenseGroup? group;
    if (request.groupId != null && request.groupId!.isNotEmpty) {
      group = _groupById(request.groupId!);
    }
    group ??= activeGroup;
    final GroupMember? identity = activeIdentity;
    if (group == null || identity == null || identity.role != MemberRole.admin) {
      _collaborationTransport.sendTo(peerId, <String, dynamic>{
        'type': 'JOIN_REJECT',
        'reason': 'Only admin host can approve joins.',
      });
      _pendingJoinRequests.removeWhere((PendingJoinRequest r) => r.peerId == peerId);
      notifyListeners();
      return;
    }

    GroupMember? existingMember;
    for (final GroupMember member in group.members) {
      if (member.name.trim().toLowerCase() == request.requestedName.trim().toLowerCase()) {
        existingMember = member;
        break;
      }
    }

    ExpenseGroup effectiveGroup = group;
    if (existingMember == null) {
      final GroupMember newMember = GroupMember(
        id: _newId('member'),
        name: request.requestedName,
        role: MemberRole.member,
      );
      final List<GroupMember> members = List<GroupMember>.from(group.members)..add(newMember);
      effectiveGroup = group.copyWith(members: members);
      _replaceGroup(effectiveGroup);
      existingMember = newMember;
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
    _pendingJoinRequests.removeWhere((PendingJoinRequest r) => r.peerId == peerId);
    _broadcastActiveGroupUpdate();
    _broadcastPresence();
    notifyListeners();
  }

  void rejectJoinRequest(String peerId, String reason) {
    _collaborationTransport.sendTo(peerId, <String, dynamic>{
      'type': 'JOIN_REJECT',
      'reason': reason,
    });
    _pendingJoinRequests.removeWhere((PendingJoinRequest r) => r.peerId == peerId);
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
      scheme: 'splitwise',
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
    if (_groups.length <= 1) {
      return 'At least one group must exist.';
    }

    _groups.removeWhere((ExpenseGroup group) => group.id == groupId);
    _expensesByGroup.remove(groupId);
    _identityByGroup.remove(groupId);

    if (_activeGroupId == groupId && _groups.isNotEmpty) {
      _activeGroupId = _groups.first.id;
    }
    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
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
    _persistAppState();
    if (!_isApplyingRemoteSync) {
      _broadcastActiveGroupUpdate();
    }
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
    final List<ExpenseItem> expenses = _expensesByGroup[group.id] ?? const <ExpenseItem>[];
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
        _expensesByGroup[groupId] = expenses;
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
      _pendingJoinRequests.removeWhere((PendingJoinRequest r) => r.peerId == peerId);
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
        _pendingJoinRequests.removeWhere((PendingJoinRequest r) => r.peerId == message.fromPeerId);
        _pendingJoinRequests.add(
          PendingJoinRequest(peerId: message.fromPeerId, requestedName: name, groupId: groupId),
        );
        notifyListeners();
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
    final ExpenseGroup? group = _tryHydrateGroupFromSnapshot(
      snapshot,
      groupId,
      token,
      upsertExisting: true,
    );
    if (group != null) {
      _activeGroupId = group.id;
      if (assignedName.isNotEmpty) {
        for (final GroupMember member in group.members) {
          if (member.name.trim().toLowerCase() == assignedName.trim().toLowerCase()) {
            _identityByGroup[group.id] = member.id;
            break;
          }
        }
      }
      _persistAppState();
      _pendingInviteGroupId = null;
      notifyListeners();
    }
    _isApplyingRemoteSync = false;
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
    } catch (_) {
      _groups.clear();
      _identityByGroup.clear();
      _joinTokenByGroup.clear();
      _expensesByGroup.clear();
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

  String _newId(String prefix) {
    _idCounter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }
}
