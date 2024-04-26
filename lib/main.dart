// ignore_for_file: depend_on_referenced_packages, use_key_in_widget_constructors, prefer_final_fields, library_private_types_in_public_api, prefer_const_constructors, avoid_print

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: SafeArea(
        child: CameraScreen(),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  TextEditingController _apiUrlController = TextEditingController();
  TextEditingController _idController = TextEditingController();
  String? _savedId;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
    );
    await _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final apiUrl = _apiUrlController.text;
    if (apiUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter an API URL'),
        ),
      );
      return;
    }
    try {
      await _initializeControllerFuture;
      await _initializeCamera();
      setState(() {
        _isRecording = true;
      });
      Timer.periodic(Duration(seconds: 1), (timer) async {
        if (!_isRecording) {
          timer.cancel();
          return;
        }
        XFile imageFile = await _controller.takePicture();
        await _sendFrameToApi(File(imageFile.path), apiUrl);
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _sendFrameToApi(File imageFile, String url) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      // Files data to the request
      request.files.add(
        http.MultipartFile(
          'image', // API parameter name
          imageFile.readAsBytes().asStream(), // file stream
          imageFile.lengthSync(), // Length
          filename: imageFile.path.split('/').last,
          // contentType: MediaType('image', 'jpeg'),
        ),
      );

      request.fields['camera_id'] = _savedId ?? "0"; // TODO Add camera ID here.

      var response = await request.send();
      if (response.statusCode == 200) {
        print('Image sent successfully');
      } else {
        print('Failed to send image');
      }
    } catch (e) {
      print(e);
    }
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
  }

  void _saveId() {
    setState(() {
      _savedId = _idController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Camera app',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(10.0),
            child: TextField(
              controller: _apiUrlController,
              decoration: InputDecoration(
                labelText: 'Enter API URL',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: 'Enter ID',
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _saveId,
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.white30),
                  ),
                  child: Text('Save'),
                )
              ],
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Column(
                    children: <Widget>[
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: CameraPreview(_controller),
                        ),
                      ),
                      if (_savedId != null) Text('Camera ID: $_savedId'),
                      ElevatedButton(
                        onPressed:
                            _isRecording ? _stopRecording : _startRecording,
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all<Color>(Colors.white30),
                        ),
                        child: Text(_isRecording ? 'Stop' : 'Start'),
                      )
                    ],
                  );
                } else {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
