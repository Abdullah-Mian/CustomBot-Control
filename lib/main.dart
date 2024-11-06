// lib/main.dart
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
  String connectionStatus = 'Waiting for ESP32...';
  bool isConnected = false;
  List<Widget> controls = [];
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
          connectionStatus = 'ESP32 Connected!';
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

  void addJoystick() {
    setState(() {
      controls.add(
        Draggable(
          feedback: const JoystickControl(),
          childWhenDragging: Container(),
          child: const JoystickControl(),
        ),
      );
    });
  }

  void addButton() {
    setState(() {
      controls.add(
        Draggable(
          feedback: const CustomButton(),
          childWhenDragging: Container(),
          child: const CustomButton(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Controller'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: isConnected ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            child: Column(
              children: [
                if (!isConnected) Text(
                  'IP Address: $ipAddress\nPort: $port',
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
            child: DragTarget<int>(
              builder: (context, _, __) {
                return Stack(
                  children: controls,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: addJoystick,
            child: const Icon(Icons.gamepad),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            onPressed: addButton,
            child: const Icon(Icons.smart_button),
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

class JoystickControl extends StatefulWidget {
  const JoystickControl({super.key});

  @override
  State<JoystickControl> createState() => _JoystickControlState();
}

class _JoystickControlState extends State<JoystickControl> {
  double size = 100;
  String character = 'W';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          size = size * details.scale;
        });
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: TextField(
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'Key',
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                setState(() {
                  character = value[0];
                });
              }
            },
          ),
        ),
      ),
    );
  }
}

class CustomButton extends StatefulWidget {
  const CustomButton({super.key});

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  double width = 80;
  double height = 80;
  String character = 'X';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          width = width * details.scale;
          height = height * details.scale;
        });
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: TextField(
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'Key',
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                setState(() {
                  character = value[0];
                });
              }
            },
          ),
        ),
      ),
    );
  }
}