# Kết nối dữ liệu QTJP Mobile

## Nguồn dữ liệu

- Kana và nét viết: asset ngoại tuyến sẵn có, không phụ thuộc backend.
- Từ điển: `GET /api/dictionary/search?keyword=...`, không cần đăng nhập.
- Từ điển AI: `POST /api/dictionary/ai` gửi `keyword` (1–100 ký tự) và `mode` (`LOOKUP` hoặc `EXPLAIN`); `GET /api/dictionary/ai/quota`. Cả hai yêu cầu JWT. Kết quả nằm trong `entry`, lượt còn lại lấy từ API quota/phản hồi HTTP 429, không tự tính ở client.
- Đăng nhập: `POST /api/users/login`, giữ nguyên hợp đồng website (username, password, replaceOtherSession).
- Flashcard: `GET /api/flashcards/decks?level=...`, sau đó tải `/decks/{id}/vocabularies` khi mở bộ thẻ.
- Lưu tiến độ: `POST /api/flashcards/progress` với vocabularyId và remembered. Chỉ chuyển thẻ sau khi lưu thành công.
- Ngữ pháp: `GET /api/grammar/lessons?level=...` và `/lessons/{id}`.
- Phân tích ngữ pháp AI: `POST /api/grammar/analyze` gửi `sentence` (1–1.000 ký tự), `translationHint` và `context`; phản hồi gồm `sentence`, `translation`, `grammarPoints` (mỗi mục có `grammar` và `contextNote`).
- Luyện viết: `GET /api/writing/topics?level=...`, `POST /api/writing/topics/generate`, `POST /api/writing/submit`; bài sửa gửi parentWritingId của lần nộp trước, không tự truyền userId.
- Lịch sử/thống kê viết: `GET /api/writing/history` và `/api/writing/stats`. Có thể mở một lần nộp cũ để viết lại.
- Kyuto: `POST /api/assistant/chat` với message và tối đa 10 lượt hội thoại hợp lệ gần nhất (role user/assistant, bỏ nội dung rỗng). Khóa Gemini, quota và truy xuất dữ liệu vẫn do backend quản lý.
- JLPT: `GET /api/jlpt/exams?level=...`, `/exams/{id}`, `/history`; `POST /attempts/start` gửi `examId`; tiếp tục bằng `GET /attempts/{id}`. Lưu đáp án bằng `PUT /attempts/{id}/answer` (`answerKeyId`, `selectedOption`, cho phép null để bỏ chọn); đánh dấu bằng `PUT /attempts/{id}/mark`.
- Chuyển phần JLPT: `POST /api/jlpt/attempts/{id}/complete-section` và `/start-next-section`; phần cuối do backend nộp/chấm điểm. Kết quả dùng `GET /attempts/{id}/result`. Không gửi userId hoặc đáp án đúng từ client.
- Video: `GET /api/videos/presets?level=...`, `/history`, `/usage`, `/presets/{id}` và `/{id}`. Phân tích link bằng `POST /api/videos/analyze` với `url`; phân tích lại bằng `POST /api/videos/{id}/reanalyze`; giải thích câu bằng `POST /api/videos/subtitles/{id}/grammar`.
- Toàn bộ `/api/videos/**`, kể cả danh sách mẫu, yêu cầu JWT theo SecurityConfig. Mobile mặc định lấy tất cả video giống website (không gửi `level`), có thể chọn N5–N1 để lọc. Lịch sử/quota lỗi không xóa danh sách đã tải thành công. Phân tích lại chỉ có ADMIN theo backend.
- VIP/VNPAY: `POST /api/payments/vnpay/create` chỉ gửi `months` (1, 3, 6, 12); `GET /api/payments/vnpay/history`; cả hai dùng JWT. Giá niêm yết tham khảo cùng website/backend; số tiền thanh toán cuối cùng phải lấy từ phản hồi tạo đơn.
- Tài khoản: `POST /api/users/register`, `/forgot-password`, `/reset-password`; `GET/PUT /api/users/me/profile`, `PUT /api/users/me/password`, `POST/DELETE /api/users/me/avatar`, `GET /api/users/me/sessions`, `DELETE /api/users/me/sessions/others`. Upload ảnh dùng multipart trường `file`, JPG/PNG tối đa 2 MB. Không gửi userId hoặc quyền tài khoản từ client.
- Thông báo: `GET /api/notifications`, `PATCH /api/notifications/{id}/read` và `/read-all`. Chỉ thay đổi trạng thái đọc sau khi máy chủ xác nhận.
- Các API học yêu cầu JWT Bearer, không thay đổi hoặc bỏ qua bảo mật backend.

## Chạy trên realme qua USB

Backend Spring Boot hiện tại trên máy tính phải đang chạy ở cổng 8080 và kết nối được MySQL.
Người dùng chủ động chạy các lệnh sau khi cần kiểm tra ứng dụng; không cần tạo task mới:

```powershell
adb -s 0H73A09I22103260 reverse tcp:8080 tcp:8080
flutter run -d 0H73A09I22103260 --dart-define=API_BASE_URL=htt<LOCAL_PROJECT_PATH>
```

`127.0.0.1` trên điện thoại chỉ đến backend máy tính khi có adb reverse. Khi rút/cắm USB hoặc khởi động lại thiết bị, cần chạy lại lệnh adb reverse. Không chạy thêm phiên flutter run nếu đã có một phiên đang hoạt động. Các plugin âm thanh, WebView, kho bảo mật, chọn ảnh và lần bổ sung `url_launcher`/`package_info_plus` cần dừng phiên cũ và chạy lại `flutter run`, không chỉ Hot Reload/Hot Restart.

Mở Từ điển để kiểm tra dữ liệu công khai (từ mặc định: 学校). Sau đó đăng nhập **trên điện thoại** bằng tài khoản website để tải bộ thẻ và ngữ pháp. Không ghi tài khoản/mật khẩu vào mã nguồn hoặc file cấu hình.

## Android/iOS và bản phát hành

Đổi endpoint bằng `--dart-define=API_BASE_URL=http<LOCAL_PROJECT_PATH><dia-chi-backend>` khi build/run. Bản release bắt buộc HTTPS; không có địa chỉ API sản xuất mặc định. Endpoint không được chứa thông tin đăng nhập.

Android chỉ cho HTTP loopback trong cấu hình debug, không mở cleartext cho bản release. iPhone thật không dùng được adb reverse; cần backend HTTPS mà iPhone truy cập được và build trên macOS. Không tắt kiểm tra chứng chỉ hoặc bật ngoại lệ HTTP toàn cục cho iOS.

## Phiên đăng nhập và giới hạn hiện tại

- Mặc định JWT chỉ giữ trong bộ nhớ. Có thể chọn **Giữ đăng nhập trên thiết bị này**: chỉ JWT và địa chỉ API được lưu bằng `flutter_secure_storage`, không lưu mật khẩu/hồ sơ hoặc dùng file/SharedPreferences dạng văn bản làm phương án dự phòng. Android tắt backup dữ liệu app; iOS cấu hình Keychain entitlements.
- Khi mở lại app, JWT đã lưu phải được backend xác nhận qua `GET /api/users/me/profile` trước khi nhận diện tài khoản. Token hết hạn bị xóa; mất mạng không hiển thị hồ sơ cũ và có nút thử khôi phục ở Cá nhân. Đăng xuất hoặc đăng nhập không chọn giữ phiên xóa bản lưu. Ghi/xóa được xếp hàng để thao tác ghi chậm không khôi phục token sau đăng xuất. Đăng nhập mới hủy kết quả khôi phục đang chờ, kể cả khi lần đăng nhập mới thất bại.
- Khi kho bảo mật bị khóa/lỗi, app báo lỗi tại Cá nhân; không lưu token sang nơi kém an toàn hơn. Cần kiểm tra Keychain/Keystore trên máy thật; thao tác xóa kho thất bại có thể cần người dùng đăng xuất lại khi thiết bị mở khóa.
- Đăng ký thành công quay về đăng nhập, không tự cấp phiên. Quên mật khẩu hiển thị phản hồi chung của backend; màn hình đặt lại nhận liên kết từ email hoặc token. Chưa đăng ký universal/app link tự mở ứng dụng. Đổi mật khẩu thành công xóa phiên hiện tại và yêu cầu đăng nhập lại; lỗi giữ form để sửa. Email thực tế phụ thuộc cấu hình gửi thư của backend.
- Nếu backend trả VIP_SESSION_ACTIVE, app hỏi xác nhận trước khi thay phiên thiết bị khác.
- HTTP 401 xóa phiên cũ; HTTP 403 báo thiếu quyền, kể cả khi gateway trả nội dung lỗi không phải JSON. Phản hồi thành công sai JSON vẫn báo lỗi dữ liệu. Phản hồi của số phiên cũ bị loại bỏ, kể cả khi backend cấp lại cùng chuỗi JWT; không làm hết phiên tài khoản hiện tại.
- Không dùng dữ liệu demo khi mất mạng hoặc tự thay dữ liệu cấp độ khác. Demo repository chỉ dùng khi được inject rõ ràng trong kiểm thử.
- Luyện viết AI và Kyuto đã được tích hợp trong mã ứng dụng. Không tự tạo đề, tự chấm bài hoặc tự gửi câu hỏi khi mở màn hình. Chỉ gọi AI khi người dùng bấm gửi/tạo đề.
- Yêu cầu AI có thời gian chờ riêng (120 giây cho Kyuto/tạo đề, 180 giây cho chấm bài); không tự thử lại POST. Nếu chấm bài quá thời gian chờ, app nhắc mở lịch sử trước khi gửi lại vì backend có thể đã lưu kết quả.
- Bản thảo giữ tại màn hình khi lỗi mạng; khi rời bản thảo chưa nộp, app hỏi lựa chọn. Không lưu bản thảo hoặc hội thoại vào file. Dữ liệu của phiên cũ không hiển thị cho tài khoản khác.
- Khi Kyuto hết lượt hoặc AI tạm ngừng, câu hỏi vẫn ở ô nhập, nguồn/liên kết học liệu do backend trả về vẫn xem được. `QUOTA_EXCEEDED` cập nhật số lượt hiển thị về 0; không chặn các câu hỏi điều hướng/tra cứu không tiêu tốn AI ở backend.
- Liên kết Kyuto chỉ được ánh xạ vào danh sách route Flutter cho phép; không mở URL bên ngoài từ kết quả AI. Mở được bài ngữ pháp cụ thể, danh sách Flashcard, JLPT và Video theo cấp độ; các đường dẫn chưa có tương đương native không được biến thành liên kết hoạt động.
- JLPT dùng tài liệu số hóa từ `examJsonUrl` khi có; lỗi tải tài liệu có nút tải lại. Mở đề hoặc tải danh sách không tự bắt đầu lượt thi. Sau khi mất phản hồi bắt đầu, cần tải lại danh sách để tìm lượt đang làm trước khi bắt đầu lại.
- Thời gian JLPT từ Spring `LocalDateTime` được đọc theo `API_TIMEZONE_OFFSET` (mặc định `+07:00`, đúng máy backend hiện tại), không theo múi giờ điện thoại. Nếu chuyển backend sang múi giờ khác phải truyền giá trị tương ứng khi chạy/build. Mốc có offset/Z được giữ nguyên. Backend quyết định hết giờ và điểm; điểm `/180` là điểm luyện tập tham khảo.
- Video dùng màn hình Flutter cho danh sách, phụ đề, bản dịch, từ vựng và ngữ pháp. WebView chỉ chứa trình phát YouTube/TikTok chính thức với ID đã kiểm tra; không nhúng website QTJP, JWT, URL nhập thô hoặc câu trả lời AI. Trình phát dùng origin HTTPS từ app ID thực tế do `package_info_plus` đọc, không dùng địa chỉ HTTP backend làm referrer. Chọn câu tua đến mốc tương ứng; bỏ tick cũ trong lúc chờ tua để tránh nhảy ngược câu; nghe lại câu dừng tại cuối câu; video tạm dừng khi app ra nền/rời màn hình.
- Mỗi video có sẵn có thể **Xem video trước, chưa gọi AI** bằng metadata thật của danh sách. Trong màn xem trước, bấm **Tải phụ đề và phân tích AI** mới gọi API mở video mẫu. Màn học có giải thích ngữ pháp và **Hỏi Kyuto về câu này**: điền sẵn câu, chưa gửi câu hỏi cho đến khi người học bấm gửi. Back từ màn học quay về danh sách video.
- Mở danh sách video chỉ đọc dữ liệu. Riêng `GET /presets/{id}` có thể tạo phụ đề ở backend nên chỉ gọi khi bấm mở video mẫu. Phân tích/phân tích lại chờ tối đa 180 giây, ngữ pháp 120 giây; không tự gửi lại. Sau timeout tạo phụ đề/phân tích, khóa thao tác tạo tiếp cho đến khi người dùng kiểm tra lịch sử. Quyền và quota lấy từ máy chủ. Video bị hạn chế nhúng/khu vực, riêng tư hoặc mất mạng hiển thị lỗi trình phát và nút thử lại.
- Hồ sơ, thiết bị, thông báo và video xóa dữ liệu riêng khi đổi phiên; phản hồi cũ không được áp dụng cho tài khoản mới. Thông báo chỉ mở các route native cho phép; đường dẫn ngoài bị bỏ qua, không có push/polling nền. API client từ chối đích khác origin API và không theo redirect mang thông tin đăng nhập.
- Google OAuth native chưa triển khai; không hiển thị nút đăng nhập Google chưa hoạt động. VIP/VNPAY đã có màn hình native và dùng backend hiện có, không có backend thanh toán mới.

## Thao tác AI và thanh toán trên app

- **Từ điển → Tra từ / giải thích với AI**: tra cứu hoặc giải thích chi tiết, đọc quota server. Không gọi AI khi chỉ mở màn hình; timeout giữ nội dung và yêu cầu kiểm tra quota trước khi gửi lại.
- **Ngữ pháp → Tra mẫu / phân tích câu bằng AI**: nhập câu/mẫu rồi bấm phân tích; kết quả hiển thị bản dịch, cấu trúc, ý nghĩa, cách dùng, lưu ý và ví dụ. Không tự gửi khi mở.
- **Cá nhân → Nâng cấp / gia hạn VIP** (hoặc liên kết VIP ở Video/AI): tải hồ sơ và lịch sử; chọn gói → xác nhận tạo đơn → xem số tiền backend trả về → bấm **Mở VNPAY để thanh toán**. Trình duyệt hệ thống mở đúng URL HTTPS đã ký, không nhận JWT qua header hay query do mobile thêm.
- Kiểm tra host/path VNPAY cho phép, mã đơn, số tiền VND nhân 100 và dạng chữ ký trước khi mở. Không sửa query đã ký. Tên miền sandbox hiển thị rõ môi trường thử nghiệm; không trình bày sandbox như thanh toán thật.
- Quay về app sẽ đọc lại lịch sử và hồ sơ; có nút **Kiểm tra thanh toán và cập nhật VIP** để kiểm tra tiếp nếu IPN/return còn đang xử lý. Không tin `payment=success` từ URL hoặc việc mở/đóng trình duyệt, không tự sửa membership hay gọi callback/IPN từ mobile.
- Tạo đơn timeout/phản hồi sai khóa tạo tiếp cho đến khi đọc lịch sử. Mở trình duyệt thất bại thử lại đúng đơn cũ, không POST lại. Lịch sử lỗi khóa tạo/mở thanh toán đến khi xác minh lại. Chọn gói khác không đồng nghĩa hủy đơn ở máy chủ; có cảnh báo đơn chờ để tránh trả trùng. Lịch sử hiện không cung cấp lại paymentUrl sau khi thoát app, vì vậy app không tự dựng URL hoặc giả khả năng tiếp tục đơn cũ.
- Backend vẫn phải cấu hình VNPAY (mặc định trong mã là Sandbox), xác minh chữ ký/số tiền, cấp VIP và cung cấp return/IPN URL có thể truy cập được. Trên USB, URL callback phải truy cập được từ trình duyệt điện thoại; mobile không tự đổi localhost/cổng trong URL đã ký. Bản iOS cần API/callback HTTPS và kiểm tra trên macOS/iPhone.
- Tài liệu nền tảng đã đối chiếu: [YouTube WebView/referrer](http<LOCAL_PROJECT_PATH> [url_launcher](http<LOCAL_PROJECT_PATH> [package_info_plus](http<LOCAL_PROJECT_PATH> [VNPAY Sandbox](http<LOCAL_PROJECT_PATH>

## Kiểm tra

```powershell
flutter analyze
flutter test
```

Kiểm thử API dùng transport giả lập để kiểm tra hợp đồng, xác thực, lỗi, phân cấp JLPT, tài khoản, video và thông báo. Kiểm thử multipart chỉ gửi đến HTTP server loopback do test tạo, không upload lên backend thật. Không tạo tài khoản, gửi email, dùng AI hoặc thay đổi dữ liệu website trong kiểm thử. Việc học và lưu tiến độ thật chỉ thực hiện khi người dùng thao tác trong ứng dụng.

Trên realme cần xác nhận phát YouTube/TikTok, chọn ảnh, đóng/mở lại app khi giữ phiên và âm thanh JLPT. iOS cần kiểm tra riêng trên macOS/iPhone với API HTTPS, quyền thư viện ảnh và Keychain. `flutter analyze`/widget test không xác nhận được các tích hợp native này.
