const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(cors());

const PORT = process.env.PORT || 3000;
const DB_FILE = path.join(__dirname, 'database.json');
const SECRET_SIGNING_KEY = 'VCAM_PRO_SECRET_KEY_MASTER_2026';

// Initialize Database
let db = {
    users: {},
    challenges: {}
};

if (fs.existsSync(DB_FILE)) {
    try {
        db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
    } catch (e) {
        console.error('Error loading database. Initializing fresh DB.');
    }
} else {
    // Default Master Admin Account
    db.users['admin'] = {
        password: 'password123',
        role: 'lifetime',
        expireDate: '2099-12-31',
        maxDevices: 10,
        activeDevices: []
    };
    saveDatabase();
}

function saveDatabase() {
    fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

// ==========================================
// CLIENT / TWEAK API ENDPOINTS
// ==========================================

// 1. Challenge Handshake
app.post('/api/auth/challenge', (req, res) => {
    const deviceId = req.headers['x-device-id'] || req.body.device_id || 'unknown';
    const challengeId = crypto.randomUUID();
    const challengeNonce = crypto.randomBytes(16).toString('hex');

    db.challenges[challengeId] = {
        nonce: challengeNonce,
        deviceId: deviceId,
        createdAt: Date.now()
    };

    res.json({
        challenge_id: challengeId,
        challenge_nonce: challengeNonce
    });
});

// 2. Login & License Issuance
app.post('/api/auth/login', (req, res) => {
    const { username, password, device_id, device_name } = req.body;

    const user = db.users[username];
    if (!user || user.password !== password) {
        return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Sai tên đăng nhập hoặc mật khẩu.' });
    }

    // Check expiration date
    const now = new Date();
    const expiry = new Date(user.expireDate);
    if (now > expiry) {
        return res.status(403).json({ error: 'LICENSE_EXPIRED', message: 'Tài khoản đã hết hạn sử dụng.' });
    }

    // Check device limit
    if (!user.activeDevices.includes(device_id)) {
        if (user.activeDevices.length >= user.maxDevices) {
            return res.status(403).json({
                error: 'DEVICE_LIMIT',
                message: `Đã vượt quá số lượng thiết bị cho phép (${user.activeDevices.length}/${user.maxDevices}).`
            });
        }
        user.activeDevices.push(device_id);
        saveDatabase();
    }

    // Generate Lease with cryptographic HMAC-SHA256 signature
    const leaseData = {
        username: username,
        role: user.role,
        expireDate: user.expireDate,
        device_id: device_id,
        issuedAt: Date.now()
    };

    const leaseString = JSON.stringify(leaseData);
    const signature = crypto.createHmac('sha256', SECRET_SIGNING_KEY).update(leaseString).digest('hex');

    const accessToken = crypto.randomBytes(32).toString('hex');
    const renewalToken = crypto.randomBytes(32).toString('hex');

    res.json({
        access_token: accessToken,
        renewal_token: renewalToken,
        lease: leaseData,
        lease_signature: signature,
        active_devices: user.activeDevices.length,
        max_devices: user.maxDevices
    });
});

// 3. Heartbeat (Giữ kết nối & kiểm tra thu hồi quyền)
app.post('/api/auth/heartbeat', (req, res) => {
    const { username, device_id } = req.body;
    const user = db.users[username];

    if (!user || !user.activeDevices.includes(device_id)) {
        return res.status(401).json({ error: 'INVALID_SESSION', message: 'Thiết bị đã bị ngắt kết nối.' });
    }

    res.json({ status: 'OK', valid: true });
});

// ==========================================
// ADMIN DASHBOARD & MANAGEMENT API
// ==========================================

// Web Dashboard UI
app.get('/admin', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>VCam Pro - Quản Trị Bản Quyền</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #0f1115; color: #fff; padding: 20px; }
            .container { max-width: 900px; margin: 0 auto; }
            h1 { color: #3b82f6; }
            .card { background: #1a1d24; border-radius: 12px; padding: 20px; margin-bottom: 20px; border: 1px solid #2d3340; }
            table { width: 100%; border-collapse: collapse; margin-top: 10px; }
            th, td { padding: 12px; text-align: left; border-bottom: 1px solid #2d3340; }
            th { color: #94a3b8; }
            input, select, button { padding: 10px; border-radius: 6px; border: 1px solid #3b4252; background: #252a34; color: #fff; margin: 5px 0; }
            button { background: #3b82f6; border: none; cursor: pointer; font-weight: bold; }
            button:hover { background: #2563eb; }
            .btn-danger { background: #ef4444; }
            .btn-danger:hover { background: #dc2626; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>VCam Pro - Quản Lý Bản Quyền</h1>
            
            <div class="card">
                <h3>Tạo Tài Khoản Mới Cho Khách</h3>
                <form id="createForm">
                    <input type="text" id="username" placeholder="Tên đăng nhập" required>
                    <input type="text" id="password" placeholder="Mật khẩu" required>
                    <input type="number" id="days" placeholder="Số ngày sử dụng (VD: 30)" value="30" required>
                    <input type="number" id="maxDev" placeholder="Số thiết bị tối đa (VD: 1)" value="1" required>
                    <button type="submit">Tạo Tài Khoản</button>
                </form>
            </div>

            <div class="card">
                <h3>Danh Sách Người Dùng Đang Hoạt Động</h3>
                <table id="userTable">
                    <thead>
                        <tr>
                            <th>Tài khoản</th>
                            <th>Mật khẩu</th>
                            <th>Hết hạn</th>
                            <th>Thiết bị (Đang dùng / Max)</th>
                            <th>Thao tác</th>
                        </tr>
                    </thead>
                    <tbody></tbody>
                </table>
            </div>
        </div>

        <script>
            async function loadUsers() {
                const res = await fetch('/api/admin/users');
                const users = await res.json();
                const tbody = document.querySelector('#userTable tbody');
                tbody.innerHTML = '';
                
                for (const [uname, u] of Object.entries(users)) {
                    const tr = document.createElement('tr');
                    tr.innerHTML = \`
                        <td><strong>\${uname}</strong></td>
                        <td>\${u.password}</td>
                        <td>\${u.expireDate}</td>
                        <td>\${u.activeDevices.length} / \${u.maxDevices}</td>
                        <td>
                            <button onclick="resetDevices('\${uname}')">Xóa thiết bị</button>
                            <button class="btn-danger" onclick="deleteUser('\${uname}')">Xóa User</button>
                        </td>
                    \`;
                    tbody.appendChild(tr);
                }
            }

            document.getElementById('createForm').onsubmit = async (e) => {
                e.preventDefault();
                const username = document.getElementById('username').value;
                const password = document.getElementById('password').value;
                const days = parseInt(document.getElementById('days').value);
                const maxDevices = parseInt(document.getElementById('maxDev').value);

                await fetch('/api/admin/users', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({ username, password, days, maxDevices })
                });
                alert('Tạo tài khoản thành công!');
                loadUsers();
            };

            async function resetDevices(uname) {
                if (confirm('Xóa toàn bộ thiết bị đang lưu của ' + uname + '?')) {
                    await fetch('/api/admin/users/reset', {
                        method: 'POST',
                        headers: {'Content-Type': 'application/json'},
                        body: JSON.stringify({ username: uname })
                    });
                    loadUsers();
                }
            }

            async function deleteUser(uname) {
                if (confirm('Chắc chắn muốn xóa tài khoản ' + uname + '?')) {
                    await fetch('/api/admin/users/' + uname, { method: 'DELETE' });
                    loadUsers();
                }
            }

            loadUsers();
        </script>
    </body>
    </html>
    `);
});

// Admin REST APIs
app.get('/api/admin/users', (req, res) => {
    res.json(db.users);
});

app.post('/api/admin/users', (req, res) => {
    const { username, password, days, maxDevices } = req.body;
    const exp = new Date();
    exp.setDate(exp.getDate() + (days || 30));

    db.users[username] = {
        password: password,
        role: 'user',
        expireDate: exp.toISOString().split('T')[0],
        maxDevices: maxDevices || 1,
        activeDevices: []
    };
    saveDatabase();
    res.json({ success: true, user: db.users[username] });
});

app.post('/api/admin/users/reset', (req, res) => {
    const { username } = req.body;
    if (db.users[username]) {
        db.users[username].activeDevices = [];
        saveDatabase();
    }
    res.json({ success: true });
});

app.delete('/api/admin/users/:username', (req, res) => {
    delete db.users[req.params.username];
    saveDatabase();
    res.json({ success: true });
});

app.listen(PORT, () => {
    console.log(`[VCam License Backend] Running on http://localhost:${PORT}`);
    console.log(`[Admin Dashboard] Open in browser: http://localhost:${PORT}/admin`);
});
