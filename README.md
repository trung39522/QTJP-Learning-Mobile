# QTJP Learning Mobile

Ứng dụng học tiếng Nhật dành cho Android và iOS, được xây dựng bằng Flutter và Dart, kết nối với hệ thống QTJP Learning qua API Spring Boot.

## Tính năng

- **Bảng chữ cái:** Hiragana, Katakana, hướng dẫn nét viết và phát âm.
- **Từ vựng:** tra từ, ví dụ, học Flashcard và lưu tiến độ theo cấp độ JLPT.
- **Ngữ pháp:** giáo trình theo cấp độ, tra mẫu và phân tích câu.
- **Luyện viết:** chọn chủ đề, nộp bài, nhận nhận xét và xem lịch sử.
- **Trợ lý Kyuto:** giải đáp và gợi ý học liệu theo ngữ cảnh.
- **Thi thử JLPT:** làm bài, nghe, tiếp tục lượt thi và xem kết quả.
- **Học qua video:** YouTube/TikTok, phụ đề, bản dịch, từ vựng và giải thích ngữ pháp.
- **Tài khoản:** đăng ký, đăng nhập, khôi phục mật khẩu, hồ sơ và thông báo.
- **VIP:** lựa chọn gói học, thanh toán VNPAY và xem lịch sử giao dịch.

## Công nghệ

Flutter · Dart · Spring Boot REST API · JWT · Android Keystore / iOS Keychain

## Cài đặt

Yêu cầu Flutter với Dart tương thích [pubspec.yaml](./pubspec.yaml), Android SDK hoặc Xcode trên macOS và backend QTJP Learning.

~~~sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api-domain.com
~~~

Với Android kết nối USB và backend chạy tại cổng 8080 trên máy tính:

~~~sh
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
~~~

Bản release sử dụng API qua HTTPS. Việc build và chạy iOS cần macOS/Xcode.

## Kiểm thử

~~~sh
flutter analyze
flutter test
~~~

## Tài liệu

- [Tổng quan chức năng](./docs/features.md)
- [API và cấu hình kết nối](./docs/mobile-api.md)
- [Giấy phép dữ liệu nét viết Kana](./assets/alphabet/KANJIVG_LICENSE.txt)
