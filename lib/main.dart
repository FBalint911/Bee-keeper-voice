import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Notes App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthPage(),
    );
  }
}

// --- 1. AUTH OLDAL ---
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  // Web/Chrome: http://localhost:3000 | Android Emulátor: http://10.0.2.2:3000
  final String baseUrl = '  https://conception-tinglier-cyclonically.ngrok-free.dev ';

  Future<void> _authenticate(String type) async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$type'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userController.text,
          "password": _passController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (type == 'login') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => NotesPage(userId: data['user']['id'], baseUrl: baseUrl)
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sikeres regisztráció! Lépj be!")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? "Hiba történt")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Szerver hiba!")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Belépés")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(controller: _userController, decoration: const InputDecoration(labelText: "Felhasználónév", prefixIcon: Icon(Icons.person))),
            TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "Jelszó", prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 30),
            if (_isLoading) const CircularProgressIndicator()
            else ...[
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _authenticate('login'), child: const Text("BELÉPÉS"))),
              TextButton(onPressed: () => _authenticate('register'), child: const Text("Regisztráció")),
            ]
          ],
        ),
      ),
    );
  }
}

// --- 2. JEGYZETELŐ OLDAL HANGGAL ---
class NotesPage extends StatefulWidget {
  final int userId;
  final String baseUrl;
  const NotesPage({super.key, required this.userId, required this.baseUrl});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List notes = [];
  final TextEditingController _noteController = TextEditingController();
  
  // Hangfelismerés setup
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _fetchNotes();
  }

  // DIKTÁLÁS FUNKCIÓ
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Státusz: $status'),
        onError: (error) => print('Hiba: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _noteController.text = result.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _fetchNotes() async {
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/notes/${widget.userId}'));
      if (response.statusCode == 200) {
        setState(() => notes = jsonDecode(response.body));
      }
    } catch (e) {
      print("Hiba a lekérésnél: $e");
    }
  }

  Future<void> _addNote() async {
    if (_noteController.text.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/notes'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": widget.userId,
          "title": "Jegyzet",
          "content": _noteController.text,
        }),
      );
      if (response.statusCode == 200) {
        _noteController.clear();
        _fetchNotes();
      }
    } catch (e) {
      print("Hiba a mentésnél: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jegyzeteim"),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pop(context))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: "Írj vagy diktálj...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Mikrofon gomb
                CircleAvatar(
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                  child: IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                    onPressed: _listen,
                  ),
                ),
                const SizedBox(width: 10),
                // Mentés gomb
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _addNote,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.notes),
                  title: Text(notes[index]['content'] ?? ""),
                  subtitle: Text(notes[index]['created_at']?.toString().substring(0, 10) ?? ""),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}