#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const DB_FILE = path.join(__dirname, 'database.json');

function loadDB() {
    if (!fs.existsSync(DB_FILE)) {
        console.error('Không tìm thấy file database.json. Hãy khởi động server trước!');
        process.exit(1);
    }
    return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
}

function saveDB(db) {
    fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

const args = process.argv.slice(2);
const command = args[0];

if (!command || command === 'help') {
    console.log(`
=== VCAM PRO - CÔNG CỤ QUẢN LÝ BẢN QUYỀN CLI ===

Cách dùng:
  node admin_cli.js add <username> <password> <số_ngày> <số_máy_tối_đa>
    -> Ví dụ: node admin_cli.js add khachhang1 pass123 30 1

  node admin_cli.js list
    -> Xem toàn bộ danh sách khách hàng và hạn dùng

  node admin_cli.js reset <username>
    -> Xóa danh sách thiết bị đã lưu (khi khách đổi máy mới)

  node admin_cli.js extend <username> <số_ngày_cộng_thêm>
    -> Ví dụ: node admin_cli.js extend khachhang1 30

  node admin_cli.js remove <username>
    -> Xóa tài khoản khách hàng
`);
    process.exit(0);
}

const db = loadDB();

switch (command) {
    case 'add': {
        const username = args[1];
        const password = args[2];
        const days = parseInt(args[3]) || 30;
        const maxDev = parseInt(args[4]) || 1;

        if (!username || !password) {
            console.error('Thiếu username hoặc password!');
            process.exit(1);
        }

        const exp = new Date();
        exp.setDate(exp.getDate() + days);

        db.users[username] = {
            password: password,
            role: 'user',
            expireDate: exp.toISOString().split('T')[0],
            maxDevices: maxDev,
            activeDevices: []
        };
        saveDB(db);
        console.log(`[+] Đã tạo thành công tài khoản: ${username} (Hạn dùng: ${days} ngày, Số máy: ${maxDev})`);
        break;
    }

    case 'list': {
        console.log('\n=== DANH SÁCH KHÁCH HÀNG ===');
        console.table(Object.entries(db.users).map(([uname, u]) => ({
            'Username': uname,
            'Password': u.password,
            'Hết hạn': u.expireDate,
            'Máy online': `${u.activeDevices.length}/${u.maxDevices}`
        })));
        break;
    }

    case 'reset': {
        const username = args[1];
        if (!db.users[username]) {
            console.error('Không tìm thấy user: ' + username);
            process.exit(1);
        }
        db.users[username].activeDevices = [];
        saveDB(db);
        console.log(`[+] Đã xóa thiết bị của ${username}. Khách có thể đăng nhập trên máy mới!`);
        break;
    }

    case 'extend': {
        const username = args[1];
        const addDays = parseInt(args[2]) || 30;
        if (!db.users[username]) {
            console.error('Không tìm thấy user: ' + username);
            process.exit(1);
        }
        const curExp = new Date(db.users[username].expireDate);
        curExp.setDate(curExp.getDate() + addDays);
        db.users[username].expireDate = curExp.toISOString().split('T')[0];
        saveDB(db);
        console.log(`[+] Đã gia hạn cho ${username} thêm ${addDays} ngày. Hạn mới: ${db.users[username].expireDate}`);
        break;
    }

    case 'remove': {
        const username = args[1];
        if (db.users[username]) {
            delete db.users[username];
            saveDB(db);
            console.log(`[+] Đã xóa tài khoản: ${username}`);
        } else {
            console.error('Không tìm thấy user: ' + username);
        }
        break;
    }

    default:
        console.log('Lệnh không hợp lệ. Gõ `node admin_cli.js help` để xem hướng dẫn.');
}
