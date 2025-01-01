import 'package:custombot_control/Joysticks/action_button.dart';
import 'package:custombot_control/Joysticks/classic_joystick.dart';
import 'package:custombot_control/Joysticks/minimal_joystick.dart';
import 'package:custombot_control/Joysticks/modern_joystick.dart';
import 'package:custombot_control/Joysticks/neo_joystick.dart';
import 'package:custombot_control/Joysticks/arcade_joystick.dart';
import 'package:custombot_control/Joysticks/small_buttons_joystick.dart';
import 'package:custombot_control/Joysticks/close_buttons_joystick.dart';
import 'package:custombot_control/Joysticks/distant_buttons_joystick.dart';
import 'package:custombot_control/screens/login_screen.dart';
import 'package:custombot_control/services/auth_service.dart';
import 'package:custombot_control/services/firebase_api.dart';
import 'package:custombot_control/services/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initializeNotifications();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Controller',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardTheme: CardTheme(
          color: const Color(0xFF2D2D2D),
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const ControllerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with SingleTickerProviderStateMixin {
  String ipAddress = 'Loading...';
  bool isConnected = false;
  bool isServerOn = false;
  late AnimationController _controllerIconController;
  int selectedJoystickStyle = 0;
  IOWebSocketChannel? channel;
  final int port = 5000;
  String manualIp = '';
  HttpServer? wsServer;
  List<WebSocketChannel> connectedClients = [];
  final AuthService _authService = AuthService();

  Map<String, String> buttonChars = {
    'forward': 'W',
    'backward': 'B',
    'left': 'A',
    'right': 'D',
    'action1': 'X',
    'action2': 'Y',
  };

  final List<Widget Function(BuildContext, Map<String, Function>)>
      joystickStyles = [
    (context, callbacks) => ClassicJoystick(callbacks: callbacks),
    (context, callbacks) => ModernJoystick(callbacks: callbacks),
    (context, callbacks) => MinimalJoystick(callbacks: callbacks),
    (context, callbacks) => NeoJoystick(callbacks: callbacks),
    (context, callbacks) => ArcadeJoystick(callbacks: callbacks),
    (context, callbacks) => SmallButtonsJoystick(callbacks: callbacks),
    (context, callbacks) => CloseButtonsJoystick(callbacks: callbacks),
    (context, callbacks) => DistantButtonsJoystick(callbacks: callbacks),
  ];

  final List<String> joystickNames = [
    'Classic',
    'Modern',
    'Minimal',
    'Neo',
    'Arcade',
    'SmallButtons',
    'CloseButtons',
    'DistantButtons',
  ];

  @override
  void initState() {
    super.initState();
    _controllerIconController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    getIPAddress();
    loadSettings();
    initializeWebSocket();
  }

  Widget _buildSettingField(String label, String key) {
    return ListTile(
      title: Text(label),
      trailing: SizedBox(
        width: 50,
        child: TextField(
          maxLength: 1,
          controller: TextEditingController(text: buttonChars[key]),
          onChanged: (value) async {
            if (value.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(key, value.toUpperCase());
              setState(() {
                buttonChars[key] = value.toUpperCase();
              });
            }
          },
          decoration: const InputDecoration(
            counterText: "",
          ),
        ),
      ),
    );
  }

  Widget _buildIpField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Manual IP',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: TextEditingController(text: manualIp),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('manualIp', value);
                setState(() {
                  manualIp = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      buttonChars = {
        'forward': prefs.getString('forward')?.toUpperCase() ?? 'W',
        'backward': prefs.getString('backward')?.toUpperCase() ?? 'S',
        'left': prefs.getString('left')?.toUpperCase() ?? 'A',
        'right': prefs.getString('right')?.toUpperCase() ?? 'D',
        'action1': prefs.getString('action1')?.toUpperCase() ?? 'X',
        'action2': prefs.getString('action2')?.toUpperCase() ?? 'Y',
      };
      selectedJoystickStyle = prefs.getInt('joystickStyle') ?? 0;
      manualIp = prefs.getString('manualIp') ?? '';
    });
  }

  void showSettingsDialog(BuildContext context) {
    showDialog(
      context:
          context, // error can be solved by passing context as a parameter or by using a global key or by using a state management solution
      builder: (context) => AlertDialog(
        title: const Text(
          'Controller Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingField('Forward', 'forward'),
              _buildSettingField('Backward', 'backward'),
              _buildSettingField('Left', 'left'),
              _buildSettingField('Right', 'right'),
              _buildSettingField('Action X', 'action1'),
              _buildSettingField('Action Y', 'action2'),
              _buildIpField(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> getIPAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      setState(() {
        ipAddress = wifiIp != null ? '$wifiIp:$port' : 'Not found';
      });
    } catch (e) {
      setState(() {
        ipAddress = 'Error getting IP';
      });
    }
  }

  void showJoystickSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Select Joystick Style'),
        content: SizedBox(
          width: 300,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: joystickStyles.length,
            itemBuilder: (context, index) => InkWell(
              onTap: () {
                setState(() {
                  selectedJoystickStyle = index;
                  saveJoystickStyle(index);
                });
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedJoystickStyle == index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((0.1 * 255).toInt()),
                      Theme.of(context)
                          .colorScheme
                          .secondary
                          .withAlpha((0.1 * 255).toInt()),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gamepad,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      joystickNames[index],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> initializeWebSocket() async {
    if (!isServerOn) return;

    try {
      // Create WebSocket server
      var handler = webSocketHandler((WebSocketChannel socket) {
        setState(() {
          connectedClients.add(socket);
          isConnected = true;
          _controllerIconController.stop();
        });

        socket.stream.listen(
          (message) {
            // Handle any incoming messages if needed
          },
          onDone: () {
            setState(() {
              connectedClients.remove(socket);
              if (connectedClients.isEmpty) {
                isConnected = false;
                _controllerIconController.repeat(reverse: true);
              }
            });
          },
        );
      });

      wsServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
      print(
          'WebSocket server running on ws://${wsServer!.address.address}:$port');
    } catch (e) {
      print('Error starting WebSocket server: $e');
      setState(() {
        isConnected = false;
        _controllerIconController.repeat(reverse: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withAlpha((0.3 * 255).toInt()),
                colorScheme.secondaryContainer.withAlpha((0.3 * 255).toInt()),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ipAddress, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              FadeTransition(
                opacity: _controllerIconController,
                child: Icon(
                  Icons.gamepad,
                  size: 24,
                  color: isConnected ? colorScheme.primary : colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.download),
          onPressed: getIPAddress,
        ),
        actions: [
          IconButton(
            icon: Icon(_authService.currentUser != null
                ? Icons.person_remove_outlined
                : Icons.person_sharp),
            onPressed: () {
              if (_authService.currentUser == null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                ).then((_) {
                  setState(() {});
                });
              } else {
                _authService.signOut().then((_) {
                  setState(() {});
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.leak_add_sharp),
            onPressed: () => {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Control panel at the top
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildControlButton(
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () => showSettingsDialog(context),
                      ),
                      const SizedBox(width: 16),
                      _buildControlButton(
                        icon: Icons.gamepad,
                        label: 'Style',
                        onTap: showJoystickSelector,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Server', style: TextStyle(fontSize: 12)),
                          Switch(
                            value: isServerOn,
                            onChanged: toggleServer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Joystick area with background
          Positioned(
            left: 20,
            bottom: 20,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primaryContainer.withAlpha((0.2 * 255).toInt()),
                    Colors.transparent,
                  ],
                ),
              ),
              child: joystickStyles[selectedJoystickStyle](
                context,
                {
                  'onForward': () => sendCharacter(buttonChars['forward']!),
                  'onBackward': () => sendCharacter(buttonChars['backward']!),
                  'onLeft': () => sendCharacter(buttonChars['left']!),
                  'onRight': () => sendCharacter(buttonChars['right']!),
                  'onRelease': () => sendCharacter('S'),
                },
              ),
            ),
          ),

          // Action buttons with enhanced styling
          Positioned(
            right: 20,
            bottom: 20,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colorScheme.secondaryContainer
                        .withAlpha((0.2 * 255).toInt()),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActionButton(
                    label: 'X',
                    color: colorScheme.primaryContainer,
                    onPressed: () => sendCharacter(buttonChars['action1']!),
                  ),
                  const SizedBox(width: 20),
                  ActionButton(
                    label: 'Y',
                    color: colorScheme.secondaryContainer,
                    onPressed: () => sendCharacter(buttonChars['action2']!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void toggleServer(bool value) async {
    setState(() {
      isServerOn = value;
    });
    if (isServerOn) {
      await initializeWebSocket();
    } else {
      for (var client in connectedClients) {
        client.sink.close();
      }
      connectedClients.clear();
      await wsServer?.close();
      wsServer = null;
      setState(() {
        isConnected = false;
        _controllerIconController.repeat(reverse: true);
      });
    }
  }

  void sendCharacter(String character) {
    if (isConnected && connectedClients.isNotEmpty) {
      for (var client in connectedClients) {
        client.sink.add(character);
      }
    }
  }

  @override
  void dispose() {
    _controllerIconController.dispose();
    for (var client in connectedClients) {
      client.sink.close();
    }
    wsServer?.close();
    super.dispose();
  }
}

Future<void> saveJoystickStyle(int style) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('joystickStyle', style);
}
