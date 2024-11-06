import 'package:flutter/material.dart';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(const ControllerApp());
}

class ControllerApp extends StatelessWidget {
  const ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  final int port = 8080;
  List<Socket> clients = [];

  @override
  void initState() {
    super.initState();
    initializeServer();
    getIPAddress();
  }

  Future<void> getIPAddress() async {
    try {
      final info = NetworkInfo();
      final hotspotIp = await info.getWifiIP();
      setState(() {
        ipAddress = hotspotIp ?? 'Not found';
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
        });

        client.listen(
          (data) {
            // Handle incoming data
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
      print('Error starting server: $e');
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
    for (var client in clients) {
      client.write(character);
    }
  }
 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Bot Controller', style: TextStyle(fontWeight: FontWeight.bold))),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: isConnected ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            child: Column(
              children: [
                if (!isConnected)
                  Text(
                    'IP Address: $ipAddress: $port',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                Text(
                  connectionStatus,
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  bottom: 20,
                  child: GestureDetector(
                    onTap: () => sendCharacter('W'), // Send 'W' for joystick press
                    child: const JoystickControl(),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => {sendCharacter('A')}, // Send 'A' for Button 1
                        child: const CustomButton(character: 'A', color: Colors.red),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => sendCharacter('B'), // Send 'B' for Button 2
                        child: const CustomButton(character: 'B', color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
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

class JoystickControl extends StatelessWidget {
  const JoystickControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'W',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String character;
  final Color color;

  const CustomButton({super.key, required this.character, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          character,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
