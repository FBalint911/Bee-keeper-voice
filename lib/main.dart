import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';

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
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB300),
          primary: const Color(0xFFFFB300),
          secondary: const Color(0xFF263238),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// --- MODERN ANALIZÁTOR ---
enum HiveStatus { ok, warning, danger }

class HiveAnalyzer {
  static const map = {
    HiveStatus.danger: ['atka', 'varroa', 'nyúlós', 'rablás', 'pusztulás'],
    HiveStatus.warning: [
      'kevés méz',
      'anyabölcső',
      'nincs fias',
      'élelemhiány',
      'moly'
    ],
  };

  static HiveStatus analyze(List<String> logs) {
    if (logs.isEmpty) return HiveStatus.ok;
    String lastLog = logs.first.toLowerCase();
    for (var word in map[HiveStatus.danger]!) {
      if (lastLog.contains(word)) return HiveStatus.danger;
    }
    for (var word in map[HiveStatus.warning]!) {
      if (lastLog.contains(word)) return HiveStatus.warning;
    }
    return HiveStatus.ok;
  }

  static Color getStatusColor(HiveStatus status) {
    switch (status) {
      case HiveStatus.danger:
        return Colors.redAccent;
      case HiveStatus.warning:
        return Colors.orangeAccent;
      case HiveStatus.ok:
        return Colors.greenAccent;
    }
  }
}

// --- BEJELENTKEZÉS OLDAL ---
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
      String? savedPass = prefs.getString('user_$user');
      if (savedPass == pass) {
        if (!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => BeehiveListPage(username: user)));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Hibás adatok!")));
      }
    } else {
      await prefs.setString('user_$user', pass);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Sikeres regisztráció! Jelentkezz be.")));
      setState(() => _isLogin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
              begin: Alignment.topLeft),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 350),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 20)
                  ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hive_rounded,
                      size: 80, color: Color(0xFFFFB300)),
                  const SizedBox(height: 10),
                  Text(_isLogin ? "BEE-LOG LOGIN" : "ÚJ FIÓK",
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _userController,
                      decoration: const InputDecoration(
                          labelText: "Felhasználónév",
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  TextField(
                      controller: _passController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: "Jelszó",
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder())),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: _handleAuth,
                    child: Text(_isLogin ? "BELÉPÉS" : "REGISZTRÁCIÓ"),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin
                        ? "Nincs még fiókom, regisztrálok"
                        : "Már van fiókom, belépek"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- FŐOLDAL: FEKVŐ MÓDRA OPTIMALIZÁLT FEJLÉCCEL ---
class BeehiveListPage extends StatefulWidget {
  final String username;
  const BeehiveListPage({super.key, required this.username});
  @override
  State<BeehiveListPage> createState() => _BeehiveListPageState();
}

class _BeehiveListPageState extends State<BeehiveListPage> {
  List<String> hives = [];
  Map<String, HiveStatus> statuses = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedHives =
        prefs.getStringList('hives_${widget.username}') ?? [];
    Map<String, HiveStatus> loadedStatuses = {};
    for (var hive in savedHives) {
      List<String> logs =
          prefs.getStringList('logs_${widget.username}_$hive') ?? [];
      loadedStatuses[hive] = HiveAnalyzer.analyze(logs);
    }
    setState(() {
      hives = savedHives;
      statuses = loadedStatuses;
    });
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 10) return "Jó reggelt";
    if (hour < 18) return "Szép napot";
    return "Jó estét";
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isLandscape ? 80 : 140,
            pinned: true,
            backgroundColor: const Color(0xFFFFB300),
            elevation: 0,
            leading:
                const Icon(Icons.hive_rounded, color: Colors.black, size: 28),
            actions: [
              IconButton(
                  onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage())),
                  icon: const Icon(Icons.logout, color: Colors.black))
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 50, bottom: 12),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 90) {
                    return Text(
                      "${_getGreeting()}, ${widget.username}!",
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    );
                  } else {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getGreeting(),
                            style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 10,
                                fontWeight: FontWeight.w500)),
                        Text("${widget.username}!",
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Mosonmagyaróvár",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("22°C - Ideális kirepülés",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Icon(Icons.wb_sunny_rounded,
                        color: Colors.orange[400], size: 45),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text("Saját kaptáraid",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: hives.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(
                        child: Text("Még nincs kaptárad. Adj hozzá egyet!")))
                : SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildModernHiveCard(hives[index],
                          statuses[hives[index]] ?? HiveStatus.ok, index),
                      childCount: hives.length,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: Colors.black,
        label: const Text("Új Kaptár", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Hány új kaptár?"),
              content: TextField(
                  controller: ctrl, keyboardType: TextInputType.number),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Mégse")),
                ElevatedButton(
                    onPressed: () async {
                      int count = int.tryParse(ctrl.text) ?? 0;
                      if (count > 0) {
                        final prefs = await SharedPreferences.getInstance();
                        int start = hives.length + 1;
                        for (int i = 0; i < count; i++) {
                          hives.add("$start. sz. Kaptár");
                          start++;
                        }
                        await prefs.setStringList(
                            'hives_${widget.username}', hives);
                        if (mounted) Navigator.pop(context);
                        _loadData();
                      }
                    },
                    child: const Text("Hozzáadás")),
              ],
            ));
  }

  Widget _buildModernHiveCard(String name, HiveStatus status, int index) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => NotePage(
                    hives: hives,
                    currentIndex: index,
                    username: widget.username)));
        _loadData();
      },
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
                color: HiveAnalyzer.getStatusColor(status).withOpacity(0.4),
                width: 2)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(alignment: Alignment.center, children: [
              Icon(Icons.hexagon_rounded,
                  size: 70, color: Colors.amber.withOpacity(0.1)),
              Icon(Icons.hive_outlined, size: 35, color: Colors.amber[800]),
            ]),
            const SizedBox(height: 5),
            Text(name.split('.')[0] + ". kaptár",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
                width: 30,
                height: 4,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: HiveAnalyzer.getStatusColor(status))),
          ],
        ),
      ),
    );
  }
}

// --- JEGYZET OLDAL (HISTORY) ---
class NotePage extends StatefulWidget {
  final List<String> hives;
  final int currentIndex;
  final String username;
  const NotePage(
      {super.key,
      required this.hives,
      required this.currentIndex,
      required this.username});
  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  late int _index;
  final _noteController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
    _loadLogs();
  }

  void _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _logs = prefs.getStringList(
              'logs_${widget.username}_${widget.hives[_index]}') ??
          [];
    });
  }

  void _save() async {
    if (_noteController.text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    String ts = DateFormat('MM.dd HH:mm').format(DateTime.now());
    setState(() {
      _logs.insert(0, "[$ts] ${_noteController.text.trim()}");
      _noteController.clear();
    });
    await prefs.setStringList(
        'logs_${widget.username}_${widget.hives[_index]}', _logs);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('Hiba: $error');
          setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: "hu_HU",
          onDevice: true, // Offline mód támogatása
          listenMode: stt.ListenMode.dictation, // Hosszabb diktáláshoz
          partialResults: true,
          onResult: (val) {
            setState(() {
              _noteController.text = val.recognizedWords;
              if (val.finalResult) {
                _isListening = false;
              }
            });
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("A mikrofon nem érhető el.")),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
          backgroundColor: const Color(0xFFFFB300),
          title: Text(widget.hives[_index],
              style: const TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _logs.length,
              itemBuilder: (context, i) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                    title: Text(_logs[i]),
                    leading: const Icon(Icons.history, color: Colors.grey)),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
            child: Column(
              children: [
                TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                        hintText: "Új bejegyzés...", border: InputBorder.none)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: _listen,
                        icon: Icon(_isListening ? Icons.stop : Icons.mic,
                            color: _isListening ? Colors.red : Colors.amber,
                            size: 30)),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white),
                        onPressed: _save,
                        child: const Text("MENTÉS")),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
