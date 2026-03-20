const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcrypt');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
const PORT = 3000;

// Middleware-ek
app.use(cors()); 
app.use(bodyParser.json()); 

// Kapcsolódás a MySQL-hez
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '', // HeidiSQL-ben ellenőrizd, ha van jelszavad!
    database: 'flutter_auth'
});

db.connect((err) => {
    if (err) {
        console.error('Hiba a MySQL csatlakozásnál: ' + err.stack);
        return;
    }
    console.log('Sikeresen kapcsolódva a MySQL-hez (ID: ' + db.threadId + ')');
});

// --- AUTHENTIKÁCIÓ ---

app.post('/register', async (req, res) => {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ error: "Hiányzó adatok!" });

    try {
        const hashedPassword = await bcrypt.hash(password, 10);
        const sql = "INSERT INTO users (username, password) VALUES (?, ?)";
        db.query(sql, [username, hashedPassword], (err, result) => {
            if (err) {
                if (err.code === 'ER_DUP_ENTRY') return res.status(400).json({ error: "Foglalt felhasználónév!" });
                return res.status(500).json({ error: "Adatbázis hiba." });
            }
            res.status(200).json({ message: "Sikeres regisztráció!" });
        });
    } catch (error) {
        res.status(500).json({ error: "Szerver hiba." });
    }
});

app.post('/login', (req, res) => {
    const { username, password } = req.body;
    const sql = "SELECT * FROM users WHERE username = ?";
    db.query(sql, [username], async (err, results) => {
        if (err) return res.status(500).json({ error: "Lekérdezési hiba." });
        if (results.length === 0) return res.status(404).json({ error: "Nincs ilyen felhasználó!" });

        const user = results[0];
        const isMatch = await bcrypt.compare(password, user.password);

        if (isMatch) {
            res.status(200).json({ 
                message: "Sikeres bejelentkezés!",
                user: { id: user.id, username: user.username }
            });
        } else {
            res.status(401).json({ error: "Hibás jelszó!" });
        }
    });
});

// --- KAPTÁR KEZELÉS (SZÍNKÓD TÁMOGATÁSSAL) ---

// Kaptárak lekérése az utolsó jegyzet dátumával együtt
app.get('/beehives/:userId', (req, res) => {
    const sql = `
        SELECT b.*, 
        (SELECT MAX(created_at) FROM notes WHERE beehive_id = b.id) as last_note 
        FROM beehives b 
        WHERE b.user_id = ?`;
    
    db.query(sql, [req.params.userId], (err, results) => {
        if (err) {
            console.error("Hiba a kaptárak lekérésekor:", err);
            return res.status(500).json(err);
        }
        res.json(results);
    });
});

// Tömeges kaptár hozzáadás
app.post('/beehives-bulk', (req, res) => {
    const { userId, count } = req.body;
    if (!count || count < 1) return res.status(400).json({ error: "Érvénytelen darabszám" });

    db.query("SELECT COUNT(*) as total FROM beehives WHERE user_id = ?", [userId], (err, results) => {
        if (err) return res.status(500).json(err);
        
        let startNum = results[0].total + 1;
        let values = [];
        for (let i = 0; i < count; i++) {
            values.push([userId, `${startNum + i}. Kaptár`]);
        }

        const sql = "INSERT INTO beehives (user_id, hive_name) VALUES ?";
        db.query(sql, [values], (err, result) => {
            if (err) return res.status(500).json(err);
            res.json({ message: "Kaptárak hozzáadva!" });
        });
    });
});

// --- JEGYZET KEZELÉS ---

app.get('/notes/:userId/:beehiveId', (req, res) => {
    const { userId, beehiveId } = req.params;
    const sql = "SELECT * FROM notes WHERE user_id = ? AND beehive_id = ? ORDER BY created_at DESC";
    db.query(sql, [userId, beehiveId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.post('/notes', (req, res) => {
    const { userId, beehiveId, content } = req.body;
    const sql = "INSERT INTO notes (user_id, beehive_id, content) VALUES (?, ?, ?)";
    db.query(sql, [userId, beehiveId, content], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: "Mentve!", id: result.insertId });
    });
});

app.put('/notes/:id', (req, res) => {
    const { content } = req.body;
    const sql = "UPDATE notes SET content = ? WHERE id = ?";
    db.query(sql, [content, req.params.id], (err, result) => {
        if (err) return res.status(500).json({ error: "Hiba a szerkesztésnél" });
        res.json({ message: "Frissítve!" });
    });
});

app.delete('/notes/:id', (req, res) => {
    db.query("DELETE FROM notes WHERE id = ?", [req.params.id], (err, result) => {
        if (err) return res.status(500).json({ error: "Hiba a törlésnél" });
        res.json({ message: "Törölve!" });
    });
});

// Indítás - 0.0.0.0-on figyel, hogy a hálózatról (mobilról) is elérd
app.listen(3000, '0.0.0.0', () => {
    console.log("-----------------------------------------");
    console.log("Szerver fut: http://localhost:3000");
    console.log("Az adatbázis (HeidiSQL) készen áll!");
    console.log("-----------------------------------------");
});