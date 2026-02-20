import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http; // <--- NUEVO IMPORT

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV App Pro 2026',
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ContentItem {
  String name, url, imageUrl;
  ContentItem({required this.name, required this.url, required this.imageUrl});
  Map<String, dynamic> toMap() => {'name': name, 'url': url, 'imageUrl': imageUrl};
  factory ContentItem.fromMap(Map<String, dynamic> map) =>
      ContentItem(name: map['name'] ?? '', url: map['url'] ?? '', imageUrl: map['imageUrl'] ?? '');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ContentItem> channels = [];
  List<ContentItem> movies = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  // MODIFICADO: Ahora carga desde GitHub y tiene memoria local (caché)
  Future<void> _loadData() async {
    const String urlCanales = "https://raw.githubusercontent.com/rikus4416-stack/tv/main/assets/canales.json";
    const String urlPeliculas = "https://raw.githubusercontent.com/rikus4416-stack/tv/main/assets/peliculas.json";

    final prefs = await SharedPreferences.getInstance();

    try {
      // Intentamos bajar canales de GitHub (tiempo de espera de 8 seg)
      final resCanales = await http.get(Uri.parse(urlCanales)).timeout(const Duration(seconds: 8));
      if (resCanales.statusCode == 200) {
        await prefs.setString('channels_data', resCanales.body);
      }

      // Intentamos bajar películas de GitHub
      final resPelis = await http.get(Uri.parse(urlPeliculas)).timeout(const Duration(seconds: 8));
      if (resPelis.statusCode == 200) {
        await prefs.setString('movies_data', resPelis.body);
      }
    } catch (e) {
      debugPrint("Error de red, cargando última lista guardada: $e");
    }

    // Ahora leemos lo que sea que haya quedado en memoria (lo nuevo o lo anterior)
    final String? channelsPref = prefs.getString('channels_data');
    final String? moviesPref = prefs.getString('movies_data');

    if (channelsPref != null && channelsPref.isNotEmpty) {
      channels = (jsonDecode(channelsPref) as List).map((e) => ContentItem.fromMap(e)).toList();
    } else {
      // Si la app es nueva y no hay internet, lee el archivo de la carpeta assets
      try {
        String jsonString = await rootBundle.loadString('assets/canales.json');
        channels = (jsonDecode(jsonString) as List).map((e) => ContentItem.fromMap(e)).toList();
      } catch (e) { debugPrint(e.toString()); }
    }

    if (moviesPref != null && moviesPref.isNotEmpty) {
      movies = (jsonDecode(moviesPref) as List).map((e) => ContentItem.fromMap(e)).toList();
    } else {
      try {
        String jsonString = await rootBundle.loadString('assets/peliculas.json');
        movies = (jsonDecode(jsonString) as List).map((e) => ContentItem.fromMap(e)).toList();
      } catch (e) { debugPrint(e.toString()); }
    }
    
    setState(() {});
  }

  void _navigateToPlayer(List<ContentItem> items, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullScreenPlayer(items: items, initialIndex: index)),
    );
  }

  Widget _buildGrid(List<ContentItem> items) {
    if (items.isEmpty) return const Center(child: CircularProgressIndicator());
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Focus(
          autofocus: index == 0,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
              _navigateToPlayer(items, index);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) {
              final bool hasFocus = Focus.of(context).hasFocus;
              return GestureDetector(
                onTap: () => _navigateToPlayer(items, index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: hasFocus ? Colors.blueAccent : Colors.white24, width: hasFocus ? 5 : 1),
                    image: DecorationImage(image: NetworkImage(items[index].imageUrl), fit: BoxFit.cover),
                  ),
                  child: Stack(
                    children: [
                      if (hasFocus) Container(alignment: Alignment.center, color: Colors.black26, child: const Icon(Icons.play_circle_fill, color: Colors.blueAccent, size: 40)),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity, color: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(items[index].name, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TV Pro 2026'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'CANALES'), Tab(text: 'PELÍCULAS')]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildGrid(channels), _buildGrid(movies)],
      ),
    );
  }
}

class FullScreenPlayer extends StatefulWidget {
  final List<ContentItem> items;
  final int initialIndex;
  const FullScreenPlayer({super.key, required this.items, required this.initialIndex});
  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  late int _currentIndex;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _setupPlayer();
  }

  void _setupPlayer() {
    final dynamic native = player.platform;
    try {
      // SE MANTIENEN TUS AJUSTES DE VELOCIDAD PERFECTOS
      native.setProperty('network-caching', '200'); 
      native.setProperty('probedata', '16384');      
      native.setProperty('analyzeduration', '500'); 
      native.setProperty('fpsprobesize', '0');       
      native.setProperty('fastseek', 'yes');
      native.setProperty('rtsp_transport', 'udp');
      native.setProperty('framedrop', 'vo');         
      native.setProperty('tls-verify', 'no');        
      native.setProperty('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
    } catch (e) {
      debugPrint("Error de motor: $e");
    }

    player.open(Media(widget.items[_currentIndex].url));
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _changeMedia(int index) {
    if (index < 0 || index >= widget.items.length) return;
    setState(() {
      _currentIndex = index;
      player.open(Media(widget.items[_currentIndex].url));
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    player.dispose();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const ScrollIntent(direction: AxisDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const ScrollIntent(direction: AxisDirection.down),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ScrollIntent: CallbackAction<ScrollIntent>(onInvoke: (intent) {
            if (intent.direction == AxisDirection.up) {
              _changeMedia(_currentIndex - 1);
            } else {
              _changeMedia(_currentIndex + 1);
            }
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: GestureDetector(
              onTap: () {
                setState(() => _showControls = !_showControls);
                if (_showControls) _startHideControlsTimer();
              },
              child: Stack(
                children: [
                  Center(child: Video(controller: controller)),
                  if (_showControls)
                    Container(
                      color: Colors.black45,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                            title: Text(widget.items[_currentIndex].name),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(icon: const Icon(Icons.skip_previous, size: 40, color: Colors.white), onPressed: () => _changeMedia(_currentIndex - 1)),
                                const SizedBox(width: 40),
                                IconButton(
                                  icon: Icon(player.state.playing ? Icons.pause_circle : Icons.play_circle, size: 70, color: Colors.blueAccent),
                                  onPressed: () {
                                    player.playOrPause();
                                    setState(() {});
                                  },
                                ),
                                const SizedBox(width: 40),
                                IconButton(icon: const Icon(Icons.skip_next, size: 40, color: Colors.white), onPressed: () => _changeMedia(_currentIndex + 1)),
                              ],
                            ),
                          ),
                        ],
                      ),
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