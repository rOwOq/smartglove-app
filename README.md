# 📱 스마트 장갑 Flutter 앱

스마트 위치 전송 장갑 프로젝트의 모바일 앱입니다.
사용자(장갑 착용자)와 보호자가 동일한 앱을 사용하며, 로그인 후 역할(role)에 따라 분기됩니다.

(Node.js 서버 + MySQL + Firebase FCM 연동)

## ⚙️ 주요 기능

 - 로그인/회원가입
 - 사용자 모드
 - 장갑 BLE(MyFlexBLE) 연결 및 상태 표시
 - Flex 센서 굽힘 데이터 수신
 - 검지(F2) "CLOSED" 시 → 스마트폰 GPS 자동 전송
 - 배터리 상태 표시
 - 보호자 정보 확인
 - 보호자 모드
 - 연동된 사용자 상태(BLE 연결, 배터리) 실시간 조회
 - 사용자 위치 목록 확인
 - 지도에서 최신 위치 표시 (Google Maps API)
 - FCM 푸시 알림 수신 (이상행동/배터리 경고 등)

## 📂 프로젝트 구조
📦 midas_mobile
 ┣ 📂 lib
 ┃ ┣ 📂 providers/       # 상태 관리 (BLE, 사용자 상태 등)
 ┃ ┣ 📂 screens/         # 로그인/홈/위치/연동 UI 화면
 ┃ ┣ 📂 widgets/         # 공용 위젯
 ┃ ┗ 📜 main.dart        # 앱 진입점
 ┣ 📂 android            # Android 설정 (Google Maps API 키 포함)
 ┣ 📂 ios                # iOS 설정
 ┣ 📜 pubspec.yaml       # Flutter 패키지 관리
 ┗ 📜 README.md

##🔌 주요 패키지

flutter_blue_plus
 → BLE 연결
geolocator
 → GPS 위치 가져오기
google_maps_flutter
 → 지도 표시
firebase_messaging
 → 푸시 알림 수신
provider
 → 상태 관리

## 🌐 서버 연동

외부 도메인: https://midas.p-e.kr

API는 Node.js 서버와 동일한 REST API 사용 → 서버 README
 참고

## 🚀 실행 방법
1. 의존성 설치
flutter pub get

2. 앱 실행 (에뮬레이터/실기기)
flutter run

3. 빌드
flutter build apk   # 안드로이드
flutter build ios   # iOS

##📱 화면 구성
 - 로그인/회원가입
 - 계정 생성 및 로그인
 - role에 따라 사용자 홈 / 보호자 홈 분기
 - 사용자 홈 (User)
 - BLE 연결 상태 카드
 - 배터리 진행바
 - 보호자 정보 카드
 - 알림 테스트 버튼
 - 보호자 홈 (Guardian)
 - 사용자 리스트
 - 각 사용자 BLE 연결 상태 / 배터리 상태
 - 위치 확인 버튼 → 지도 화면 이동
 - 알림 수신 로그

## 🔔 푸시 알림 (FCM)
 - 이상행동 감지 → 보호자에게 푸시 전송
 - 배터리 부족 경고 → 보호자 알림
 - 테스트 알림 전송 가능
