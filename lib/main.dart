import 'dart:async';
import 'package:flutter/material.dart';
import 'package:acr_cloud_sdk/acr_cloud_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spotify/spotify.dart' as spot;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Music Recognition',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(title: 'Nhận diện nhạc & Spotify'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final AcrCloudSdk _acrCloud = AcrCloudSdk();
  String _result = 'Nhấn nút để bắt đầu nhận dạng';
  bool _isRecognizing = false;
  late AnimationController _waveController;
  late spot.SpotifyApi spotify;
  List<spot.Track> tracks = [];
  List<spot.Artist> artists = [];
  List<spot.AlbumSimple> albums = [];
  List<spot.PlaylistSimple> playlists = [];

  @override
  void initState() {
    super.initState();
    var credentials = spot.SpotifyApiCredentials(
      'b5c7db89e4474976b4bc1a7dbb530dd0',
      '999213d75d194d4b89558aefadee5614',
    );
    spotify = spot.SpotifyApi(credentials);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _acrCloud.init(
      host: 'identify-ap-southeast-1.acrcloud.com',
      accessKey: 'feb91c05983f15166729ca304fca4b58',
      accessSecret: 'brb1vdvjkhu5lKfhwbR0GwOpmVGk2y54keEZSJTZ',
      recorderConfigRate: 16000,
      recorderConfigChannels: 1,
      recMode: ACRCloudRecMode.advance_remote,
    );

    _acrCloud.songModelStream.listen((songModel) async {
      setState(() {
        _isRecognizing = false;
      });
      if (songModel.metadata != null && songModel.metadata!.music!.isNotEmpty) {
        final music = songModel.metadata!.music!.first;
        _result =
            'Bài hát: ${music.title}\nCa sĩ: ${music.artists?.map((artist) => artist.name).join(', ') ?? ''}\nAlbum: ${music.album?.name ?? ''}\nRelease Date: ${music.releaseDate ?? ''}';
        await searchMusicOnSpotify(music);
      } else {
        setState(() {
          _result = 'Không tìm thấy kết quả.';
          tracks.clear();
          artists.clear();
          albums.clear();
          playlists.clear();
        });
      }
    }, onError: (error) {
      setState(() {
        _isRecognizing = false;
        _result = 'Đã xảy ra lỗi: $error';
        tracks.clear();
        artists.clear();
        albums.clear();
        playlists.clear();
      });
    }, onDone: () {
      setState(() {
        _isRecognizing = false;
      });
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> searchMusicOnSpotify(dynamic music) async {
    String query = music.title ?? '';
    if (music.artists != null && music.artists!.isNotEmpty) {
      query += ' ' + music.artists!.map((a) => a.name).join(' ');
    }
    List<spot.Track> foundTracks = [];
    List<spot.Artist> foundArtists = [];
    List<spot.AlbumSimple> foundAlbums = [];
    List<spot.PlaylistSimple> foundPlaylists = [];

    try {
      var searchPages = await spotify.search.get(query).first(2);
      for (var page in searchPages) {
        if (page.items == null) continue;
        for (var item in page.items!) {
          if (item is spot.Track) foundTracks.add(item);
          if (item is spot.Artist) foundArtists.add(item);
          if (item is spot.AlbumSimple) foundAlbums.add(item);
          if (item is spot.PlaylistSimple) foundPlaylists.add(item);
        }
      }
    } catch (e) {
      setState(() {
        _result = 'Lỗi tìm kiếm Spotify: $e';
      });
    }

    setState(() {
      tracks = foundTracks;
      artists = foundArtists;
      albums = foundAlbums;
      playlists = foundPlaylists;
    });
  }

  Future<void> _startRecognition() async {
    final statuses = await [
      Permission.microphone,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      setState(() {
        _isRecognizing = true;
        _result = 'Đang nghe...';
        tracks.clear();
        artists.clear();
        albums.clear();
        playlists.clear();
      });

      await _acrCloud.start();
      await Future.delayed(const Duration(seconds: 30));
      await _acrCloud.stop();
    } else {
      setState(() {
        _result = 'Bạn cần cấp đầy đủ quyền để nhận dạng âm thanh.';
      });

      if (statuses.values.any((status) => status.isPermanentlyDenied)) {
        openAppSettings();
      }
    }
  }

  Future<void> _stopRecognition() async {
    await _acrCloud.stop();
    setState(() {
      _isRecognizing = false;
      _result = 'Đã dừng nhận dạng.';
    });
  }

  Widget _buildSpotifyResults() {
    if (tracks.isEmpty &&
        artists.isEmpty &&
        albums.isEmpty &&
        playlists.isEmpty) {
      return SizedBox.shrink();
    }
    return Expanded(
      child: ListView(
        children: [
          if (tracks.isNotEmpty)
            _buildSection(
                'Tracks',
                tracks
                    .map((t) => ListTile(
                          leading: t.album?.images?.isNotEmpty == true
                              ? Image.network(t.album!.images!.first.url ?? '',
                                  width: 48, height: 48, fit: BoxFit.cover)
                              : Icon(Icons.music_note, size: 48),
                          title: Text(t.name ?? ''),
                          subtitle: Text(
                              t.artists?.map((a) => a.name).join(', ') ?? ''),
                        ))
                    .toList()),
          if (artists.isNotEmpty)
            _buildSection(
                'Artists',
                artists
                    .map((a) => ListTile(
                          leading: a.images?.isNotEmpty == true
                              ? Image.network(a.images!.first.url ?? '',
                                  width: 48, height: 48, fit: BoxFit.cover)
                              : Icon(Icons.person, size: 48),
                          title: Text(a.name ?? ''),
                        ))
                    .toList()),
          if (albums.isNotEmpty)
            _buildSection(
                'Albums',
                albums
                    .map((al) => ListTile(
                          leading: al.images?.isNotEmpty == true
                              ? Image.network(al.images!.first.url ?? '',
                                  width: 48, height: 48, fit: BoxFit.cover)
                              : Icon(Icons.album, size: 48),
                          title: Text(al.name ?? ''),
                          subtitle: Text(
                              al.artists?.map((a) => a.name).join(', ') ?? ''),
                        ))
                    .toList()),
          if (playlists.isNotEmpty)
            _buildSection(
                'Playlists',
                playlists
                    .map((pl) => ListTile(
                          leading: pl.images?.isNotEmpty == true
                              ? Image.network(pl.images!.first.url ?? '',
                                  width: 48, height: 48, fit: BoxFit.cover)
                              : Icon(Icons.queue_music, size: 48),
                          title: Text(pl.name ?? ''),
                        ))
                    .toList()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        ...children,
        Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1DB954), // Spotify Green
                  Color(0xFF1DB960),
                  Color(0xFF1DB990),
                  Color(0xFF191414), // Spotify Black
                ],
              ),
            ),
          ),
          Center(
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isRecognizing)
                        ...List.generate(3, (i) {
                          return AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              final value =
                                  (_waveController.value + i * 0.33) % 1.0;
                              return Opacity(
                                opacity: 1 - value,
                                child: Container(
                                  width: 140 + value * 200,
                                  height: 140 + value * 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color.fromARGB(255, 0, 219, 77)
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      GestureDetector(
                        onTap: () {
                          if (!_isRecognizing) {
                            _startRecognition();
                          } else {
                            _stopRecognition();
                          }
                        },
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1DB954),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.fromARGB(255, 58, 48, 48),
                                Color(0xFF1DB960),
                                Color(0xFF1DB954),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(10, 10),
                                color: Colors.black38,
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.speaker,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _result,
                      key: ValueKey(_result),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // if (!_isRecognizing)
                  //   ElevatedButton.icon(
                  //     onPressed: _startRecognition,
                  //     icon: const Icon(Icons.mic),
                  //     label: const Text('Bắt đầu nhận dạng'),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: const Color(0xFF1DB954),
                  //       foregroundColor: Colors.white,
                  //       padding: const EdgeInsets.symmetric(
                  //           horizontal: 24, vertical: 12),
                  //       textStyle: const TextStyle(fontSize: 16),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(16),
                  //       ),
                  //     ),
                  //   ),
                  // if (_isRecognizing)
                  //   Column(
                  //     children: [
                  //       const SizedBox(height: 16),
                  //       ElevatedButton.icon(
                  //         onPressed: _stopRecognition,
                  //         icon: const Icon(Icons.stop),
                  //         label: const Text('Dừng nhận dạng'),
                  //         style: ElevatedButton.styleFrom(
                  //           backgroundColor: Colors.red,
                  //           foregroundColor: Colors.white,
                  //           padding: const EdgeInsets.symmetric(
                  //               horizontal: 24, vertical: 12),
                  //           textStyle: const TextStyle(fontSize: 16),
                  //           shape: RoundedRectangleBorder(
                  //             borderRadius: BorderRadius.circular(16),
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  const SizedBox(height: 16),
                  _buildSpotifyResults(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
