import 'dart:async';

import 'package:flutter/material.dart';
import 'package:acr_cloud_sdk/acr_cloud_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACRCloud Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'ACRCloud Audio Recognition'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AcrCloudSdk _acrCloud = AcrCloudSdk();
  String _result = 'Nhấn nút để bắt đầu nhận dạng';
  bool _isRecognizing = false;
  StreamSubscription? _resultSubscription;

  @override
  void initState() {
    super.initState();
    _acrCloud.init(
      host: 'identify-ap-southeast-1.acrcloud.com', // Thay thế bằng host của bạn
      accessKey: 'feb91c05983f15166729ca304fca4b58', // Thay thế bằng access key của bạn
      accessSecret: 'brb1vdvjkhu5lKfhwbR0GwOpmVGk2y54keEZSJTZ', // Thay thế bằng access secret của bạn
      recorderConfigRate: 16000,
      recorderConfigChannels: 1,
      recMode: ACRCloudRecMode.default_mode,
    );

    _acrCloud.songModelStream.listen((songModel) {
      setState(() {
        _isRecognizing = false;
        if (songModel.status == 'OK') {
          if (songModel.metadata != null && songModel.metadata!.music!.isNotEmpty) {
            final music = songModel.metadata!.music!.first;
            _result = 'Bài hát: ${music.title}\nCa sĩ: ${music.artists!.map((artist) => artist.name).join(', ')}\nAlbum: ${music.album!.name}';
          } else {
            _result = 'Không tìm thấy kết quả.';
          }
        } else {
          _result = 'Lỗi nhận dạng: ${songModel.status} - ${songModel.toString()}';
        }
      });
    }, onError: (error) {
      setState(() {
        _isRecognizing = false;
        _result = 'Đã xảy ra lỗi: $error';
      });
    }, onDone: () {
      setState(() {
        _isRecognizing = false;
        _result = 'Nhận dạng hoàn tất.';
      });
    });
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecognition() async {
    PermissionStatus microphoneStatus = await Permission.microphone.request();

    if (microphoneStatus.isGranted) {
      setState(() {
        _isRecognizing = true;
        _result = 'Đang nghe...';
      });

      await _acrCloud.start();
    } else if (microphoneStatus.isDenied) {
      setState(() {
        _result = 'Quyền truy cập microphone bị từ chối.';
      });
    } else if (microphoneStatus.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _stopRecognition() async {
    await _acrCloud.stop();
    setState(() {
      _isRecognizing = false;
      _result = 'Đã dừng nhận dạng.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _result,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.0),
              ),
            ),
            SizedBox(height: 20),
            if (!_isRecognizing)
              ElevatedButton(
                onPressed: _startRecognition,
                child: Text('Bắt đầu nhận dạng'),
              ),
            if (_isRecognizing)
              ElevatedButton(
                onPressed: _stopRecognition,
                child: Text('Dừng nhận dạng'),
                style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}