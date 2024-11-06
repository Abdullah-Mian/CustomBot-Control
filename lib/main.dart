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
  final int port = 8080;
  List<Socket> clients = [];
  Socket? activeClient;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bot Controller'),
        centerTitle: true,
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildConnectionStatus(),
                const SizedBox(height: 20),
                const Text(
                  'Controls',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
                buildControlButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade200 : Colors.red.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            'IP Address: $ipAddress:$port',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            connectionStatus,
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildControlButtons() {
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => handleButtonPress('W'),
          onTapUp: (_) => handleButtonRelease(),
          onTapCancel: () => handleButtonRelease(),
          child: const CustomButton(character: 'Forward', color: Colors.blue),
        ),
        const SizedBox(height: 15),
        GestureDetector(
          onTapDown: (_) => handleButtonPress('A'),
          onTapUp: (_) => handleButtonRelease(),
          onTapCancel: () => handleButtonRelease(),
          child: const CustomButton(character: 'Left', color: Colors.orange),
        ),
        const SizedBox(height: 15),
        GestureDetector(
          onTapDown: (_) => handleButtonPress('D'),
          onTapUp: (_) => handleButtonRelease(),
          onTapCancel: () => handleButtonRelease(),
          child: const CustomButton(character: 'Right', color: Colors.purple),
        ),
        const SizedBox(height: 15),
        GestureDetector(
          onTapDown: (_) => handleButtonPress('S'),
          onTapUp: (_) => handleButtonRelease(),
          onTapCancel: () => handleButtonRelease(),
          child: const CustomButton(character: 'Back', color: Colors.red),
        ),
      ],
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
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: Offset(0, 4),
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
