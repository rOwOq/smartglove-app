class UserStatus {
  final bool gloveConnected;
  final DateTime timestamp;

  UserStatus({required this.gloveConnected, required this.timestamp});

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    // 필수 필드가 없으면 예외를 던짐
    if (!json.containsKey('glove_connected') || !json.containsKey('timestamp')) {
      throw FormatException("UserStatus JSON에 필수 필드가 없습니다.");
    }

    // 타임스탬프 파싱을 안전하게 처리: 잘못된 형식일 경우 현재 시간으로 처리
    DateTime parsedTimestamp;
    try {
      parsedTimestamp = DateTime.parse(json['timestamp']);
    } catch (_) {
      parsedTimestamp = DateTime.now(); // 형식이 잘못된 경우 현재 시간으로 대체
    }

    return UserStatus(
      gloveConnected: json['glove_connected'] ?? false,  // glove_connected가 없으면 false로 설정
      timestamp: parsedTimestamp,
    );
  }

  @override
  String toString() {
    return 'BLE 연결 상태: ${gloveConnected ? "🟢 연결됨" : "🔴 끊김"} (시간: $timestamp)';
  }
}
