import 'dart:async';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/custom_group_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
CustomGroupsService get CustomGroupsSvc => GetIt.I<CustomGroupsService>();

/// Lightweight read-only reactive cache of all custom groups, used by the
/// Chat Filters sheet so it doesn't hit the DB every time it opens.
class CustomGroupsService {
  final RxList<CustomGroup> groups = <CustomGroup>[].obs;

  StreamSubscription? _eventSub;

  Future<void> init() async {
    await refresh();
    _eventSub = EventDispatcherSvc.stream.listen((event) {
      if (event.type == 'custom-groups-updated') refresh();
    });
  }

  Future<void> refresh() async {
    groups.value = await CustomGroupInterface.getAll();
    // Drop any filter selection pointing at a group that no longer exists
    // (e.g. just got deleted). ChatsSvc is guaranteed to be registered by the
    // time this runs — it initializes earlier in the startup sequence.
    if (GetIt.I.isRegistered<ChatsService>()) {
      ChatsSvc.pruneStaleCustomGroupIds();
    }
  }

  /// Ids of the custom groups each chat belongs to, keyed by chat guid.
  ///
  /// Built from [groups] (refreshed on every 'custom-groups-updated' event)
  /// rather than `Chat.customGroups` — that backlink ToMany is lazily loaded
  /// and cached per Chat instance, so it goes stale as soon as a chat is added
  /// to/removed from a group and never picks up the change.
  Map<String, Set<int>> groupIdsByChatGuid() {
    final result = <String, Set<int>>{};
    for (final group in groups) {
      for (final chat in group.chats) {
        result.putIfAbsent(chat.guid, () => <int>{}).add(group.id!);
      }
    }
    return result;
  }

  void dispose() {
    _eventSub?.cancel();
  }
}
