import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dbus/dbus.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
LauncherBadgeService get LauncherBadgeSvc => GetIt.I<LauncherBadgeService>();

/// Publishes the unread count to the Linux dock (Ubuntu Dock, Dash to Dock, KDE, Plank) through the Unity
/// `com.canonical.Unity.LauncherEntry` D-Bus API.
///
/// The dock discards a badge as soon as its sender leaves the session bus, so the connection is held open
/// for the lifetime of the app rather than opened per update. That also clears the badge when the app exits.
class LauncherBadgeService {
  static const _tag = 'LauncherBadge';
  static final _path = DBusObjectPath('/com/canonical/unity/launcherentry/bluebubbles');

  DBusClient? _client;
  int? _lastCount;

  Future<void> setCount(int count) async {
    if (count == _lastCount) return;
    try {
      _client ??= DBusClient.session();
      await _client!.emitSignal(
        path: _path,
        interface: 'com.canonical.Unity.LauncherEntry',
        name: 'Update',
        values: [
          DBusString('application://$linuxDesktopId.desktop'),
          DBusDict.stringVariant({
            'count': DBusInt64(count),
            'count-visible': DBusBoolean(count > 0),
          }),
        ],
      );
      _lastCount = count;
    } catch (e, s) {
      Logger.warn('Failed to update launcher badge', error: e, trace: s, tag: _tag);
    }
  }
}
