# VCAM PRO - FULL SOURCE CODE TWEAK & LICENSE MANAGEMENT

Bộ mã nguồn mở hoàn chỉnh cho Tweak Camera ảo (Virtual Camera) trên iOS 15.0+ (Dopamine Rootless / RootHide), xây dựng theo kiến trúc sạch (Clean-room Implementation) dựa trên bản phân tích ngược VcamNextPlus.

Toàn bộ quyền sở hữu, mã nguồn và hệ thống xác thực thuộc về bạn.

---

## 1. CẤU TRÚC THƯ MỤC DỰ ÁN

```
Vcam-src/
├── Makefile                      # Root Makefile điều khiển Theos biên dịch toàn bộ gói
├── control                       # Metadata gói Debian (.deb)
├── README.md                     # Hướng dẫn tổng quan và đóng gói
│
├── App/                          # [MODULE 1] Ứng dụng GUI chính (VCNext.app)
│   ├── Makefile
│   ├── Info.plist
│   ├── main.m
│   ├── AppDelegate.h / .m
│   └── RootViewController.h / .m # 5 Sections chuẩn: Status, Media, OBS Link, Behavior/Color Sync, Account
│
├── CameraTweak/                  # [MODULE 2] Tweak tiêm Camera (VCNextCamera.dylib)
│   ├── Makefile
│   ├── VCNextCamera.plist        # Filter tiêm vào cameracaptured & mediaserverd
│   └── Tweak.x                   # Hook AVCaptureSession, CVPixelBuffer swapping, Realtime Color Sync Filter
│
├── OverlayTweak/                 # [MODULE 3] Nút Home Nổi (VCNextOverlay.dylib)
│   ├── Makefile
│   ├── VCNextOverlay.plist       # Filter tiêm vào SpringBoard
│   └── Overlay.x                 # Cửa sổ UIWindow nổi đè mọi App, AssistiveTouch kéo thả, Panel Zoom & Control
│
├── StreamDaemon/                 # [MODULE 4] Daemon nhận luồng OBS (VCNStreamDaemon)
│   ├── Makefile
│   ├── com.vcnext.streamd.plist  # LaunchDaemon chạy nền quyền mobile
│   └── main.m                    # Socket TCP lắng nghe cổng 1935 RTMP, ghi đệm luồng live.vcn
│
└── Backend/                      # [MODULE 5] Máy chủ Quản lý Tài khoản & Cấp quyền
    ├── package.json
    ├── server.js                 # Server Express API xác thực, HMAC Lease + Web Dashboard (/admin)
    ├── admin_cli.js              # Công cụ Terminal CLI tạo user, gia hạn ngày, xóa máy khách
    └── README.md                 # Hướng dẫn chi tiết triển khai server bản quyền
```

---

## 2. HƯỚNG DẪN BIÊN DỊCH THÀNH FILE .DEB

### Yêu cầu môi trường:
* Máy Mac hoặc máy tính Linux/Windows (WSL) có cài đặt **Theos**.
* Hoặc biên dịch trực tiếp trên iPhone qua NewTerm / Filza (đã cài đặt `theos`).

### Lệnh biên dịch:
Mở Terminal tại thư mục `Vcam-src/`:
```bash
# 1. Dọn dẹp bản build cũ
make clean

# 2. Biên dịch và đóng gói thành file .deb cho iOS 15 Rootless (arm64/arm64e)
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

Sau khi hoàn thành, file `.deb` thành phẩm sẽ xuất hiện trong thư mục `packages/`.

---

## 3. CÁCH HOẠT ĐỘNG VÀ QUẢN LÝ BẢN QUYỀN

1. **Chạy Server:** 
   Vào thư mục `Backend/`, chạy `npm start`. Mở `http://localhost:3000/admin` để tạo tài khoản cho bạn và khách hàng.
2. **Cài đặt Tweak trên iPhone:**
   Cài file `.deb` qua Sileo/Zebra trên Dopamine (hỗ trợ cả RootHide và Rootless).
3. **Mở App VCam Custom:**
   * Chọn video từ thư viện ảnh hoặc ném video vào `/var/jb/var/mobile/Library/VCNext/Media/`.
   * Bật **Floating Control** để con trỏ nút Home ảo xuất hiện trên màn hình, đi vào bất kỳ app nào (Zalo, TikTok, Telegram) cũng có thể bấm nút nổi để bật/tắt, zoom và chỉnh màu.
   * Bật **Color Sync** để video giả tự động điều chỉnh ánh sáng, độ ấm/lạnh theo môi trường phòng thực tế.
