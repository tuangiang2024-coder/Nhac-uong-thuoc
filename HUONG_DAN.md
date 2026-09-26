# Nhắc uống thuốc – Hướng dẫn cài đặt

App Android có 2 phần:
- **Danh sách thuốc**: tên thuốc, mỗi lần uống bao nhiêu, ghi chú (sau ăn…), các giờ uống trong ngày.
- **Giọng đọc** (bản 2): đến giờ, máy đọc to tiếng Việt tên thuốc, liều và hướng dẫn cách uống, ví dụ: "Mẹ ơi, đến giờ uống thuốc buổi tối rồi ạ. Metformin 500 mi li gam, 1 viên, sau ăn. Uống với một cốc nước đầy."
- **Chuông báo**: đến giờ, máy đổ chuông lặp lại (kể cả khi đang khoá màn hình), hiện các thuốc cần uống, bấm **Đã uống** để tắt. Chuông tự lặp lại mỗi ngày.

Dữ liệu lưu ngay trong điện thoại, không cần mạng, không cần tài khoản.

Để có file cài đặt (APK), chọn **một** trong hai cách dưới đây.

---

## Cách 1: Nhờ GitHub tạo file APK (không phải cài gì lên máy tính)

1. Tạo tài khoản miễn phí tại https://github.com.
2. Bấm **New repository**, đặt tên `nhac-uong-thuoc`, chọn **Private**, bấm **Create repository**.
3. Bấm **uploading an existing file**. Kéo **toàn bộ nội dung** bên trong thư mục `nhac_uong_thuoc` (các thư mục `lib`, `android`, `test`, file `pubspec.yaml`…) vào trang, rồi bấm **Commit changes**.
4. Tạo file chạy tự động:
   - Bấm **Add file → Create new file**.
   - Ở ô tên file, gõ đúng: `.github/workflows/build-apk.yml`
   - Mở file `.github/workflows/build-apk.yml` trong thư mục đã tải về (bằng Notepad), copy toàn bộ và dán vào.
   - Bấm **Commit changes**.
5. Vào tab **Actions**. Chờ khoảng 5–10 phút đến khi có dấu tích xanh.
6. Bấm vào lần chạy đó, kéo xuống mục **Artifacts**, tải `nhac-uong-thuoc-apk` (file .zip, giải nén ra `app-release.apk`).

Nếu có dấu X đỏ, bấm vào để xem lỗi và gửi cho Claude.

---

## Cách 2: Cài công cụ lên máy tính Windows

Mất khoảng 1 giờ và cần khoảng 10 GB ổ cứng. Hợp nếu bạn muốn tự sửa app về sau.

1. Cài **Git for Windows**: https://git-scm.com/download/win
2. Cài **Android Studio**: https://developer.android.com/studio. Mở lên một lần, để nó tải Android SDK. Vào **More Actions → SDK Manager → SDK Tools**, tích **Android SDK Command-line Tools**, bấm OK.
3. Cài **Flutter**: làm theo https://docs.flutter.dev/get-started/install/windows/mobile (chọn Android). Sau khi cài, mở **PowerShell** và chạy:
   ```
   flutter doctor --android-licenses
   flutter doctor
   ```
   Bấm `y` để đồng ý các giấy phép. `flutter doctor` phải có dấu tích ở mục Flutter và Android toolchain.
4. Mở PowerShell trong thư mục `nhac_uong_thuoc` (mở thư mục trong File Explorer, gõ `powershell` vào thanh địa chỉ, Enter). Chạy lần lượt:
   ```
   flutter create --platforms=android --org vn.giadinh --project-name nhac_uong_thuoc .
   flutter pub get
   flutter build apk --release
   ```
   Lệnh đầu chỉ tạo thêm các file còn thiếu, không ghi đè code của app.
5. File cài đặt nằm ở: `build\app\outputs\flutter-apk\app-release.apk`

(Có thể cắm điện thoại qua USB, bật **Gỡ lỗi USB** trong Tuỳ chọn nhà phát triển, rồi chạy `flutter run --release` để cài thẳng.)

---

## Cài APK vào điện thoại

1. Gửi file `app-release.apk` sang điện thoại (qua Zalo, Google Drive, cáp USB…).
2. Mở file trên điện thoại. Nếu máy hỏi, cho phép **Cài ứng dụng không rõ nguồn gốc**.
3. Nếu Play Protect cảnh báo, chọn **Vẫn cài đặt** (vì app tự làm, chưa đăng lên cửa hàng).

## Cài đặt lần đầu (rất quan trọng)

Mở app, bấm biểu tượng bánh răng **Cài đặt chuông**:
1. Bật **Hiện thông báo** và **Báo thức đúng giờ** nếu đang "Chưa bật".
2. Bấm **Mở** ở **Hiện toàn màn hình khi khoá máy**, bật lên (Android 14 trở lên).
3. Tắt tối ưu pin cho app: **Cài đặt điện thoại → Ứng dụng → Nhắc uống thuốc → Pin → Không hạn chế**.
   - Xiaomi: bật thêm **Tự khởi động**.
   - Oppo/Realme: **Pin → Cho phép hoạt động nền**.
   - Samsung: **Pin → Không hạn chế**, và đảm bảo app không nằm trong "Ứng dụng ngủ".
4. Bấm **Thử chuông (sau 10 giây)**, tắt màn hình và chờ. Phải nghe chuông và thấy màn hình bật lên.

Âm lượng chuông theo **âm lượng Báo thức** của máy, nên chuông vẫn kêu khi máy để chế độ rung/im lặng. Hãy chỉnh âm lượng báo thức đủ to.

## Cài giọng đọc tiếng Việt (bản 2)

Trong app, vào **Cài đặt chuông → Giọng đọc**:
1. Nếu dòng **Giọng tiếng Việt trên máy** ghi "Chưa bật", bấm **Bật**. Chọn bộ đọc **Google** (Dịch vụ lời nói của Google), chọn ngôn ngữ **Tiếng Việt** và tải giọng về. Máy Samsung có thể dùng bộ đọc Samsung nếu có tiếng Việt. Nếu máy chưa có bộ đọc Google, cài **"Dịch vụ lời nói của Google"** (Speech Services by Google) từ CH Play.
2. Ô **Gọi người uống thuốc là**: gõ "Mẹ", "Bố", "Bà"… để máy gọi đúng người.
3. Chỉnh **Tốc độ đọc** cho vừa tai, bấm **Nghe thử giọng đọc**.

Khi đến giờ và màn hình chuông mở ra, tiếng chuông tắt và máy chuyển sang đọc lời nhắc, đọc lại mỗi phút cho đến khi bấm **Đã uống** (tối đa 30 phút). Có nút **Nghe lại** để đọc ngay. Nếu máy chưa có giọng tiếng Việt, chuông vẫn kêu như bản cũ.

Khi thêm/sửa thuốc, điền ô **Hướng dẫn cách uống** (ghi đúng theo dặn của bác sĩ/dược sĩ) và bấm **Nghe thử** để nghe máy đọc.

## Ảnh thuốc (bản 3)

Khi thêm/sửa thuốc, bấm **Chụp ảnh** để chụp viên thuốc hoặc vỉ thuốc (hoặc **Chọn ảnh** có sẵn trong máy). Nên chụp gần, đủ sáng, đặt viên thuốc trên nền trơn để thấy rõ màu và hình dáng. Chụp cả mặt vỉ có in tên thuốc càng tốt.

Đến giờ, màn hình chuông hiện ảnh to của từng loại thuốc cần uống. Bấm vào ảnh để xem to hơn, có thể dùng hai ngón tay để phóng to. Danh sách thuốc ở màn hình chính cũng có ảnh nhỏ.

## Cập nhật từ bản cũ

1. Trên GitHub, vào repo, bấm **Add file → Upload files**, kéo toàn bộ nội dung thư mục `nhac_uong_thuoc` mới vào (ghi đè file cũ), bấm **Commit changes**. Nhớ có cả file `android/app/nhac-uong-thuoc.jks` (khoá ký app) và thư mục `android/app/src/main/kotlin`.
2. Chờ tab **Actions** chạy xong (dấu tích xanh), tải APK mới.
3. **Riêng lần cập nhật lên bản 2:** gỡ app cũ trên điện thoại trước rồi mới cài bản mới (bản 1 được ký bằng khoá tạm nên không cài đè được). Sau đó nhập lại thuốc.
4. Từ bản 2 trở đi, app dùng khoá ký cố định: chỉ cần cài đè, danh sách thuốc được giữ nguyên.

Giữ repo GitHub ở chế độ **Private**, vì trong đó có khoá ký app.

## Sử dụng

- **Thêm thuốc**: nhập tên, liều, ghi chú, bấm **Thêm giờ** để chọn các giờ uống, rồi **Lưu**.
- **Sửa/xoá**: bấm vào tên thuốc ở màn hình chính.
- Các thuốc cùng giờ sẽ gộp vào một lần chuông.
- Khi chuông kêu: bấm **Đã uống** (trên màn hình hoặc ngay trên thông báo) để tắt. Nếu không ai bấm, chuông tự tắt sau 30 phút.

Nên dùng thử vài ngày để chắc chuông luôn kêu đúng giờ trước khi hoàn toàn tin vào app.
