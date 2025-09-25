import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:midas_mobile/config.dart';
// config.dart에서 서버 주소 가져오기 위해 import 추가
 // 실제 프로젝트명/경로에 맞게 수정

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '사진 설명 및 음성 출력',
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String _description = ''; // AI가 생성한 사진 설명 텍스트

  // TTS 인스턴스
  final FlutterTts _flutterTts = FlutterTts();

  // 여기에 본인의 Google Translate API 키 넣기
  final String translateApiKey = 'api key 넣기';

  @override
  void initState() {
    super.initState();
    _initTts(); // TTS 초기 설정
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    // speak 완료 대기 설정 (선택)
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
          _description = '사진 분석 중...';
        });

        // 서버에 사진 보내고 설명 받기
        final englishDescription = await fetchDescription(_imageFile!);

        // 받은 영어 설명을 한국어로 번역
        final koreanDescription = await translateText(englishDescription, 'ko');

        setState(() {
          _description = koreanDescription;
        });

        // 받은 한국어 설명 텍스트를 음성으로 출력
        await _speak(_description);
      }
    } catch (e) {
      setState(() {
        _description = '사진 촬영 중 오류가 발생했습니다.';
      });
      print('사진 촬영 오류: $e');
    }
  }

  Future<String> fetchDescription(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // config.dart의 imageDescriptionUrl 사용
    final uri = Uri.parse(imageDescriptionUrl);

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      );

      // 디버깅용 로그
      print('[fetchDescription] status: ${response.statusCode}');
      print('[fetchDescription] body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['description'] ?? '서버에서 description 키를 찾을 수 없습니다.';
      } else {
        return '서버 오류 발생: 상태 코드 ${response.statusCode}\n${response.body}';
      }
    } catch (e) {
      print('설명 요청 오류: $e');
      return '설명 생성 중 오류가 발생했습니다.';
    }
  }

  Future<String> translateText(String text, String targetLangCode) async {
    final url = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2?key=$translateApiKey',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'target': targetLangCode,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['data']['translations'][0]['translatedText'];
        return translatedText;
      } else {
        print('번역 API 오류 상태 코드: ${response.statusCode}');
        return text; // 번역 실패 시 원문 반환
      }
    } catch (e) {
      print('번역 요청 오류: $e');
      return text; // 번역 실패 시 원문 반환
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.stop(); // 이전 버퍼 정리
    await _flutterTts.speak(text); // 실제 읽어주기 호출
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진 촬영 및 설명')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _imageFile == null
                  ? const Text('아직 사진이 없습니다.')
                  : Image.file(_imageFile!),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _takePhoto,
                child: const Text('사진 찍기'),
              ),
              const SizedBox(height: 20),
              Text(
                _description,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
