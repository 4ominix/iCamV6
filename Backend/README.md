# HỆ THỐNG MÁY CHỦ BẢN QUYỀN VCAM PRO (LICENSE BACKEND)

Hệ thống quản lý tài khoản, cấp quyền, giới hạn thiết bị và kiểm soát bản quyền cho tweak VCam Pro.

---

## 1. Hướng dẫn khởi chạy Server

### Trên Máy tính cá nhân (hoặc VPS Windows / Linux / Ubuntu):
1. Cài đặt **Node.js** (tải tại [nodejs.org](https://nodejs.org/)).
2. Mở Terminal / PowerShell tại thư mục `Backend/`:
   ```bash
   npm install
   npm start
   ```
3. Server sẽ chạy mặc định tại cổng `3000`:
   * **Admin Dashboard:** Mở trình duyệt vào `http://localhost:3000/admin`
   * Mọi tài khoản và dữ liệu thiết bị sẽ tự động lưu vào file `database.json`.

---

## 2. Cách quản lý & Cấp quyền người dùng

Bạn có 2 cách cực kỳ tiện lợi để quản lý:

### Cách 1: Dùng Giao diện Web (Dashboard)
Truy cập: `http://localhost:3000/admin`
* Nhập Username, Password, Số ngày muốn cấp (VD: 30), Số thiết bị tối đa (VD: 1 hoặc 2) -> Bấm **Tạo Tài Khoản**.
* Có nút **Xóa thiết bị** ngay trên web khi khách hàng đổi iPhone mới.
* Có nút **Xóa User** để thu hồi quyền ngay lập tức.

### Cách 2: Dùng Dòng lệnh CLI (Cực nhanh qua Terminal)
* **Tạo tài khoản:**
  ```bash
  node admin_cli.js add khachhang1 matkhau123 30 1
  ```
* **Xem danh sách người dùng & số máy đang dùng:**
  ```bash
  node admin_cli.js list
  ```
* **Gia hạn ngày cho khách:**
  ```bash
  node admin_cli.js extend khachhang1 30
  ```
* **Reset thiết bị (cho khách đổi máy):**
  ```bash
  node admin_cli.js reset khachhang1
  ```

---

## 3. Triển khai Domain & Tweak kết nối đến Server của bạn

1. Đưa server lên VPS (hoặc dùng dịch vụ miễn phí như Render, Railway, Vercel, hoặc mở port qua Cloudflare Tunnel / Ngrok).
2. Trỏ domain hoặc subdomain của bạn về IP VPS (ví dụ: `api.vcamcuaban.com`).
3. Trong file `RootViewController.m` của App hoặc trong Tweak, cập nhật đường dẫn URL server về `https://api.vcamcuaban.com` là toàn bộ thiết bị của khách sẽ kết nối thẳng về máy chủ do bạn làm chủ 100%!
