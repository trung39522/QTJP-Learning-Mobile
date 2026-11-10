# Chức năng QTJP Learning Mobile

## Học tiếng Nhật

| Chức năng | Nội dung |
| --- | --- |
| Bảng chữ cái | Hiragana/Katakana, nét viết ngoại tuyến và phát âm |
| Từ điển | Tra từ, cách đọc, nghĩa, ví dụ và giải thích AI |
| Flashcard | Bộ thẻ theo cấp độ JLPT, học từ và lưu tiến độ |
| Ngữ pháp | Giáo trình, chi tiết bài học, tra mẫu và phân tích câu |
| Luyện viết | Chủ đề, chấm bài, sửa bài, lịch sử và thống kê |
| Kyuto | Hội thoại có ngữ cảnh, nguồn tham khảo và liên kết học liệu |
| JLPT | Chọn đề, bắt đầu hoặc tiếp tục bài, nghe, đánh dấu câu và xem kết quả |
| Video | Danh sách theo cấp độ, xem trước, phân tích phụ đề, từ vựng và ngữ pháp |

## Tài khoản

Ứng dụng hỗ trợ đăng ký, đăng nhập, khôi phục và đổi mật khẩu, cập nhật hồ sơ, ảnh đại diện, quản lý phiên thiết bị và đọc thông báo.

Tùy chọn giữ đăng nhập sử dụng kho bảo mật của hệ điều hành. Phiên được xác nhận lại với máy chủ khi mở ứng dụng. Các màn hình cập nhật dữ liệu theo tài khoản đang đăng nhập.

## Gói VIP và thanh toán

Người học có thể chọn gói 1, 3, 6 hoặc 12 tháng. Sau khi tạo đơn, ứng dụng hiển thị số tiền từ máy chủ và mở VNPAY bằng trình duyệt hệ thống.

Khi quay về ứng dụng, lịch sử giao dịch và quyền VIP được cập nhật từ backend. Môi trường VNPAY Sandbox có nhãn thử nghiệm riêng.

## Phạm vi tích hợp

Các luồng học, tài khoản và thanh toán đã được triển khai trong mã ứng dụng. Phát video, âm thanh, thư viện ảnh, khôi phục phiên và thanh toán cần được kiểm tra trên thiết bị với cấu hình backend tương ứng. Kiểm thử tự động bao phủ hợp đồng API, trạng thái màn hình và xử lý lỗi; kiểm thử thiết bị được thực hiện riêng cho Android và iOS.

Đăng nhập Google và liên kết email tự mở ứng dụng chưa được hỗ trợ. Liên kết đặt lại mật khẩu có thể được dán vào màn hình khôi phục.

## Cấu trúc mã nguồn

- [lib/app](../lib/app): trạng thái ứng dụng và điều hướng chính.
- [lib/core](../lib/core): kết nối API, lưu phiên, giao diện dùng chung.
- [lib/screens](../lib/screens): các màn hình và repository theo chức năng.
- [assets](../assets): hình ảnh, nhận diện và dữ liệu nét viết.
- [test](../test): kiểm thử dữ liệu, tích hợp API và widget.

Chi tiết endpoint và cấu hình kết nối: [mobile-api.md](./mobile-api.md).
