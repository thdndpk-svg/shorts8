
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const ShortsApp());

class ShortsApp extends StatelessWidget {
  const ShortsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shorts Maker',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String status = '영상 선택 → 자동 쇼츠 생성';
  double progress = 0;

  Future<void> pickAndMake() async {
    await [Permission.storage, Permission.videos, Permission.photos].request();
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    setState(() { status = '변환 중...'; progress = 0.2; });

    final dir = await getApplicationDocumentsDirectory();
    final outPath = "${dir.path}/shorts_${DateTime.now().millisecondsSinceEpoch}.mp4";
    final input = video.path;

    // 1. 9:16 크롭 + 30초 컷 + 자막 추가
    // scale and crop to 1080x1920, take first 30 seconds
    final cmd = "-y -i \"$input\" -t 30 -vf \"scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,drawtext=text='@shorts':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=h-100:box=1:boxcolor=black@0.5\" -c:a aac -b:a 128k -preset ultrafast $outPath";

    await FFmpegKit.execute(cmd);

    setState(() { status = '완료! 저장됨:\n$outPath'; progress = 1.0; });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('쇼츠 생성 완료!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube → Shorts')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_creation_outlined, size: 96, color: Colors.red),
            const SizedBox(height: 24),
            Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: pickAndMake,
              icon: const Icon(Icons.video_library),
              label: const Text('영상 선택하고 쇼츠 만들기'),
            ),
            const SizedBox(height: 16),
            const Text('※ 현재는 갤러리 영상 30초를 9:16으로 변환합니다.\n유튜브 링크 다운로드는 다음 버전에서 추가.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
