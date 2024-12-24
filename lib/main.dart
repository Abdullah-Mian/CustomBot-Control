import 'package:custombot_control/action_button.dart';
import 'package:custombot_control/classic_joystick.dart';
import 'package:custombot_control/minimal_joystick.dart';
import 'package:custombot_control/modern_joystick.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
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

  Map<String, String> buttonChars = {
    'forward': 'W',
    'backward': 'S',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: TextEditingController(
                  text: buttonChars[key]),
              maxLength: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onChanged: (value) async {
                if (value.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(key, value.toUpperCase());
                  setState(() {
                    buttonChars[key] = value.toUpperCase();
                  });
                }
              },
            ),
          ),
        ],
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
        title: const Text('Select Joystick Style'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              joystickStyles.length,
              (index) => ListTile(
                leading: Radio<int>(
                  value: index,
                  groupValue: selectedJoystickStyle,
                  onChanged: (value) {
                    setState(() {
                      selectedJoystickStyle = value!;
                      Navigator.pop(context);
                    });
                  },
                ),
                title: Text('Style ${index + 1}'),
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
      print('WebSocket server running on ws://${wsServer!.address.address}:$port');
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ipAddress),
            const SizedBox(width: 10),
            FadeTransition(
              opacity: _controllerIconController,
              child: const Icon(Icons.gamepad, size: 24),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Left side controls
          Center(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => showSettingsDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.gamepad),
                      onPressed: showJoystickSelector,
                    ),
                    Switch(
                      value: isServerOn,
                      onChanged: (value) => toggleServer(value),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main controller area
          Positioned(
            left: 20,
            bottom: 20,
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

          // Right side action buttons
          Positioned(
            right: 20,
            bottom: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActionButton(
                  label: 'X',
                  color: Colors.green,
                  onPressed: () => sendCharacter(buttonChars['action1']!),
                ),
                const SizedBox(width: 20),
                ActionButton(
                  label: 'Y',
                  color: Colors.blue,
                  onPressed: () => sendCharacter(buttonChars['action2']!),
                ),
              ],
            ),
          ),
        ],
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
