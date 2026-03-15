import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'app_core.dart';
import 'app_library.dart';
import 'app_player.dart';
import 'app_playlists.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _tabs = const [HomeTab(), PlaylistsTab(), LibraryTab()];

  @override
  void initState() {
    super.initState();
    AppData.tabChangeNotifier.addListener(_onTabExternallyChanged);
  }

  @override
  void dispose() {
    AppData.tabChangeNotifier.removeListener(_onTabExternallyChanged);
    super.dispose();
  }

  void _onTabExternallyChanged() {
    setState(() {
      _currentIndex = AppData.tabChangeNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Stack(
        children: [
          _tabs[_currentIndex],
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: StreamBuilder<SequenceState?>(
              stream: AppData.player.sequenceStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                if (state?.sequence.isEmpty ?? true) {
                  return const SizedBox.shrink();
                }
                final int idx = state!.currentIndex ?? 0;
                final File currentFile = AppData.currentQueue[idx];

                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (c) => PlayerModal(song: currentFile),
                    );
                  },
                  onHorizontalDragEnd: (d) {
                    if (d.primaryVelocity != null) {
                      if (d.primaryVelocity! > 0) {
                        AppData.player.seekToPrevious();
                      } else if (d.primaryVelocity! < 0) {
                        AppData.player.seekToNext();
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(
                      bottom: 15,
                      left: 10,
                      right: 10,
                    ),
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF2C2C2E,
                      ).withAlpha((0.95 * 255).toInt()),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 10),
                        const Icon(
                          CupertinoIcons.double_music_note,
                          color: Colors.redAccent,
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            AppData.metadataCache[currentFile.path]?.title ??
                                currentFile.path
                                    .split('/')
                                    .last
                                    .replaceAll('.mp3', ''),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: AppData.player.playerStateStream,
                          builder: (context, snapshot) {
                            final pState = snapshot.data;
                            final playing = pState?.playing ?? false;
                            return Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    playing
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: playing
                                      ? AppData.player.pause
                                      : AppData.player.play,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    CupertinoIcons.forward_fill,
                                    color: Colors.white54,
                                    size: 28,
                                  ),
                                  onPressed: AppData.player.seekToNext,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF161618),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (v) {
          AppData.tabChangeNotifier.value = v;
          if (v != 1) AppData.activePlaylistKey = null;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.music_albums),
            label: "Listas",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            label: "Biblioteca",
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: AppData.uiNotifier,
        builder: (context, _, _) {
          final history = AppData.getRecentHistory();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Hola",
                        style: TextStyle(color: Colors.white54, fontSize: 24),
                      ),
                      Text(
                        "Bienvenido",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _HeroCard(history: history)),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              SliverToBoxAdapter(
                child: history.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "Reproduce alguna canción para llenar tu historial personal.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : _HistorySection(history: history),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              const SliverToBoxAdapter(
                child: SectionHeader(title: "Tus listas"),
              ),
              SliverToBoxAdapter(child: _PlaylistsRow()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final List<File> history;

  const _HeroCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final File? latest = history.isNotEmpty ? history.first : null;
    final String title = latest != null
        ? AppData.metadataCache[latest.path]?.title ??
              latest.path.split('/').last.replaceAll('.mp3', '')
        : "Explora tu biblioteca";
    final String subtitle = latest != null
        ? "Continúa desde donde lo dejaste"
        : "Agrega canciones y crea listas para empezar";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.redAccent.withAlpha(220), const Color(0xFF2C2E36)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 20,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Siente el momento",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: latest == null
                      ? null
                      : () => AppData.playSongContext(latest, history),
                  child: const Text("Continuar"),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    AppData.tabChangeNotifier.value = 1;
                    AppData.activePlaylistKey = null;
                  },
                  child: const Text(
                    "Mostrar listas",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final List<File> history;

  const _HistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: "Historial reciente"),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final song = history[index];
                final meta = AppData.metadataCache[song.path];
                final title =
                    meta?.title ??
                    song.path.split('/').last.replaceAll('.mp3', '');
                final artist = meta?.artist ?? "Desconocido";

                return GestureDetector(
                  onTap: () => AppData.playSongContext(song, history),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withAlpha(40),
                          const Color(0xFF1A1A1F),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.clock,
                          color: Colors.redAccent,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          artist,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                          ),
                          onPressed: () =>
                              AppData.playSongContext(song, history),
                          child: const Text(
                            "Reproducir",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistsRow extends StatelessWidget {
  const _PlaylistsRow();

  @override
  Widget build(BuildContext context) {
    if (AppData.playlists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Text(
            "Crea listas en la pestaña 'Listas'",
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: AppData.playlists.keys.length,
        itemBuilder: (context, index) {
          final key = AppData.playlists.keys.elementAt(index);
          final length = AppData.playlists[key]?.length ?? 0;
          return GestureDetector(
            onTap: () {
              AppData.activePlaylistKey = key;
              AppData.tabChangeNotifier.value = 1;
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E20).withValues(alpha: 217),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.music_note_list,
                    color: Colors.redAccent,
                    size: 38,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$length canciones",
                    style: TextStyle(color: Colors.white.withAlpha(150)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
