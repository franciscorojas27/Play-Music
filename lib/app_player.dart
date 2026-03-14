import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'dart:ui';
import 'app_core.dart';
import 'dart:io';

class PlayerModal extends StatefulWidget {
  final File song;
  const PlayerModal({required this.song, super.key});

  @override
  State<PlayerModal> createState() => _PlayerModalState();
}

class _PlayerModalState extends State<PlayerModal> {
  bool _showingQueue = false;

  void _toggleQueue() {
    setState(() => _showingQueue = !_showingQueue);
  }

  void _showAddToPlaylistDialog(File song) {
    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          title: const Text(
            "Añadir a lista...",
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AppData.playlists.keys.length,
              itemBuilder: (ctx, i) {
                final pName = AppData.playlists.keys.elementAt(i);
                return ListTile(
                  title: Text(
                    pName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    AppData.addSongToPlaylist(pName, song.path);
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
                );
              },
            ),
          ),
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
                Navigator.pop(c); // Cierra popup

                // Si se está reproduciendo, pasamos a la siguiente o detenemos
                if (AppData.player.playing) {
                  await AppData.player.pause();
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
                  Navigator.pop(context); // Cierra modal
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 15) Navigator.pop(context);
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161618).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25.0,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 5,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Cover / Up Next
                      Expanded(
                        child: _showingQueue
                            ? _buildQueueView()
                            : _buildCoverView(),
                      ),

                      // Player controls
                      _buildPlayerControls(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverView() {
    return StreamBuilder<SequenceState?>(
      stream: AppData.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state?.sequence.isEmpty ?? true) return const SizedBox.shrink();
        final idx = state!.currentIndex ?? 0;
        final currentFile = AppData.currentQueue[idx];

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      width: 250,
                      height: 250,
                      child: const Icon(
                        CupertinoIcons.music_mic,
                        size: 120,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        CupertinoIcons.ellipsis_vertical,
                        color: Colors.white,
                        size: 28,
                      ),
                      color: const Color(0xFF161618),
                      onSelected: (val) {
                        if (val == 'add') {
                          _showAddToPlaylistDialog(currentFile);
                        } else if (val == 'delete') {
                          _showDeleteConfirmDialog(currentFile);
                        }
                      },
                      itemBuilder: (c) => [
                        const PopupMenuItem(
                          value: 'add',
                          child: Text(
                            "Añadir a lista...",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            "Eliminar del dispositivo",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              currentFile.path.split('/').last.replaceAll('.mp3', ''),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _buildQueueView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Siguiente...",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<SequenceState?>(
            stream: AppData.player.sequenceStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final currentIndex = state?.currentIndex ?? 0;

              return ListView.builder(
                itemCount: AppData.currentQueue.length,
                itemBuilder: (c, i) {
                  final f = AppData.currentQueue[i];
                  final isCurrent = i == currentIndex;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      f.path.split('/').last.replaceAll('.mp3', ''),
                      style: TextStyle(
                        color: isCurrent ? Colors.redAccent : Colors.white,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                    ),
                    leading: isCurrent
                        ? const Icon(
                            CupertinoIcons.speaker_2_fill,
                            color: Colors.redAccent,
                          )
                        : const Icon(
                            CupertinoIcons.music_note,
                            color: Colors.white54,
                          ),
                    onTap: () {
                      AppData.player.seek(Duration.zero, index: i);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerControls() {
    return Column(
      children: [
        StreamBuilder<Duration>(
          stream: AppData.player.positionStream,
          builder: (context, snapshot) {
            final pos = snapshot.data ?? Duration.zero;
            final t = AppData.player.duration ?? Duration.zero;
            return ProgressBar(
              progress: pos,
              total: t,
              progressBarColor: Colors.redAccent,
              baseBarColor: Colors.white24,
              thumbColor: Colors.redAccent,
              timeLabelTextStyle: const TextStyle(color: Colors.white54),
              onSeek: (p) => AppData.player.seek(p),
            );
          },
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StreamBuilder<bool>(
              stream: AppData.player.shuffleModeEnabledStream,
              builder: (context, snapshot) {
                final shuffle = snapshot.data ?? false;
                return IconButton(
                  icon: Icon(
                    CupertinoIcons.shuffle,
                    color: shuffle ? Colors.redAccent : Colors.white54,
                  ),
                  onPressed: () =>
                      AppData.player.setShuffleModeEnabled(!shuffle),
                );
              },
            ),

            IconButton(
              icon: const Icon(
                CupertinoIcons.backward_fill,
                color: Colors.white,
                size: 36,
              ),
              onPressed: () => AppData.player.seekToPrevious(),
            ),

            StreamBuilder<PlayerState>(
              stream: AppData.player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final playing = state?.playing ?? false;
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: playing
                        ? AppData.player.pause
                        : AppData.player.play,
                  ),
                );
              },
            ),

            IconButton(
              icon: const Icon(
                CupertinoIcons.forward_fill,
                color: Colors.white,
                size: 36,
              ),
              onPressed: () => AppData.player.seekToNext(),
            ),

            StreamBuilder<LoopMode>(
              stream: AppData.player.loopModeStream,
              builder: (context, snapshot) {
                final loop = snapshot.data ?? LoopMode.off;
                IconData icon = CupertinoIcons.repeat;
                Color color = loop == LoopMode.off
                    ? Colors.white54
                    : Colors.redAccent;
                if (loop == LoopMode.one) icon = CupertinoIcons.repeat_1;

                return IconButton(
                  icon: Icon(icon, color: color),
                  onPressed: () {
                    if (loop == LoopMode.off) {
                      AppData.player.setLoopMode(LoopMode.all);
                    } else if (loop == LoopMode.all) {
                      AppData.player.setLoopMode(LoopMode.one);
                    } else {
                      AppData.player.setLoopMode(LoopMode.off);
                    }
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                CupertinoIcons.list_bullet,
                color: _showingQueue ? Colors.redAccent : Colors.white54,
              ),
              onPressed: _toggleQueue,
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
