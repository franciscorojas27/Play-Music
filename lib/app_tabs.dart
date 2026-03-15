import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'app_library.dart';
import 'app_playlists.dart';
import 'app_player.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _tabs = [
    const HomeTab(),
    const PlaylistsTab(),
    const LibraryTab(),
  ];

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
                if (state?.sequence.isEmpty ?? true)
                  return const SizedBox.shrink();

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
                      color: const Color(0xFF2C2C2E).withValues(alpha: 0.95),
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
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hola,",
                        style: TextStyle(color: Colors.white54, fontSize: 24),
                      ),
                      const Text(
                        "Bienvenido",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (history.isNotEmpty) ...[
                        const Text(
                          "Historial reciente",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        ...history.map(
                          (song) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                CupertinoIcons.clock,
                                color: Colors.redAccent,
                              ),
                            ),
                            title: Text(
                              AppData.metadataCache[song.path]?.title ??
                                  song.path
                                      .split('/')
                                      .last
                                      .replaceAll('.mp3', ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                            ),
                            onTap: () => AppData.playSongContext(song, history),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                      const Text(
                        "Tus Listas",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 150,
                  child: AppData.playlists.isEmpty
                      ? const Center(
                          child: Text(
                            "Crea listas en la pestaña 'Listas'",
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                                width: 130,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E1E20,
                                  ).withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.music_albums_fill,
                                      color: Colors.redAccent,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      key,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                    ),
                                    Text(
                                      "$length tracks",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
