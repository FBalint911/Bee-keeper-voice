const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcrypt');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
const PORT = 3000;

// Middleware-ek beállítása
app.use(cors()); // Engedélyezi, hogy a Flutter app (akár webes is) elérje a szervert
app.use(bodyParser.json()); // Feldolgozza a JSON formátumú adatokat

// 2. Lépés: Kapcsolódás a XAMPP MySQL-hez
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',      // XAMPP alapértelmezett felhasználó
    password: '',      // XAMPP-nél alapból nincs jelszó
    database: 'flutter_auth' // Ezt hoztuk létre a phpMyAdmin-ban
});

db.connect((err) => {
    if (err) {
        console.error('Hiba a MySQL csatlakozásnál: ' + err.stack);
        return;
    }
    console.log('Sikeresen kapcsolódva a MySQL adatbázishoz (ID: ' + db.threadId + ')');
});

// 3. Lépés: REGISZTRÁCIÓ (POST /register)
app.post('/register', async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ error: "Hiányzó adatok!" });
    }

    try {
        // Jelszó titkosítása (ne tároljunk sima szöveget!)
        const hashedPassword = await bcrypt.hash(password, 10);

        const sql = "INSERT INTO users (username, password) VALUES (?, ?)";
        db.query(sql, [username, hashedPassword], (err, result) => {
            if (err) {
                if (err.code === 'ER_DUP_ENTRY') {
                    return res.status(400).json({ error: "Ez a felhasználónév már foglalt!" });
                }
                return res.status(500).json({ error: "Adatbázis hiba történt." });
            }
            res.status(200).json({ message: "Sikeres regisztráció!" });
        });
    } catch (error) {
        res.status(500).json({ error: "Szerver hiba." });
    }
});

// 4. Lépés: BEJELENTKEZÉS (POST /login)
app.post('/login', (req, res) => {
    const { username, password } = req.body;

    const sql = "SELECT * FROM users WHERE username = ?";
    db.query(sql, [username], async (err, results) => {
        if (err) return res.status(500).json({ error: "Lekérdezési hiba." });

        if (results.length === 0) {
            return res.status(404).json({ error: "Nincs ilyen felhasználó!" });
        }

        const user = results[0];

        // Titkosított jelszó összehasonlítása
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

app.listen(3000, '0.0.0.0', () => {
    console.log("Szerver fut: http://172.16.0.168:3000");
});

// JEGYZETEK LEKÉRÉSE
app.get('/notes/:userId', (req, res) => {
    const userId = req.params.userId;
    const sql = "SELECT * FROM notes WHERE user_id = ? ORDER BY created_at DESC";
    db.query(sql, [userId], (err, results) => {
        if (err) return res.status(500).json({ error: "Hiba a lekérdezésnél" });
        res.json(results);
    });
});

app.post('/notes', (req, res) => {
    const { userId, title, content } = req.body;
    console.log("Mentési kérés érkezett:", req.body); // Ez kiírja a terminálba, amit a Flutter küld

    const sql = "INSERT INTO notes (user_id, title, content) VALUES (?, ?, ?)";
    db.query(sql, [userId, title, content], (err, result) => {
        if (err) {
            console.error("SQL hiba mentéskor:", err); // Itt fogjuk látni, ha rossz a tábla neve
            return res.status(500).json({ error: "Hiba a mentésnél" });
        }
        console.log("Jegyzet sikeresen mentve, ID:", result.insertId);
        res.json({ message: "Jegyzet elmentve!", noteId: result.insertId });
    });
});