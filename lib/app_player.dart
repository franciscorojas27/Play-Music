import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:async';
import 'dart:ui';
import 'app_core.dart';
import 'dart:io';

class PlayerModal extends StatefulWidget {
  final File song;
  const PlayerModal({required this.song, super.key});

  @override
  State<PlayerModal> createState() => _PlayerModalState();
}

enum _SkipDirection { backward, forward }

class _PlayerModalState extends State<PlayerModal> {
  bool _showingQueue = false;
  _SkipDirection? _skipDirection;
  Timer? _skipIndicatorTimer;

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

  @override
  void dispose() {
    _skipIndicatorTimer?.cancel();
    super.dispose();
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
            color: const Color(0xFF161618).withAlpha((0.95 * 255).toInt()),
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

        const double artworkSize = 250;
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: GestureDetector(
                      onDoubleTapDown: (details) =>
                          _handleDoubleTap(details, artworkSize),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(
                            (0.1 * 255).toInt(),
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withAlpha(
                                (0.2 * 255).toInt(),
                              ),
                              blurRadius: 40,
                            ),
                          ],
                        ),
                        width: artworkSize,
                        height: artworkSize,
                        clipBehavior: Clip.antiAlias,
                        child: AppData.metadataCache[currentFile.path] != null
                            ? QueryArtworkWidget(
                                id: AppData.metadataCache[currentFile.path]!.id,
                                type: ArtworkType.AUDIO,
                                keepOldArtwork: true,
                                artworkWidth: artworkSize,
                                artworkHeight: artworkSize,
                                artworkFit: BoxFit.cover,
                                nullArtworkWidget: const Icon(
                                  CupertinoIcons.music_mic,
                                  size: 120,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.music_mic,
                                size: 120,
                                color: Colors.redAccent,
                              ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _skipDirection == null ? 0 : 1,
                        child: _buildSkipOverlay(),
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
                        } else if (val == 'create_playlist') {
                          _showCreatePlaylistFromSongDialog(currentFile);
                        } else if (val == 'timer') {
                          _showSleepTimerDialog();
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
                          value: 'create_playlist',
                          child: Text(
                            "Crear lista a partir de esta",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'timer',
                          child: Text(
                            "Temporizador de apagado",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<Duration?>(
              valueListenable: AppData.sleepTimerRemaining,
              builder: (context, remaining, child) {
                if (remaining == null) return const SizedBox.shrink();
                final mins = (remaining.inSeconds / 60).floor();
                final secs = remaining.inSeconds % 60;
                return Text(
                  "Apagado en: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              AppData.metadataCache[currentFile.path]?.title ??
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

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        title: const Text(
          "Temporizador de apagado",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                "Desactivar",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                AppData.setSleepTimer(0);
                Navigator.pop(c);
              },
            ),
            ListTile(
              title: const Text(
                "15 minutos",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                AppData.setSleepTimer(15);
                Navigator.pop(c);
              },
            ),
            ListTile(
              title: const Text(
                "30 minutos",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                AppData.setSleepTimer(30);
                Navigator.pop(c);
              },
            ),
            ListTile(
              title: const Text(
                "60 minutos",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                AppData.setSleepTimer(60);
                Navigator.pop(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistFromSongDialog(File song) {
    final TextEditingController cont = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        title: const Text("Nueva lista", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: cont,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Nombre de la lista",
            hintStyle: TextStyle(color: Colors.white24),
          ),
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
            onPressed: () {
              if (cont.text.isNotEmpty) {
                AppData.createPlaylist(cont.text);
                AppData.addSongToPlaylist(cont.text, song.path);
                Navigator.pop(c);
              }
            },
            child: const Text(
              "Crear",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
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

              return ReorderableListView.builder(
                onReorder: (oldIdx, newIdx) {
                  AppData.reorderQueue(oldIdx, newIdx);
                },
                itemCount: AppData.currentQueue.length,
                itemBuilder: (c, i) {
                  final f = AppData.currentQueue[i];
                  final isCurrent = i == currentIndex;
                  return ListTile(
                    key: ValueKey(f.path + i.toString()),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppData.metadataCache[f.path]?.title ??
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
                    trailing: const Icon(
                      CupertinoIcons.bars,
                      color: Colors.white24,
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

  void _handleDoubleTap(TapDownDetails details, double width) {
    final isForward = details.localPosition.dx > width / 2;
    final direction = isForward
        ? _SkipDirection.forward
        : _SkipDirection.backward;
    _startSkipIndicator(direction);

    final current = AppData.player.position;
    final total = AppData.player.duration ?? Duration.zero;

    if (isForward) {
      final skip = current + const Duration(seconds: 15);
      AppData.player.seek(skip > total ? total : skip);
    } else {
      final skip = current - const Duration(seconds: 5);
      AppData.player.seek(skip.isNegative ? Duration.zero : skip);
    }
  }

  void _startSkipIndicator(_SkipDirection direction) {
    _skipIndicatorTimer?.cancel();
    setState(() {
      _skipDirection = direction;
    });
    _skipIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _skipDirection = null;
      });
    });
  }

  Widget _buildSkipOverlay() {
    final direction = _skipDirection ?? _SkipDirection.forward;
    final icon = direction == _SkipDirection.forward
        ? CupertinoIcons.forward_fill
        : CupertinoIcons.backward_fill;
    final label = direction == _SkipDirection.forward
        ? "Adelantar 15s"
        : "Retroceder 5s";
    final alignment = direction == _SkipDirection.forward
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
                  width: 74,
                  height: 74,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withAlpha(150),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 40,
                    icon: Icon(
                      playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      color: Colors.white,
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
