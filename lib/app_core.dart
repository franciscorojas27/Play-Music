import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AppData {
  static final AudioPlayer player = AudioPlayer();
  static List<File> allSongs = [];
  static List<File> currentPlaylistQueue = [];
  static Map<String, SongModel> metadataCache = {};

  // Temporizador de apagado
  static Timer? _sleepTimer;
  static final ValueNotifier<Duration?> sleepTimerRemaining = ValueNotifier(null);

  // Playlists: Nombre -> Lista de rutas (paths)
  static Map<String, List<String>> playlists = {};
  static List<String> playHistory = [];
  static SharedPreferences? prefs;

  static void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes == 0) {
      sleepTimerRemaining.value = null;
      return;
    }
    
    DateTime endTime = DateTime.now().add(Duration(minutes: minutes));
    
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = endTime.difference(DateTime.now());
      if (remaining.isNegative) {
        player.pause();
        timer.cancel();
        sleepTimerRemaining.value = null;
      } else {
        sleepTimerRemaining.value = remaining;
      }
    });
  }

  // Notificará a la UI cuando cambien las playlists o las canciones
  static final ValueNotifier<int> uiNotifier = ValueNotifier(0);

  // Tab notifier para cambiar desde codigo
  static final ValueNotifier<int> tabChangeNotifier = ValueNotifier(0);
  static String? activePlaylistKey;

  static Future<void> initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    playHistory = prefs?.getStringList('playHistory') ?? [];

    String? pStr = prefs?.getString('playlists');
    if (pStr != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(pStr);
        playlists = decoded.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        );
      } catch (e) {
        debugPrint("Error parsing playlists: $e");
      }
    }
  }

  static Future<void> savePlaylists() async {
    await prefs?.setString('playlists', jsonEncode(playlists));
    uiNotifier.value++;
  }

  static Future<void> saveLastPlayed(String path) async {
    playHistory.remove(path);
    playHistory.insert(0, path);
    if (playHistory.length > 5) playHistory = playHistory.sublist(0, 5);
    await prefs?.setStringList('playHistory', playHistory);
    uiNotifier.value++;
  }

  static List<File> getRecentHistory() {
    List<File> result = [];
    for (String path in playHistory) {
      try {
        result.add(allSongs.firstWhere((f) => f.path == path));
      } catch (e) {
        debugPrint('Historial: no se encontró la canción en $path');
      }
    }
    return result;
  }

  static List<File> get currentQueue => currentPlaylistQueue;

  // --- CRUD Playlists ---
  static void createPlaylist(String name) {
    if (!playlists.containsKey(name)) {
      playlists[name] = [];
      savePlaylists();
    }
  }

  static void deletePlaylist(String name) {
    playlists.remove(name);
    savePlaylists();
  }

  static void addSongToPlaylist(String playlistName, String path) {
    if (playlists.containsKey(playlistName)) {
      if (!playlists[playlistName]!.contains(path)) {
        playlists[playlistName]!.add(path);
        savePlaylists();
      }
    }
  }

  static void removeSongFromPlaylist(String playlistName, String path) {
    if (playlists.containsKey(playlistName)) {
      playlists[playlistName]!.remove(path);
      savePlaylists();
    }
  }

  static Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final File item = currentPlaylistQueue.removeAt(oldIndex);
    currentPlaylistQueue.insert(newIndex, item);

    try {
      // just_audio move dynamic sequence
      final sequence = player.sequence;
      // Safe check for index bounds
      if (oldIndex < sequence.length && newIndex < sequence.length) {
        await (player.audioSource as ConcatenatingAudioSource)
            .move(oldIndex, newIndex);
      }
        } catch (e) {
      debugPrint("Error reordering queue: $e");
    }
    uiNotifier.value++;
  }

  static Future<void> playNext(File song) async {
    // Inserta la canción justo después de la actual
    final currentIndex = player.currentIndex ?? -1;
    final targetIndex = currentIndex + 1;

    currentPlaylistQueue.insert(targetIndex, song);
    try {
      final meta = metadataCache[song.path];
      final nombre =
          meta?.title ?? song.path.split('/').last.replaceAll('.mp3', '');
      final artist = meta?.artist ?? "Desconocido";
      final album = meta?.album ?? "PlayMusic";

      final source = AudioSource.uri(
        Uri.parse(song.path),
        tag: MediaItem(
          id: song.path,
          album: album,
          title: nombre,
          artist: artist,
          artUri: Uri.parse("asset:///assets/cover.png"),
        ),
      );

      if (player.audioSource is ConcatenatingAudioSource) {
        await (player.audioSource as ConcatenatingAudioSource)
            .insert(targetIndex, source);
      } else {
        await setupPlaylist(currentPlaylistQueue, initialIndex: currentIndex);
      }
    } catch (e) {
      debugPrint("Error in playNext: $e");
    }
    uiNotifier.value++;
  }

  static Future<void> addToQueue(File song) async {
    currentPlaylistQueue.add(song);
    try {
      final meta = metadataCache[song.path];
      final nombre =
          meta?.title ?? song.path.split('/').last.replaceAll('.mp3', '');
      final artist = meta?.artist ?? "Desconocido";
      final album = meta?.album ?? "PlayMusic";

      final source = AudioSource.uri(
        Uri.parse(song.path),
        tag: MediaItem(
          id: song.path,
          album: album,
          title: nombre,
          artist: artist,
          artUri: Uri.parse("asset:///assets/cover.png"),
        ),
      );

      if (player.audioSource is ConcatenatingAudioSource) {
        await (player.audioSource as ConcatenatingAudioSource).add(source);
      } else {
        // If not a concatenating source, we set up a new one with the song added
        await setupPlaylist(currentPlaylistQueue,
            initialIndex: player.currentIndex ?? 0);
      }
    } catch (e) {
      debugPrint("Error adding to queue: $e");
    }
    uiNotifier.value++;
  }

  static Future<void> deleteSongPermanently(File song) async {
    // Intentar eliminar el archivo
    try {
      if (song.existsSync()) {
        song.deleteSync();
      }
    } catch (e) {
      debugPrint('Error al eliminar archivo: $e');
      return; // Si no se pudo eliminar de disco, abortamos
    }

    // Remover de la lista global
    allSongs.removeWhere((s) => s.path == song.path);
    currentPlaylistQueue.removeWhere((s) => s.path == song.path);

    // Remover de todas las playlists
    for (var key in playlists.keys) {
      playlists[key]?.remove(song.path);
    }
    savePlaylists();

    // Remover del historial
    playHistory.remove(song.path);
    await prefs?.setStringList('playHistory', playHistory);

    // Notificar a la UI
    uiNotifier.value++;
  }

  // --- Manejo del reproductor ---
  static Future<void> setupPlaylist(
    List<File> songs, {
    int initialIndex = 0,
  }) async {
    currentPlaylistQueue = List.from(songs); // copy of the list
    try {
      final sources = songs.map((file) {
        final meta = metadataCache[file.path];
        final nombre =
            meta?.title ?? file.path.split('/').last.replaceAll('.mp3', '');
        final artist = meta?.artist ?? "Desconocido";
        final album = meta?.album ?? "PlayMusic";

        return AudioSource.uri(
          Uri.parse(file.path),
          tag: MediaItem(
            id: file.path,
            album: album,
            title: nombre,
            artist: artist,
            artUri: Uri.parse("asset:///assets/cover.png"),
          ),
        );
      }).toList();

      await player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: initialIndex,
      );
    } catch (e) {
      debugPrint("Error playlist: $e");
    }
  }

  static void playSongContext(File file, List<File> contextPlaylist) async {
    int idx = contextPlaylist.indexOf(file);
    if (idx == -1) return;
    saveLastPlayed(file.path);
    if (currentPlaylistQueue != contextPlaylist) {
      await setupPlaylist(contextPlaylist, initialIndex: idx);
      player.play();
    } else {
      await player.seek(Duration.zero, index: idx);
      player.play();
    }
  }
}
