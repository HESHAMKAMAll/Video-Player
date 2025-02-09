import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import 'dart:io';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;
  final bool autoPlay;
  final List<VideoModel>? playlist;
  final int currentIndex;
  final bool enableAutoNext;
  final bool enableLooping;

  const VideoPlayerScreen({
    Key? key,
    required this.video,
    this.autoPlay = true,
    this.playlist,
    this.currentIndex = 0,
    this.enableAutoNext = false,
    this.enableLooping = false,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String _errorMessage = '';
  bool _isFullScreen = false;
  Duration _savedPosition = Duration.zero;

  String get _positionKey => 'video_position_${widget.video.path}';

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.file(File(widget.video.path));
      await _videoPlayerController.initialize();

      await _loadSavedPosition();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: widget.autoPlay,
        looping: widget.enableLooping,
        showControlsOnInitialize: true,
        startAt: _savedPosition,
        placeholder: _buildThumbnail(),
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'An error occurred while playing the video: $errorMessage',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        },
        additionalOptions: (context) {
          return <OptionItem>[
            OptionItem(
              onTap: (_) => _togglePlaybackSpeed(),
              iconData: Icons.speed,
              title: 'Operating speed',
            ),
            OptionItem(
              onTap: (_) => _toggleQuality(),
              iconData: Icons.high_quality,
              title: 'Video Quality',
            ),
            OptionItem(
              onTap: (_) => _showVideoInfo(),
              iconData: Icons.info_outline,
              title: 'Video information',
            ),
            OptionItem(
              onTap: (context) {
                _toggleLooping();
                Navigator.of(context).pop(); // إغلاق البوتم شيت
              },
              iconData: Icons.loop,
              title: 'repeat video',
            ),
          ];
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white,
        ),
      );

      _videoPlayerController.addListener(_onVideoPositionChanged);

      setState(() {
        _isInitialized = true;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
      print("Error initializing video player: $error");
    }
  }

  Widget _buildThumbnail() {
    return FutureBuilder<void>(
      future: _videoPlayerController.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return VideoPlayer(_videoPlayerController);
        }
        return Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  void _onVideoPositionChanged() {
    if (!_videoPlayerController.value.isPlaying &&
        _videoPlayerController.value.position >= _videoPlayerController.value.duration) {
      _onVideoEnded();
    }

    if (_videoPlayerController.value.isPlaying) {
      final currentPosition = _videoPlayerController.value.position;
      if ((currentPosition.inSeconds % 5) == 0 && currentPosition != _savedPosition) {
        _savedPosition = currentPosition;
        _savePosition(_savedPosition);
      }
    }
  }

  void _onVideoEnded() {
    if (widget.enableAutoNext && widget.playlist != null) {
      _playNextVideo();
    } else if (widget.enableLooping) {
      _videoPlayerController.seekTo(Duration.zero);
      _videoPlayerController.play();
    }
  }

  void _playNextVideo() {
    if (widget.playlist != null && widget.currentIndex < widget.playlist!.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            video: widget.playlist![widget.currentIndex + 1],
            playlist: widget.playlist,
            currentIndex: widget.currentIndex + 1,
            enableAutoNext: widget.enableAutoNext,
            enableLooping: widget.enableLooping,
          ),
        ),
      );
    } else if (widget.enableLooping && widget.playlist != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            video: widget.playlist![0],
            playlist: widget.playlist,
            currentIndex: 0,
            enableAutoNext: widget.enableAutoNext,
            enableLooping: widget.enableLooping,
          ),
        ),
      );
    }
  }

  // ... (previous code remains the same until _toggleLooping function)

  void _toggleLooping() {
    setState(() {
      if (_chewieController != null) {
        // تحديث خاصية التكرار باستخدام looping بدلاً من isLooping
        final newLoopingState = !_chewieController!.looping;
        _chewieController!.dispose();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: true,
          looping: newLoopingState,
          showControlsOnInitialize: true,
          startAt: _videoPlayerController.value.position,
          placeholder: _buildThumbnail(),
          deviceOrientationsOnEnterFullScreen: [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.portraitUp,
          ],
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text(
                'An error occurred while playing the video.: $errorMessage',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          },
          // additionalOptions: (context) {
          //   return <OptionItem>[
          //     OptionItem(
          //       onTap: (_) => _togglePlaybackSpeed(),
          //       iconData: Icons.speed,
          //       title: 'سرعة التشغيل',
          //     ),
          //     OptionItem(
          //       onTap: (_) => _toggleQuality(),
          //       iconData: Icons.high_quality,
          //       title: 'جودة الفيديو',
          //     ),
          //     OptionItem(
          //       onTap: (_) => _showVideoInfo(),
          //       iconData: Icons.info_outline,
          //       title: 'معلومات الفيديو',
          //     ),
          //     OptionItem(
          //       onTap: (context) {
          //         _toggleLooping();
          //         Navigator.of(context).pop(); // إغلاق البوتم شيت
          //       },
          //       iconData: Icons.loop,
          //       title: 'تكرار الفيديو',
          //     ),
          //   ];
          // },
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.red,
            handleColor: Colors.red,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white,
          ),
        );
      }
    });
  }

  // ... (rest of the code remains the same)

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMilliseconds = prefs.getInt(_positionKey);
      if (savedMilliseconds != null) {
        _savedPosition = Duration(milliseconds: savedMilliseconds);

        if (_savedPosition > _videoPlayerController.value.duration) {
          _savedPosition = Duration.zero;
        }
      }
    } catch (e) {
      print('Error loading saved position: $e');
      _savedPosition = Duration.zero;
    }
  }

  Future<void> _savePosition(Duration position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_positionKey, position.inMilliseconds);
    } catch (e) {
      print('Error saving position: $e');
    }
  }

  Future<void> _togglePlaybackSpeed() async {
    if (_chewieController == null) return;

    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final currentSpeed = _chewieController!.videoPlayerController.value.playbackSpeed;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose playback speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((speed) {
            return ListTile(
              title: Text('${speed}x'),
              selected: currentSpeed == speed,
              onTap: () {
                _chewieController!.videoPlayerController.setPlaybackSpeed(speed);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleQuality() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('High quality (1080p)'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Medium quality (720p)'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Low quality (480p)'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('file name: ${widget.video.path.split('/').last}'),
            const SizedBox(height: 8),
            Text('Duration: ${_videoPlayerController.value.duration.toString().split('.').first}'),
            const SizedBox(height: 8),
            Text(
                'Dimensions: ${_videoPlayerController.value.size.width.toInt()}x${_videoPlayerController.value.size.height.toInt()}'
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('closing'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'An error occurred.: $_errorMessage',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => initializePlayer(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        Center(
          child: Chewie(
            controller: _chewieController!,
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isFullScreen) {
                  _chewieController?.exitFullScreen();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Positioned(
      bottom: 70,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.currentIndex > 0)
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      video: widget.playlist![widget.currentIndex - 1],
                      playlist: widget.playlist,
                      currentIndex: widget.currentIndex - 1,
                      enableAutoNext: widget.enableAutoNext,
                      enableLooping: widget.enableLooping,
                    ),
                  ),
                );
              },
            ),
          if (widget.currentIndex < (widget.playlist?.length ?? 0) - 1)
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: () {
                _playNextVideo();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
           _chewieController?.exitFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              _buildVideoPlayer(),
              if (widget.playlist != null)
                _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_videoPlayerController.value.isInitialized) {
      _savePosition(_videoPlayerController.value.position);
    }
    _videoPlayerController.removeListener(_onVideoPositionChanged);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}