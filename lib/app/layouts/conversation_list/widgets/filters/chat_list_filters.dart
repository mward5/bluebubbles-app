/// Independent, combinable filter dimensions for the conversation list.
/// Each dimension is single-select within itself (e.g. "Unread" vs "All" for
/// read status), but the dimensions combine with AND semantics — e.g.
/// "Unread" + "Group Chats" shows only unread group chats.
library;

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';

enum ChatReadFilter { all, unread }

enum ChatSenderFilter { all, known, unknown }

enum ChatTypeFilter { all, group, direct }

enum ChatMuteFilter { all, muted, unmuted }

enum ChatServiceFilter { all, iMessage, other }

// Future dimension, pending Message.isServiceMessage / Message.isSpam:
// enum ChatCategoryFilter { all, twoFactor, spam, promotions, transactions }

/// Bundles the current selection for every conversation-list filter
/// dimension. Immutable — use [copyWith] to change one dimension at a time.
class ChatListFilters {
  final ChatReadFilter readFilter;
  final ChatSenderFilter senderFilter;
  final ChatTypeFilter typeFilter;
  final ChatMuteFilter muteFilter;
  final ChatServiceFilter serviceFilter;

  /// Ids of custom groups currently selected as a filter. Empty means no
  /// group filter is active; multiple ids are OR'd together within this
  /// dimension (a chat matches if it belongs to any selected group).
  final Set<int> customGroupIds;

  /// When true, shows only chats that don't belong to any custom group.
  /// Mutually exclusive with [customGroupIds] in practice — callers clear
  /// one when setting the other.
  final bool showUngroupedOnly;

  const ChatListFilters({
    this.readFilter = ChatReadFilter.all,
    this.senderFilter = ChatSenderFilter.all,
    this.typeFilter = ChatTypeFilter.all,
    this.muteFilter = ChatMuteFilter.all,
    this.serviceFilter = ChatServiceFilter.all,
    this.customGroupIds = const {},
    this.showUngroupedOnly = false,
  });

  static const _keyRead = 'read';
  static const _keySender = 'sender';
  static const _keyType = 'type';
  static const _keyMute = 'mute';
  static const _keyService = 'service';
  static const _keyCustomGroupIds = 'customGroupIds';
  static const _keyShowUngrouped = 'showUngrouped';

  /// Decodes a [Settings.savedChatFilters]-style map (dimension name -> enum
  /// name). Unknown/missing keys fall back to [ChatListFilters]'s defaults —
  /// safe to call on a map from an older app version missing newer keys.
  factory ChatListFilters.fromSettingsMap(Map<String, String> map) {
    return ChatListFilters(
      readFilter: chatReadFilterFromName(map[_keyRead] ?? ''),
      senderFilter: chatSenderFilterFromName(map[_keySender] ?? ''),
      typeFilter: chatTypeFilterFromName(map[_keyType] ?? ''),
      muteFilter: chatMuteFilterFromName(map[_keyMute] ?? ''),
      serviceFilter: chatServiceFilterFromName(map[_keyService] ?? ''),
      customGroupIds:
          (map[_keyCustomGroupIds] ?? '').split(',').where((s) => s.isNotEmpty).map(int.parse).toSet(),
      showUngroupedOnly: map[_keyShowUngrouped] == '1',
    );
  }

  /// Encodes this selection into a [Settings.savedChatFilters]-style map.
  Map<String, String> toSettingsMap() => {
        _keyRead: readFilter.name,
        _keySender: senderFilter.name,
        _keyType: typeFilter.name,
        _keyMute: muteFilter.name,
        _keyService: serviceFilter.name,
        _keyCustomGroupIds: customGroupIds.join(','),
        _keyShowUngrouped: showUngroupedOnly ? '1' : '0',
      };

  bool get hasActiveFilter =>
      readFilter != ChatReadFilter.all ||
      senderFilter != ChatSenderFilter.all ||
      typeFilter != ChatTypeFilter.all ||
      muteFilter != ChatMuteFilter.all ||
      serviceFilter != ChatServiceFilter.all ||
      customGroupIds.isNotEmpty ||
      showUngroupedOnly;

  /// Whether [chat] passes every active dimension. Shared by the conversation
  /// list and notification muting so both agree on what's filtered out.
  ///
  /// [hasUnread] is the chat's current unread state. [isKnownSender] returns
  /// whether the chat is a group or its sender has a contact; it's only called
  /// when the sender dimension is active. [groupIds] returns the ids of the
  /// custom groups [chat] belongs to; it's only called when a custom-group
  /// dimension is active.
  bool matches(
    Chat chat, {
    required bool hasUnread,
    required bool Function() isKnownSender,
    required Set<int> Function() groupIds,
  }) {
    if (readFilter == ChatReadFilter.unread && !hasUnread) return false;

    // The legacy "Filter Unknown Senders" setting already siphons unknown-sender
    // chats into their own separate list (see ChatsService.getFilteredChats and
    // Chat.shouldMuteNotification) — when it's on, it takes precedence over this
    // dimension so the two mechanisms can't fight and produce a confusing empty list.
    if (!SettingsSvc.settings.filterUnknownSenders.value && senderFilter != ChatSenderFilter.all) {
      if (isKnownSender() != (senderFilter == ChatSenderFilter.known)) return false;
    }

    if (typeFilter != ChatTypeFilter.all && chat.isGroup != (typeFilter == ChatTypeFilter.group)) return false;
    if (muteFilter != ChatMuteFilter.all && (chat.muteType != null) != (muteFilter == ChatMuteFilter.muted)) {
      return false;
    }
    if (serviceFilter != ChatServiceFilter.all && chat.isIMessage != (serviceFilter == ChatServiceFilter.iMessage)) {
      return false;
    }

    if (customGroupIds.isNotEmpty) {
      if (!groupIds().any(customGroupIds.contains)) return false;
    } else if (showUngroupedOnly) {
      if (groupIds().isNotEmpty) return false;
    }
    return true;
  }

  ChatListFilters copyWith({
    ChatReadFilter? readFilter,
    ChatSenderFilter? senderFilter,
    ChatTypeFilter? typeFilter,
    ChatMuteFilter? muteFilter,
    ChatServiceFilter? serviceFilter,
    Set<int>? customGroupIds,
    bool? showUngroupedOnly,
  }) {
    return ChatListFilters(
      readFilter: readFilter ?? this.readFilter,
      senderFilter: senderFilter ?? this.senderFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      muteFilter: muteFilter ?? this.muteFilter,
      serviceFilter: serviceFilter ?? this.serviceFilter,
      customGroupIds: customGroupIds ?? this.customGroupIds,
      showUngroupedOnly: showUngroupedOnly ?? this.showUngroupedOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatListFilters &&
      other.readFilter == readFilter &&
      other.senderFilter == senderFilter &&
      other.typeFilter == typeFilter &&
      other.muteFilter == muteFilter &&
      other.serviceFilter == serviceFilter &&
      other.showUngroupedOnly == showUngroupedOnly &&
      const SetEquality<int>().equals(other.customGroupIds, customGroupIds);

  @override
  int get hashCode => Object.hash(
        readFilter,
        senderFilter,
        typeFilter,
        muteFilter,
        serviceFilter,
        showUngroupedOnly,
        Object.hashAllUnordered(customGroupIds),
      );
}

/// Looks up an enum value by its [Enum.name], falling back to [orElse]
/// instead of throwing if the stored string doesn't match any current value
/// (e.g. after a future enum rename).
T _enumByName<T extends Enum>(List<T> values, String name, T orElse) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return orElse;
}

ChatReadFilter chatReadFilterFromName(String name) => _enumByName(ChatReadFilter.values, name, ChatReadFilter.all);

ChatSenderFilter chatSenderFilterFromName(String name) =>
    _enumByName(ChatSenderFilter.values, name, ChatSenderFilter.all);

ChatTypeFilter chatTypeFilterFromName(String name) => _enumByName(ChatTypeFilter.values, name, ChatTypeFilter.all);

ChatMuteFilter chatMuteFilterFromName(String name) => _enumByName(ChatMuteFilter.values, name, ChatMuteFilter.all);

ChatServiceFilter chatServiceFilterFromName(String name) =>
    _enumByName(ChatServiceFilter.values, name, ChatServiceFilter.all);
