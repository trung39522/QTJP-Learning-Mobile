# Đăng nhập Google trên Android

Ứng dụng dùng plugin `google_sign_in` chính thức và gửi ID token đến API đang có: `POST /api/users/google-login`. Quyền truy cập, phiên VIP và JWT của QTJP vẫn do backend xác minh. ID token Google không được lưu trên thiết bị.

Client ID riêng được đọc từ `GOOGLE_SERVER_CLIENT_ID` khi build. Mã nguồn công khai không có client ID mặc định. Sao chép [cấu hình mẫu](../config/local.example.json) thành `config/local.json`, điền cấu hình của bạn và chạy `flutter run --dart-define-from-file=config/local.json`. File này đã được Git bỏ qua; không dùng client secret trong ứng dụng.

Trong cùng dự án Google Cloud của website, tạo hoặc kiểm tra OAuth client loại **Android**:

- Package: `com.example.qtjp_mobile`
- SHA-1: lấy từ chứng chỉ ký trên máy của bạn; không đưa dấu vân tay cá nhân vào tài liệu công khai.
- Web OAuth client phải tương ứng với Client ID mà backend chấp nhận.

Không cần thêm `google-services.json` khi đã truyền `serverClientId` bằng Dart. Bản phát hành phải đăng ký thêm chứng chỉ ký phát hành hoặc Play App Signing; không dùng SHA-1 debug để thay thế.

Chưa xác minh đăng nhập bằng tài khoản Google thật nếu chưa hoàn thành đăng ký OAuth Android. Hủy hộp chọn tài khoản không gửi yêu cầu đăng nhập. Xung đột phiên VIP chỉ được thay sau khi người dùng xác nhận.

## Cấu hình trên Google Cloud

1. Mở [Google Cloud Console](https://console.cloud.google.com/auth/clients), chọn đúng project chứa OAuth client **Web application** của website QTJP. Không tạo project mới cho lần thử này.
2. Vào **Google Auth Platform → Clients → Create client**. Giao diện cũ có thể hiển thị **APIs & Services → Credentials → Create credentials → OAuth client ID**.
3. Chọn **Application type: Android**, đặt tên dễ nhận biết, ví dụ `QTJP Mobile Debug`.
4. Nhập package `com.example.qtjp_mobile` và SHA-1 của chứng chỉ ký APK trên máy của bạn, sau đó lưu. Có thể xem báo cáo chứng chỉ bằng `./gradlew signingReport` trong thư mục Android; giữ kết quả ở máy cá nhân.
5. Giữ nguyên OAuth client Web của website. Flutter truyền **Web client ID** làm `serverClientId`; không thay bằng client ID loại Android vừa tạo.

Giá trị cấu hình riêng có dạng:

```text
<WEB_CLIENT_ID>
```

Backend đọc client ID từ biến môi trường `GOOGLE_CLIENT_ID`. Giá trị lúc chạy phải trùng với Web client ID mà Flutter sử dụng, vì backend kiểm tra audience của ID token. Chưa xác minh được giá trị của biến trong phiên backend đang chạy. Không cần sửa API hoặc logic xác thực để thêm client Android.

Nếu Google báo tài khoản không được phép truy cập và project đang ở trạng thái **Testing**, kiểm tra **Google Auth Platform → Audience → Test users** và thêm đúng tài khoản đang dùng để thử. Nếu project đã được cấu hình cho website, kiểm tra cấu hình hiện có trước khi thay đổi. Không cần chuyển ứng dụng sang Production chỉ để thử trên điện thoại.

## Kiểm tra kết nối API khi thử qua USB

Google xác nhận tài khoản và QTJP tạo phiên đăng nhập là hai bước riêng. Sau khi nhận ID token Google, điện thoại còn phải gọi được backend QTJP.

Bản debug qua USB có thể dùng `API_BASE_URL=http://127.0.0.1:8080`. Cần backend chạy trên máy tính ở cổng 8080, điện thoại cắm USB, và chuyển tiếp cổng:

```powershell
adb -s '<DEVICE_ID>' reverse tcp:8080 tcp:8080
```

Task VS Code **QTJP Mobile: Run on realme RMX3760** đã có bước chuyển tiếp này. Lệnh `adb reverse` không tự khởi động backend. Có thể thử đăng nhập bằng mật khẩu trước để kiểm tra kết nối đến API; đăng nhập mật khẩu thành công chưa đủ để kết luận OAuth Android đã đúng.

Sau khi chỉ thêm/sửa client Android trên Google Cloud, thử lại đăng nhập trên app hiện có. Chỉ cần build lại nếu thay package, chứng chỉ ký hoặc Web client ID truyền trong Dart.

## Nhận biết lỗi

| Biểu hiện | Cần kiểm tra |
| --- | --- |
| Không mở được bộ chọn tài khoản hoặc báo lỗi cấu hình client | Package, SHA-1, Web `serverClientId`, đúng project Google Cloud; dịch vụ Google Play và kết nối mạng trên điện thoại. |
| Chọn tài khoản xong rồi quay lại, không đăng nhập | Đối chiếu OAuth Android trước. Plugin có thể nhận mã `canceled` ngay cả khi nguyên nhân là cấu hình sai; chưa thể kết luận người dùng đã hủy. |
| Google báo ứng dụng bị chặn / tài khoản không được phép | Đọc mã lỗi cụ thể; kiểm tra Audience, Test users hoặc chính sách tài khoản Google Workspace tương ứng. |
| Google chọn tài khoản thành công nhưng QTJP báo không kết nối được | Backend cổng 8080 và USB reverse. |
| QTJP báo “Không thể xác minh tài khoản Google” | Web client ID của Flutter có trùng `GOOGLE_CLIENT_ID` thực tế của backend không; kết nối backend đến Google. |
| Thông báo xung đột phiên VIP | Dùng luồng xác nhận phiên hiện có; không đổi cấu hình Google để bỏ qua giới hạn phiên. |

Khi cần chẩn đoán tiếp, cung cấp nguyên văn lỗi và bước bị lỗi: trước hay sau khi chọn tài khoản. Không chia sẻ ID token, JWT, client secret hoặc mật khẩu.

Tài liệu chính thức: [Google Sign-In Android và xử lý lỗi cấu hình](https://pub.dev/packages/google_sign_in_android), [Sign in with Google trên Android](https://developer.android.com/identity/sign-in/credential-manager-siwg), [OAuth Testing và Test users](https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification#projects-used-in-development-testing-or-staging-tiers).
