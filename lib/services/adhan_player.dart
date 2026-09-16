import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'local_file.dart' if (dart.library.io) 'local_file_io.dart';

class AdhanPlayer {
  AdhanPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  static const assetPath = 'assets/audio/adhan.mp3';

  Future<void> play({String? importedPath}) async {
    try {
      await _player.stop();
      if (importedPath != null &&
          importedPath.isNotEmpty &&
          localFileExists(importedPath)) {
        await _player.play(DeviceFileSource(importedPath));
        return;
      }
      if (await _assetExists()) {
        await _player.play(AssetSource('audio/adhan.mp3'));
        return;
      }
    } catch (error) {
      debugPrint('Adhan playback failed: $error');
    }
  }

  Future<void> stop() => _player.stop();

  Future<bool> hasAudio({String? importedPath}) async {
    if (importedPath != null &&
        importedPath.isNotEmpty &&
        localFileExists(importedPath)) {
      return true;
    }
    return _assetExists();
  }

  Future<bool> _assetExists() async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() => _player.dispose();
}
