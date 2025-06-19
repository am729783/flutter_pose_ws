import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late WebSocketChannel _channel;
  String feedback = "";
  int reps = 0;
  String stage = "";

  @override
  void initState() {
    super.initState();
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://fc-1-q6lj.onrender.com/ws'),
    );
    _channel.stream.listen((data) {
      final decoded = json.decode(data);
      setState(() {
        reps = decoded['counter'];
        stage = decoded['stage'] ?? "";
        feedback = decoded['feedback'] ?? "";
      });
    });
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller.initialize();
    setState(() {});
  }

  Future<void> _captureAndSendFrame() async {
    if (!_controller.value.isInitialized) return;
    final XFile file = await _controller.takePicture();
    final bytes = await File(file.path).readAsBytes();
    _channel.sink.add(bytes);
  }

  @override
  void dispose() {
    _controller.dispose();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gym Form Tracker")),
      body: Column(
        children: [
          _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: CameraPreview(_controller),
                )
              : Center(child: CircularProgressIndicator()),
          ElevatedButton(
            onPressed: _captureAndSendFrame,
            child: Text("Send Frame"),
          ),
          SizedBox(height: 20),
          Text("Reps: \$reps"),
          Text("Stage: \$stage"),
          Text("Feedback: \$feedback", style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}