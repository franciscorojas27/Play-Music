import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'app_core.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

enum LibMode { songs, albums, artists, genres }

class _LibraryTabState extends State<LibraryTab> {
  final TextEditingController _searchController = TextEditingController();
  List<File> _filteredSongs = [];
  LibMode _mode = LibMode.songs;

  // Para la navegación anidada de categorías
  String? _selectedCategory;
  List<File> _categorySongs = [];

  @override
  void initState() {
    super.initState();
    _filteredSongs = List.from(AppData.allSongs);
    _searchController.addListener(_filter);
    AppData.uiNotifier.addListener(_onAppDataChanged);
  }

  void _onAppDataChanged() {
    if (mounted) {
      _filter(); // re-filtrar en caso de eliminación de canciones
    }
  }

  void _filter() {
    final qc = _searchController.text.toLowerCase();
    setState(() {
      _filteredSongs = AppData.allSongs
          .where(
            (f) =>
                f.path.toLowerCase().contains(qc) ||
                (AppData.metadataCache[f.path]?.title.toLowerCase().contains(
                      qc,
                    ) ??
                    false) ||
                (AppData.metadataCache[f.path]?.artist?.toLowerCase().contains(
                      qc,
                    ) ??
                    false),
          )
          .toList();

      if (_selectedCategory != null) {
        _categorySongs = _filteredSongs.where((f) {
          final meta = AppData.metadataCache[f.path];
          if (_mode == LibMode.albums) return meta?.album == _selectedCategory;
          if (_mode == LibMode.artists) {
            return meta?.artist == _selectedCategory;
          }
          if (_mode == LibMode.genres) return meta?.genre == _selectedCategory;
          return false;
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    AppData.uiNotifier.removeListener(_onAppDataChanged);
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...AppData.playlists.keys.map(
                    (pName) => ListTile(
                      title: Text(
                        pName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        AppData.addSongToPlaylist(pName, file.path);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Añadida a $pName",
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  TextField(
                    controller: ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Nueva lista...",
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (ctrl.text.isNotEmpty) {
                        AppData.createPlaylist(ctrl.text.trim());
                        AppData.addSongToPlaylist(ctrl.text.trim(), file.path);
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text(
                      "Crear y Añadir",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(File song) {
    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          title: const Text(
            "Precaución",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "¿Estás seguro de eliminar '${song.path.split('/').last}' permanentemente de tu dispositivo? Esta acción no se puede deshacer.",
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(c);
                if (AppData.player.playing) {
                  if (AppData.currentQueue.isNotEmpty &&
                      song.path ==
                          AppData
                              .currentQueue[AppData.player.currentIndex ?? 0]
                              .path) {
                    await AppData.player.pause();
                  }
                }
                await AppData.deleteSongPermanently(song);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Canción eliminada del dispositivo",
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text(
                "ELIMINAR",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListHeader() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _filterChip(LibMode.songs, "Canciones"),
          const SizedBox(width: 10),
          _filterChip(LibMode.albums, "Álbumes"),
          const SizedBox(width: 10),
          _filterChip(LibMode.artists, "Artistas"),
          const SizedBox(width: 10),
          _filterChip(LibMode.genres, "Géneros"),
        ],
      ),
    );
  }

  Widget _filterChip(LibMode mode, String label) {
    bool selected = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mode = mode;
          _selectedCategory = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.redAccent
              : Colors.white.withAlpha((0.1 * 255).toInt()),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- RENDERS ---

  Widget _buildSongsList(List<File> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Text(
          "No hay resultados",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 10),
      itemExtent: 80,
      itemCount: songs.length,
      itemBuilder: (c, i) {
        final f = songs[i];
        final meta = AppData.metadataCache[f.path];
        final nombre =
            meta?.title ?? f.path.split('/').last.replaceAll('.mp3', '');
        final subtitulo = meta?.artist ?? "Audio MP3";

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.08 * 255).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: meta != null
                ? QueryArtworkWidget(
                    id: meta.id,
                    type: ArtworkType.AUDIO,
                    keepOldArtwork: true,
                    nullArtworkWidget: Icon(
                      CupertinoIcons.music_note,
                      color: Colors.white.withAlpha((0.5 * 255).toInt()),
                      size: 20,
                    ),
                  )
                : Icon(
                    CupertinoIcons.music_note,
                    color: Colors.white.withAlpha((0.5 * 255).toInt()),
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
            subtitulo,
            style: TextStyle(
              color: Colors.white.withAlpha((0.4 * 255).toInt()),
              fontSize: 12,
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              CupertinoIcons.ellipsis_vertical,
              color: Colors.white.withAlpha((0.5 * 255).toInt()),
            ),
            color: const Color(0xFF2A2A30),
            onSelected: (val) {
              if (val == 'next') {
                AppData.playNext(f);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Se reproducirá a continuación"),
                    backgroundColor: Colors.blueAccent,
                  ),
                );
              }
              if (val == 'add') _addToPlaylist(f);
              if (val == 'del') _showDeleteConfirmDialog(f);
              if (val == 'queue') {
                AppData.addToQueue(f);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Añadida a la cola",
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.blueAccent,
                  ),
                );
              }
            },
            itemBuilder: (c) => [
              const PopupMenuItem(
                value: 'next',
                child: Text(
                  'Reprod. a continuación',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'queue',
                child: Text(
                  'Añadir a la cola',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'add',
                child: Text(
                  'Añadir a Playlist',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'del',
                child: Text(
                  'Eliminar del dispositivo',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
          onTap: () {
            FocusScope.of(context).unfocus();
            AppData.playSongContext(f, songs);
          },
        );
      },
    );
  }

  Widget _buildCategoryGroup(LibMode m) {
    if (_selectedCategory != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextButton.icon(
              icon: const Icon(CupertinoIcons.back, color: Colors.redAccent),
              label: Text(
                _selectedCategory!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => setState(() => _selectedCategory = null),
            ),
          ),
          Expanded(child: _buildSongsList(_categorySongs)),
        ],
      );
    }

    Map<String, int> counts = {};
    for (var f in _filteredSongs) {
      final meta = AppData.metadataCache[f.path];
      String key = "Desconocido";
      if (m == LibMode.albums) key = meta?.album ?? "Sin Álbum";
      if (m == LibMode.artists) key = meta?.artist ?? "Artista Desconocido";
      if (m == LibMode.genres) key = meta?.genre ?? "Género Desconocido";

      counts[key] = (counts[key] ?? 0) + 1;
    }

    final keys = counts.keys.toList()..sort();
    if (keys.isEmpty) {
      return const Center(
        child: Text("No hay datos", style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 10),
      itemCount: keys.length,
      itemBuilder: (c, i) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
            child: const Icon(
              CupertinoIcons.folder_fill,
              color: Colors.redAccent,
            ),
          ),
          title: Text(
            keys[i],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "${counts[keys[i]]} canciones",
            style: const TextStyle(color: Colors.white54),
          ),
          trailing: const Icon(
            CupertinoIcons.chevron_right,
            color: Colors.white54,
          ),
          onTap: () {
            setState(() {
              _selectedCategory = keys[i];
              _filter();
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        title: const Text(
          "Toda tu música",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Buscar...",
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
          _buildListHeader(),
          const SizedBox(height: 10),
          Expanded(
            child: _mode == LibMode.songs
                ? _buildSongsList(_filteredSongs)
                : _buildCategoryGroup(_mode),
          ),
        ],
      ),
    );
  }
}
