# API và cấu hình kết nối

Ứng dụng sử dụng REST API Spring Boot của QTJP Learning. Địa chỉ máy chủ được truyền qua `API_BASE_URL` khi chạy hoặc build.

## Cấu hình

~~~sh
flutter run --dart-define=API_BASE_URL=https://your-api-domain.com
~~~

Với Android kết nối USB và backend tại cổng 8080:

~~~sh
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
~~~

Cần thiết lập lại chuyển tiếp cổng sau khi kết nối lại USB hoặc khởi động lại thiết bị. iOS sử dụng API HTTPS truy cập được từ thiết bị và môi trường macOS/Xcode.

Bản release yêu cầu HTTPS. Các mốc thời gian JLPT dạng `LocalDateTime` dùng `API_TIMEZONE_OFFSET`, mặc định `+07:00`; mốc có thông tin múi giờ được giữ nguyên.

## Xác thực và tài khoản

Các endpoint yêu cầu đăng nhập sử dụng `Authorization: Bearer <token>`. HTTP 401 kết thúc phiên hiện tại; HTTP 403 hiển thị thông báo quyền truy cập.

| Phương thức | Endpoint | Nội dung |
| --- | --- | --- |
| POST | `/api/users/login` | `username`, `password`, `replaceOtherSession` |
| POST | `/api/users/register` | Đăng ký tài khoản |
| POST | `/api/users/forgot-password` | Yêu cầu khôi phục mật khẩu |
| POST | `/api/users/reset-password` | Đặt lại mật khẩu bằng token |
| GET / PUT | `/api/users/me/profile` | Đọc hoặc cập nhật hồ sơ |
| PUT | `/api/users/me/password` | Đổi mật khẩu |
| POST / DELETE | `/api/users/me/avatar` | Cập nhật hoặc xóa ảnh đại diện |
| GET | `/api/users/me/sessions` | Danh sách phiên thiết bị |
| DELETE | `/api/users/me/sessions/others` | Thu hồi các phiên khác |

Ảnh đại diện dùng multipart với trường `file`, định dạng JPG/PNG, tối đa 2 MB. Đổi mật khẩu thành công yêu cầu đăng nhập lại. Trường hợp `VIP_SESSION_ACTIVE` có bước xác nhận thay thế phiên.

Tùy chọn giữ đăng nhập lưu token và địa chỉ API qua `flutter_secure_storage`. Khi mở lại ứng dụng, phiên được xác nhận bằng API hồ sơ. Dữ liệu và phản hồi được ràng buộc với phiên tài khoản hiện tại.

## Từ điển, Flashcard và ngữ pháp

| Phương thức | Endpoint | Nội dung |
| --- | --- | --- |
| GET | `/api/dictionary/search?keyword=...` | Tra từ công khai |
| POST | `/api/dictionary/ai` | `keyword` từ 1–100 ký tự, `mode`: `LOOKUP` hoặc `EXPLAIN` |
| GET | `/api/dictionary/ai/quota` | Hạn mức tra cứu AI |
| GET | `/api/flashcards/decks?level=...` | Bộ thẻ theo cấp độ |
| GET | `/api/flashcards/decks/{id}/vocabularies` | Từ vựng trong bộ thẻ |
| POST | `/api/flashcards/progress` | `vocabularyId`, `remembered` |
| GET | `/api/grammar/lessons?level=...` | Danh sách bài ngữ pháp |
| GET | `/api/grammar/lessons/{id}` | Chi tiết bài học |
| POST | `/api/grammar/analyze` | `sentence` từ 1–1.000 ký tự, `translationHint`, `context` |

Từ điển AI trả dữ liệu trong `entry`. Phân tích ngữ pháp trả `sentence`, `translation` và `grammarPoints`; mỗi mục gồm `grammar` và `contextNote`. Hạn mức sử dụng lấy từ máy chủ, bao gồm phản hồi HTTP 429.

## Luyện viết và Kyuto

| Phương thức | Endpoint | Nội dung |
| --- | --- | --- |
| GET | `/api/writing/topics?level=...` | Chủ đề luyện viết |
| POST | `/api/writing/topics/generate` | Tạo chủ đề |
| POST | `/api/writing/submit` | Nộp bài; bài sửa kèm `parentWritingId` |
| GET | `/api/writing/history` | Lịch sử bài viết |
| GET | `/api/writing/stats` | Thống kê |
| POST | `/api/assistant/chat` | `message` và tối đa 10 lượt hội thoại gần nhất |

Thao tác tạo đề, chấm bài và gửi câu hỏi được thực hiện khi người học xác nhận trên màn hình. Thời gian chờ là 120 giây cho Kyuto/tạo đề và 180 giây cho chấm bài. Khi nộp bài quá thời gian chờ, người học có thể kiểm tra lịch sử trước khi gửi lại.

Các liên kết học liệu từ Kyuto được ánh xạ đến màn hình Flutter tương ứng.

## Thi thử JLPT

| Phương thức | Endpoint | Nội dung |
| --- | --- | --- |
| GET | `/api/jlpt/exams?level=...` | Danh sách đề |
| GET | `/api/jlpt/exams/{id}` | Chi tiết đề |
| GET | `/api/jlpt/history` | Lịch sử thi |
| POST | `/api/jlpt/attempts/start` | Bắt đầu với `examId` |
| GET | `/api/jlpt/attempts/{id}` | Tiếp tục lượt thi |
| PUT | `/api/jlpt/attempts/{id}/answer` | `answerKeyId`, `selectedOption`; `null` để bỏ chọn |
| PUT | `/api/jlpt/attempts/{id}/mark` | Đánh dấu câu |
| POST | `/api/jlpt/attempts/{id}/complete-section` | Hoàn tất phần thi |
| POST | `/api/jlpt/attempts/{id}/start-next-section` | Bắt đầu phần tiếp theo |
| GET | `/api/jlpt/attempts/{id}/result` | Kết quả |

Đề số hóa được tải từ `examJsonUrl` khi có. Backend quyết định thời gian, chuyển phần và chấm điểm. Sau khi mất phản hồi bắt đầu bài, ứng dụng tải lại danh sách để tìm lượt đang làm.

## Học qua video

Toàn bộ `/api/videos/**` yêu cầu đăng nhập.

| Phương thức | Endpoint | Nội dung |
| --- | --- | --- |
| GET | `/api/videos/presets?level=...` | Video có sẵn; bỏ `level` để lấy tất cả |
| GET | `/api/videos/history` | Lịch sử học |
| GET | `/api/videos/usage` | Hạn mức sử dụng |
| GET | `/api/videos/presets/{id}` | Mở video mẫu và tải nội dung học |
| GET | `/api/videos/{id}` | Nội dung video đã phân tích |
| POST | `/api/videos/analyze` | Phân tích liên kết `url` |
| POST | `/api/videos/{id}/reanalyze` | Phân tích lại, dành cho ADMIN |
| POST | `/api/videos/subtitles/{id}/grammar` | Giải thích ngữ pháp của câu |

Danh sách mặc định hiển thị tất cả cấp độ. Người học có thể xem trước video, sau đó chọn tải phụ đề và phân tích. Trình phát dùng embed chính thức của YouTube/TikTok; phụ đề, bản dịch và nội dung học hiển thị bằng Flutter.

Thời gian chờ phân tích video là 180 giây, giải thích ngữ pháp là 120 giây. Sau yêu cầu quá thời gian chờ, ứng dụng yêu cầu kiểm tra lịch sử trước khi tạo tiếp. Khả năng phát phụ thuộc quyền nhúng, khu vực và trạng thái video của nhà cung cấp.

## VIP và VNPAY

| Phương thức | Endpoint | Nội dung |
| --- | --- | --- |
| POST | `/api/payments/vnpay/create` | `months`: 1, 3, 6 hoặc 12 |
| GET | `/api/payments/vnpay/history` | Lịch sử giao dịch |

Luồng thanh toán: chọn gói → xác nhận tạo đơn → xem số tiền máy chủ trả về → mở VNPAY bằng trình duyệt hệ thống. URL thanh toán được kiểm tra theo tên miền, đường dẫn, mã đơn và số tiền.

Khi quay về ứng dụng, lịch sử giao dịch và hồ sơ được tải lại để cập nhật quyền VIP. VNPAY Sandbox được hiển thị là môi trường thử nghiệm. Backend xử lý chữ ký, callback/IPN và cấp quyền.

Lịch sử hiện chưa cung cấp lại `paymentUrl` để tiếp tục đơn sau khi đóng ứng dụng. API và callback thanh toán cần truy cập được từ thiết bị.

## Thông báo

- `GET /api/notifications`: danh sách thông báo.
- `PATCH /api/notifications/{id}/read`: đánh dấu đã đọc.
- `PATCH /api/notifications/read-all`: đánh dấu tất cả.

Trạng thái đọc được cập nhật sau khi máy chủ xác nhận. Liên kết thông báo mở các màn hình được hỗ trợ trong ứng dụng.

## Kiểm thử tích hợp

~~~sh
flutter analyze
flutter test
~~~

Kiểm thử tự động sử dụng transport giả lập và HTTP server loopback cho multipart. Các kiểm tra trên thiết bị gồm phát video/âm thanh, chọn ảnh, giữ phiên khi đóng/mở ứng dụng và thanh toán Sandbox. iOS cần kiểm tra riêng với Keychain, quyền thư viện ảnh và API HTTPS.
