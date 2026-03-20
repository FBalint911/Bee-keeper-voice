import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// --- BEJELENTKEZÉS ÉS REGISZTRÁCIÓ ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLogin = true;

  void _handleAuth() async {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();
    if (user.isEmpty || pass.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    if (_isLogin) {
      String? storedPass = prefs.getString('user_$user');
      if (storedPass == pass) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BeehiveListPage(username: user)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hibás adatok!")));
      }
    } else {
      await prefs.setString('user_$user', pass);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sikeres regisztráció!")));
      setState(() => _isLogin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.hive_rounded, size: 100, color: Colors.amber),
              const SizedBox(height: 20),
              Text(_isLogin ? "Belépés" : "Regisztráció", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(controller: _userController, decoration: const InputDecoration(labelText: "Felhasználónév", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: "Jelszó", border: OutlineInputBorder())),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _handleAuth,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.amber[700], foregroundColor: Colors.white),
                child: Text(_isLogin ? "BELÉPÉS" : "REGISZTRÁCIÓ"),
              ),
              TextButton(onPressed: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? "Regisztráció" : "Vissza a belépéshez")),
            ],
          ),
        ),
      ),
    );
  }
}

// --- KAPTÁR LISTA ---
class BeehiveListPage extends StatefulWidget {
  final String username;
  const BeehiveListPage({super.key, required this.username});
  @override
  State<BeehiveListPage> createState() => _BeehiveListPageState();
}

class _BeehiveListPageState extends State<BeehiveListPage> {
  List<String> hives = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hives = prefs.getStringList('hives_${widget.username}') ?? [];
    });
  }

  void _addHive() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hives.add("${hives.length + 1}. sz. Kaptár");
      prefs.setStringList('hives_${widget.username}', hives);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.username} méhese 🐝"),
        backgroundColor: Colors.amber,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())))],
      ),
      body: hives.isEmpty
          ? const Center(child: Text("Még nincs kaptárad. Adj hozzá egyet!"))
          : ListView.builder(
              itemCount: hives.length,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.settings_input_component, color: Colors.amber),
                  title: Text(hives[index]),
                  trailing: const Icon(Icons.edit_note),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotePage(hiveName: hives[index], username: widget.username))),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: _addHive, backgroundColor: Colors.amber, child: const Icon(Icons.add)),
    );
  }
}

// --- JEGYZET OLDAL ---
class NotePage extends StatefulWidget {
  final String hiveName;
  final String username;
  const NotePage({super.key, required this.hiveName, required this.username});
  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  void _loadNote() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _noteController.text = prefs.getString('note_${widget.username}_${widget.hiveName}') ?? "";
    });
  }

  void _saveNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('note_${widget.username}_${widget.hiveName}', _noteController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jegyzet mentve!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.hiveName), backgroundColor: Colors.amber),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Kaptár állapota, megjegyzések:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _noteController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(hintText: "Írj ide valamit...", border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _saveNote, icon: const Icon(Icons.save), label: const Text("MENTÉS"), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))),
          ],
        ),
      ),
    );
  }
}