# QTJP Learning Mobile

Ứng dụng Flutter/Dart cho Android và iOS, sử dụng chung API Spring Boot của QTJP Learning. Repository này chỉ chứa ứng dụng Mobile, không chứa backend, cơ sở dữ liệu hoặc khóa dịch vụ AI.

## Chức năng

- Bảng chữ cái Hiragana/Katakana, nét viết ngoại tuyến và phát âm.
- Từ điển, Flashcard, giáo trình ngữ pháp và tiến độ học.
- Từ điển AI, phân tích ngữ pháp, luyện viết AI và trợ lý Kyuto.
- Thi thử JLPT: tiếp tục lượt thi, các phần thi, âm thanh, kết quả và lịch sử.
- Học qua YouTube/TikTok: video có sẵn, phụ đề, từ vựng và ngữ pháp.
- Tài khoản, hồ sơ/ảnh đại diện, giữ phiên bảo mật và thông báo.
- Chọn gói VIP và thanh toán qua VNPAY bằng API hiện có; trạng thái thanh toán/quyền VIP do backend xác nhận.

## Chuẩn bị

- Flutter tương thích với phiên bản Dart khai báo trong [pubspec.yaml](./pubspec.yaml).
- Android SDK/JDK hoặc macOS/Xcode nếu phát triển iOS.
- Backend QTJP đang chạy, kết nối được MySQL; các tính năng AI/VNPAY cần cấu hình tương ứng ở backend.

```powershell
flutter pub get
flutter analyze
flutter test
```

## Chạy bản phát triển

Với Android thật kết nối USB, chuyển tiếp cổng API trước khi chạy. Nếu có nhiều thiết bị, thêm `-s <device-id>` cho adb và `-d <device-id>` cho Flutter.

```powershell
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Chạy lại `adb reverse` sau khi cắm lại USB/khởi động thiết bị. Chỉ giữ một phiên Flutter/Gradle đang chạy. Khi thêm plugin native, dừng phiên cũ và chạy lại app; Hot Reload/Hot Restart không đủ.

iPhone thật cần backend HTTPS truy cập được từ thiết bị và môi trường build macOS. Bản release yêu cầu `API_BASE_URL` dùng HTTPS; không có endpoint sản xuất mặc định.

## Bản checkpoint hiện tại

Đây là bản phát triển, chưa phải bản phát hành đã nghiệm thu trên cả Android/iOS. Phát video/âm thanh, AI và VNPAY cần được kiểm tra trên thiết bị với cấu hình backend thực tế. Không coi kết quả test giả lập là xác nhận giao dịch thật hoặc AI thật. Google OAuth native chưa được triển khai.

- [Hợp đồng API và cách kiểm tra trên thiết bị](./docs/mobile-api.md)
- [Tiến độ, giới hạn và kết quả kiểm thử](./docs/development-checkpoints.md)
- [Nguồn dữ liệu và giấy phép nét viết Kana](./assets/alphabet/KANJIVG_LICENSE.txt)

Không đưa mật khẩu, JWT, khóa Gemini/VNPAY, keystore, cấu hình máy cá nhân, build hoặc cache vào Git. `pubspec.lock` được giữ để tái lập dependency của ứng dụng.
