// --- PANTALLA CARGA (SPLASH/LOADING) ---
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_core.dart';
import 'app_tabs.dart';
import 'package:permission_handler/permission_handler.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  String status = "Iniciando Play Music...";

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    setState(() => status = "Cargando configuración...");
    await AppData.initPrefs();

    setState(() => status = "Solicitando permisos...");
    bool perm = await _requestPermissions();
    if (!perm) {
      setState(() => status = "Permisos denegados. Reinicia la app.");
      return;
    }

    setState(() => status = "Buscando canciones...");
    await _scanFiles();

    setState(() => status = "¡Listo!");
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.request().isGranted ||
          await Permission.storage.request().isGranted) {
        return true;
      }
      return false;
    }
    return true; // iOS u otros
  }

  Future<void> _scanFiles() async {
    try {
      final dir = Directory('/storage/emulated/0/');
      if (!dir.existsSync()) return;

      final entities = dir.listSync(recursive: true, followLinks: false);
      final Set<String> paths = {};
      final List<File> validSongs = [];

      for (var f in entities) {
        if (f is File && f.path.toLowerCase().endsWith('.mp3')) {
          final p = f.path.toLowerCase();

          // Excepciones (como pidió el usuario: WhatsApp y Ringtones)
          if (p.contains('whatsapp') ||
              p.contains('ringtone') ||
              p.contains('notification') ||
              p.contains('alarms') ||
              p.contains('android/data')) {
            continue;
          }

          if (!paths.contains(p)) {
            paths.add(p);
            validSongs.add(f);
          }
        }
      }

      validSongs.sort(
        (a, b) => a.path.split('/').last.compareTo(b.path.split('/').last),
      );
      AppData.allSongs = validSongs;
    } catch (e) {
      debugPrint("Error scan: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.5),
                    blurRadius: 40,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.play_circle_fill,
                size: 100,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(
              status,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
