import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force landscape
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
    return const ControllerApp();
  }
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),
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

class _ControllerScreenState extends State<ControllerScreen> {
  String ipAddress = 'Loading...';
  String connectionStatus = 'Waiting to connect...';
  bool isConnected = false;
  ServerSocket? server;
  final int port = 5000; // Changed port number
  List<Socket> clients = [];
  Socket? activeClient;
  Map<String, String> buttonChars = {
    'forward': 'W',
    'backward': 'S',
    'left': 'A',
    'right': 'D',
    'action1': 'X',
    'action2': 'Y',
  };

  @override
  void initState() {
    super.initState();
    initializeServer();
    getIPAddress();
    loadSettings();
  }

  Future<void> getIPAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      final hotspotIp = await info.getWifiIP(); // Assuming hotspot IP is the same as WiFi IP
      setState(() {
        ipAddress = hotspotIp != null ? '$hotspotIp:$port' : (wifiIp != null ? '$wifiIp:$port' : 'Not found');
      });
    } catch (e) {
      setState(() {
        ipAddress = 'Error getting IP';
      });
    }
  }

  Future<void> initializeServer() async {
    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      server!.listen((Socket client) {
        setState(() {
          clients.add(client);
          isConnected = true;
          connectionStatus = 'Connected!';
          activeClient = client;
        });

        client.listen(
          (data) {
            print('Received: ${String.fromCharCodes(data)}');
          },
          onError: (error) {
            handleDisconnection(client);
          },
          onDone: () {
            handleDisconnection(client);
          },
        );
      });
    } catch (e) {
      setState(() {
        connectionStatus = 'Server Error: $e';
      });
    }
  }

  void handleDisconnection(Socket client) {
    setState(() {
      clients.remove(client);
      if (clients.isEmpty) {
        isConnected = false;
        connectionStatus = 'ESP32 Disconnected - Waiting for reconnection...';
      }
    });
    client.close();
  }

  void sendCharacter(String character) {
    if (isConnected && activeClient != null) {
      activeClient!.write(character);
    } else {
      setState(() {
        connectionStatus = 'Not connected to ESP32';
      });
    }
  }

  void handleButtonPress(String character) {
    sendCharacter(character);
  }

  void handleButtonRelease() {
    sendCharacter('S'); // Stop signal
  }

  void handleActionButtonPress(String character) {
    sendCharacter(character);
  }

  void handleActionButtonRelease(String character) {
    sendCharacter(character); // Send character again on release
  }

  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      buttonChars = {
        'forward': prefs.getString('forward') ?? 'W',
        'backward': prefs.getString('backward') ?? 'S',
        'left': prefs.getString('left') ?? 'A',
        'right': prefs.getString('right') ?? 'D',
        'action1': prefs.getString('action1') ?? 'X',
        'action2': prefs.getString('action2') ?? 'Y',
      };
    });
  }

  void showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Button Settings'),
        content: SingleChildScrollView(
          child: Column(
            children: buttonChars.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                trailing: SizedBox(
                  width: 50,
                  child: TextField(
                    maxLength: 1,
                    controller: TextEditingController(text: entry.value),
                    onChanged: (value) async {
                      if (value.isNotEmpty) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(entry.key, value);
                        setState(() {
                          buttonChars[entry.key] = value;
                        });
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bot Controller'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: showSettingsDialog,
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'IP Address: $ipAddress',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  connectionStatus,
                  style: TextStyle(
                    fontSize: 18,
                    color: isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTapDown: (_) => handleButtonPress(buttonChars['forward']!),
                    onTapUp: (_) => handleButtonRelease(),
                    onTapCancel: () => handleButtonRelease(),
                    child: const CustomButton(character: '↑', color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTapDown: (_) => handleButtonPress(buttonChars['left']!),
                        onTapUp: (_) => handleButtonRelease(),
                        onTapCancel: () => handleButtonRelease(),
                        child: const CustomButton(character: '←', color: Colors.orange),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTapDown: (_) => handleButtonPress(buttonChars['right']!),
                        onTapUp: (_) => handleButtonRelease(),
                        onTapCancel: () => handleButtonRelease(),
                        child: const CustomButton(character: '→', color: Colors.purple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTapDown: (_) => handleButtonPress(buttonChars['backward']!),
                    onTapUp: (_) => handleButtonRelease(),
                    onTapCancel: () => handleButtonRelease(),
                    child: const CustomButton(character: '↓', color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTapDown: (_) => handleActionButtonPress(buttonChars['action1']!),
                    onTapUp: (_) => handleActionButtonRelease(buttonChars['action1']!),
                    onTapCancel: () => handleActionButtonRelease(buttonChars['action1']!),
                    child: const CustomButton(character: 'A1', color: Colors.green),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTapDown: (_) => handleActionButtonPress(buttonChars['action2']!),
                    onTapUp: (_) => handleActionButtonRelease(buttonChars['action2']!),
                    onTapCancel: () => handleActionButtonRelease(buttonChars['action2']!),
                    child: const CustomButton(character: 'A2', color: Colors.yellow),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    server?.close();
    for (var client in clients) {
      client.close();
    }
    super.dispose();
  }
}

class CustomButton extends StatelessWidget {
  final String character;
  final Color color;

  const CustomButton({super.key, required this.character, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          character,
          style: const TextStyle(fontSize: 20, color: Colors.white),
        ),
      ),
    );
  }
}