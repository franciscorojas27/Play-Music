import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'app_core.dart';

// --- TAB 3: PLAYLISTS ---
class PlaylistsTab extends StatefulWidget {
  const PlaylistsTab({super.key});

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab> {
  String? activePlaylist;

  @override
  void initState() {
    super.initState();
    // Reconstruir si cambia algo en las playlists (usando ValueListenableBuilder luego)
  }

  void _createNew() {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          title: const Text(
            "Nueva Playlist",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Nombre...",
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.white54),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
            TextButton(
              child: const Text(
                "Crear",
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  AppData.createPlaylist(ctrl.text.trim());
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppData.uiNotifier,
      builder: (context, _, _) {
        if (AppData.activePlaylistKey != null) {
          return PlaylistDetailView(
            playlistName: AppData.activePlaylistKey!,
            onBack: () => setState(() => AppData.activePlaylistKey = null),
          );
        } else if (activePlaylist != null) {
          return PlaylistDetailView(
            playlistName: activePlaylist!,
            onBack: () => setState(() => activePlaylist = null),
          );
        }

        final names = AppData.playlists.keys.toList();

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Mis Listas",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.add_circled_solid,
                        color: Colors.redAccent,
                        size: 32,
                      ),
                      onPressed: _createNew,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: names.isEmpty
                    ? const Center(
                        child: Text(
                          "Sin listas",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: names.length,
                        itemBuilder: (c, i) {
                          final pName = names[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            leading: Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.deepOrangeAccent.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                CupertinoIcons.music_note_list,
                                color: Colors.deepOrangeAccent,
                              ),
                            ),
                            title: Text(
                              pName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "${AppData.playlists[pName]?.length ?? 0} canciones",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                CupertinoIcons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => AppData.deletePlaylist(pName),
                            ),
                            onTap: () => setState(() => activePlaylist = pName),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Playlist Detail View ---
class PlaylistDetailView extends StatelessWidget {
  final String playlistName;
  final VoidCallback onBack;

  const PlaylistDetailView({
    required this.playlistName,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final paths = AppData.playlists[playlistName] ?? [];
    List<File> pSongs = [];
    for (var p in paths) {
      try {
        final f = AppData.allSongs.firstWhere((element) => element.path == p);
        pSongs.add(f);
      } catch (e) {
        debugPrint('Playlist: no se encontró la canción en $p');
      }
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.back, color: Colors.white),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  playlistName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  CupertinoIcons.play_circle_fill,
                  color: Colors.redAccent,
                  size: 36,
                ),
                onPressed: () {
                  if (pSongs.isNotEmpty) {
                    AppData.playSongContext(pSongs.first, pSongs);
                  }
                },
              ),
              const SizedBox(width: 10),
            ],
          ),
          Expanded(
            child: pSongs.isEmpty
                ? const Center(
                    child: Text(
                      "Vacía",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 150),
                    itemCount: pSongs.length,
                    itemBuilder: (c, i) {
                      final f = pSongs[i];
                      return ListTile(
                        title: Text(
                          AppData.metadataCache[f.path]?.title ??
                              f.path.split('/').last.replaceAll('.mp3', ''),
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                        ),
                        leading: const Icon(
                          CupertinoIcons.music_note,
                          color: Colors.white54,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            CupertinoIcons.minus_circle,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            AppData.removeSongFromPlaylist(
                              playlistName,
                              f.path,
                            );
                          },
                        ),
                        onTap: () {
                          AppData.playSongContext(f, pSongs);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
