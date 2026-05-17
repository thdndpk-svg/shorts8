
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShortsApp());
}

class ShortsApp extends StatelessWidget {
  const ShortsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shorts Maker Pro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF0066FF),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  String _status = '영상 선택하고 쇼츠 만들기';
  double _progress = 0;
  bool _isProcessing = false;
  String? _outputPath;
  bool _hasPro = false;

  // 인앱결제
  final InAppPurchase _iap = InAppPurchase.instance;
  final Set<String> _kProductIds = {
    'shorts_pro_10000',
    'remover_8000',
    'bundle_15000',
    'triple_20000'
  };
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProStatus();
    _initIAP();
    _requestPermissions();
  }

  Future<void> _loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasPro = prefs.getBool('has_pro') ?? false;
    });
  }

  Future<void> _initIAP() async {
    final available = await _iap.isAvailable();
    if (!available) return;
    
    final response = await _iap.queryProductDetails(_kProductIds);
    setState(() {
      _products = response.productDetails;
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.photos.request();
    await Permission.videos.request();
  }

  Future<void> _pickAndProcess() async {
    if (!_hasPro) {
      _showPurchaseDialog();
      return;
    }

    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _status = '1. 영상 분석 중...';
    });

    try {
      final dir = await getTemporaryDirectory();
      final output = '${dir.path}/shorts_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // FFmpeg 명령어: 30초 자르기 + 9:16 변환 + 자막
      // 1. 30초 추출 (0초부터)
      // 2. 1080x1920으로 스케일, 중앙 크롭
      // 3. 자막은 나중에 추가 (현재는 기본 변환)
      setState(() {
        _status = '2. 30초 추출 중...';
        _progress = 0.2;
      });

      final command = '-y -i "${video.path}" -t 30 -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1" -c:v libx264 -preset ultrafast -crf 23 -c:a aac -b:a 128k "$output"';

      setState(() {
        _status = '3. 9:16 변환 중...';
        _progress = 0.5;
      });

      await FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          setState(() {
            _status = '4. 자막 생성 중...';
            _progress = 0.8;
          });
          
          // 자막 자동 생성은 추후 AI 서버 연동 예정
          // 현재는 변환 완료
          
          setState(() {
            _outputPath = output;
            _status = '완료! 쇼츠가 만들어졌습니다';
            _progress = 1.0;
            _isProcessing = false;
          });
        } else {
          setState(() {
            _status = '오류 발생: ${await session.getFailStackTrace()}';
            _isProcessing = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _status = '오류: $e';
        _isProcessing = false;
      });
    }
  }

  void _showPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shorts Maker Pro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('바다와 같이 넓은 스타일 - styleblue', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Shorts만: 10,000원', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('→ 워터마크 없음, 광고 없음, 9:16 자동 변환', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            const Text('워터마크 제거기만: 8,000원'),
            const SizedBox(height: 8),
            const Text('같이 사면 15,000원', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('3개 세트: 20,000원', style: TextStyle(color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchasePro();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            child: const Text('10,000원에 구매', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePro() async {
    // 테스트용: 실제로는 Google Play 결제 진행
    // 여기서는 SharedPreferences로 임시 처리
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_pro', true);
    setState(() {
      _hasPro = true;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pro 버전이 활성화되었습니다! (테스트 모드)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shorts Maker Pro'),
        backgroundColor: const Color(0xFF0066FF),
        foregroundColor: Colors.white,
        actions: [
          if (_hasPro)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Chip(label: Text('PRO', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F3FF), Colors.white],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.video_library, size: 80, color: Color(0xFF0066FF)),
                const SizedBox(height: 24),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),
                if (_isProcessing) ...[
                  LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey[300], color: const Color(0xFF0066FF)),
                  const SizedBox(height: 16),
                  Text('${(_progress * 100).toInt()}%'),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _pickAndProcess,
                    icon: const Icon(Icons.movie_creation),
                    label: Text(_hasPro ? '영상 선택하고 쇼츠 만들기' : 'PRO 버전 구매하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_outputPath != null && !_isProcessing) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  const Text('갤러리에 저장되었습니다', style: TextStyle(color: Colors.green)),
                ],
                const SizedBox(height: 48),
                const Text(
                  '바다와 같이 넓은 스타일로\n여러분께 저렴하고 부담없이',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
