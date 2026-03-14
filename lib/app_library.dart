import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'app_core.dart';

// --- TAB 2: BIBLIOTECA (Toda la música con Buscador y Menu Contextual) ---
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final TextEditingController _searchController = TextEditingController();
  List<File> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _filteredSongs = List.from(AppData.allSongs);
    _searchController.addListener(_filter);
  }

  void _filter() {
    final qc = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = AppData.allSongs
          .where((f) => f.path.toLowerCase().contains(qc))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToPlaylist(File file) {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161618),
              title: const Text(
                "Añadir a Playlist",
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Nueva Playlist...",
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.redAccent),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, color: Colors.redAccent),
                          onPressed: () {
                            if (ctrl.text.trim().isNotEmpty) {
                              AppData.createPlaylist(ctrl.text.trim());
                              AppData.addSongToPlaylist(
                                ctrl.text.trim(),
                                file.path,
                              );
                              Navigator.pop(ctx);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (AppData.playlists.isEmpty)
                      Text(
                        "No tienes listas aún.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    if (AppData.playlists.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: AppData.playlists.keys.length,
                          itemBuilder: (c, i) {
                            String pName = AppData.playlists.keys.elementAt(i);
                            return ListTile(
                              title: Text(
                                pName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              leading: const Icon(
                                CupertinoIcons.music_note_list,
                                color: Colors.white54,
                              ),
                              onTap: () {
                                AppData.addSongToPlaylist(pName, file.path);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Añadida a $pName",
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Buscar canciones...",
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 120, top: 10),
              itemExtent: 80,
              itemCount: _filteredSongs.length,
              itemBuilder: (c, i) {
                final f = _filteredSongs[i];
                final nombre = f.path.split('/').last.replaceAll('.mp3', '');
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.music_note,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    "Audio MP3",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(
                      CupertinoIcons.ellipsis_vertical,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    color: const Color(0xFF2A2A30),
                    onSelected: (val) {
                      if (val == 'add') _addToPlaylist(f);
                    },
                    itemBuilder: (c) => [
                      const PopupMenuItem(
                        value: 'add',
                        child: Text(
                          'Añadir a Playlist',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    AppData.playSongContext(f, AppData.allSongs);
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
