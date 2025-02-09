import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../models/video_model.dart';
import 'video_player_screen.dart';
import 'dart:io';
import 'package:visibility_detector/visibility_detector.dart';


class FolderListScreen extends StatefulWidget {
  const FolderListScreen({Key? key}) : super(key: key);

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_isFirstLoad) {
      _isFirstLoad = false;
      await Future.microtask(
            () => context.read<VideoProvider>().loadVideos(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshIndicatorKey.currentState?.show(),
          ),
        ],
      ),
      body: Consumer<VideoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.videosByFolder.isEmpty) {
            return const _LoadingWidget();
          }

          if (provider.error.isNotEmpty && provider.videosByFolder.isEmpty) {
            return _ErrorWidget(
              error: provider.error,
              onRetry: () => provider.refreshVideos(),
            );
          }

          return RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: () => provider.refreshVideos(),
            child: CustomScrollView(
              slivers: [
                if (provider.isLoading && provider.videosByFolder.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(),
                  ),

                if (provider.videosByFolder.isEmpty)
                  const SliverFillRemaining(
                    child: _EmptyWidget(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final folder = provider.videosByFolder.values.elementAt(index);
                          return _FolderCard(folder: folder);
                        },
                        childCount: provider.videosByFolder.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Searching for videos...'),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorWidget({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'An error occurred: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  const _EmptyWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.folder_off,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No video folders',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.read<VideoProvider>().refreshVideos(),
            icon: const Icon(Icons.refresh),
            label: const Text('to update'),
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final FolderVideos folder;

  const _FolderCard({
    required this.folder,
  });

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hour ${minutes > 0 ? 'و $minutes minute' : ''}';
    } else if (minutes > 0) {
      return '$minutes minute';
    } else {
      return 'Less than a minute';
    }
  }

  Duration _getTotalDuration() {
    return folder.videos.fold(
      Duration.zero,
          (prev, video) => prev + video.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final videosCount = folder.videos.length;
    final totalDuration = _getTotalDuration();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _navigateToFolderVideos(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              _buildFolderIcon(videosCount),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.folderName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$videosCount video • ${_formatDuration(totalDuration)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderIcon(int videosCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(
          Icons.folder,
          size: 40,
          color: Colors.amber,
        ),
        if (videosCount > 0)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                videosCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToFolderVideos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderVideosScreen(folder: folder),
      ),
    );
  }
}


class FolderVideosScreen extends StatefulWidget {
  final FolderVideos folder;

  const FolderVideosScreen({
    Key? key,
    required this.folder,
  }) : super(key: key);

  @override
  State<FolderVideosScreen> createState() => _FolderVideosScreenState();
}

class _FolderVideosScreenState extends State<FolderVideosScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _visibleItems = {};
  final int _batchSize = 100;
  int _currentBatchIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Using addPostFrameCallback to avoid build-time setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialThumbnails();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _visibleItems.clear();
    super.dispose();
  }

  void _scrollListener() {
    if (!_isLoading &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500) {
      _loadMoreThumbnails();
    }
  }

  Future<void> _loadInitialThumbnails() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final endIndex = _batchSize.clamp(0, widget.folder.videos.length);
      await _loadThumbnailsInRange(0, endIndex);
      _currentBatchIndex = endIndex;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreThumbnails() async {
    if (_isLoading || _currentBatchIndex >= widget.folder.videos.length) return;
    setState(() => _isLoading = true);

    try {
      final startIndex = _currentBatchIndex;
      final endIndex = (_currentBatchIndex + _batchSize)
          .clamp(0, widget.folder.videos.length);

      if (startIndex < endIndex) {
        await _loadThumbnailsInRange(startIndex, endIndex);
        _currentBatchIndex = endIndex;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadThumbnailsInRange(int start, int end) async {
    final videoProvider = context.read<VideoProvider>();
    for (var i = start; i < end; i++) {
      if (!mounted) return;

      final video = widget.folder.videos[i];
      if (!_visibleItems.contains(video.path)) {
        _visibleItems.add(video.path);
        await videoProvider.loadThumbnailForVideo(video.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.folderName),
      ),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 16 / 24,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: widget.folder.videos.length,
        itemBuilder: (context, index) {
          return VideoGridCard(
            video: widget.folder.videos[index],
            onVisibilityChanged: (visible) {
              if (visible &&
                  !_visibleItems.contains(widget.folder.videos[index].path)) {
                _visibleItems.add(widget.folder.videos[index].path);
                // Using Future.microtask to avoid build-time setState
                Future.microtask(() {
                  if (mounted) {
                    context.read<VideoProvider>()
                        .loadThumbnailForVideo(widget.folder.videos[index].path);
                  }
                });
              }
            },
          );
        },
      ),
    );
  }
}

class VideoGridCard extends StatelessWidget {
  final VideoModel video;
  final Function(bool) onVisibilityChanged;

  const VideoGridCard({
    Key? key,
    required this.video,
    required this.onVisibilityChanged,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(video.path),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0.1) {
          onVisibilityChanged(true);
        }
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(video: video,
                  // enableLooping: true,  تشغيل فيديو واحد مع التكرار
              ),
            ),
          );
        },
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Consumer<VideoProvider>(
                builder: (context, provider, child) {
                  if (provider.isThumbnailLoading(video.path)) {
                    return _buildLoadingWidget();
                  }

                  if (video.thumbnailPath.isNotEmpty) {
                    return Image.file(
                      File(video.thumbnailPath),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                      cacheWidth: 100,
                      cacheHeight: 150,
                    );
                  }

                  return _buildPlaceholder();
                },
              ),
              _buildVideoInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(
        Icons.video_file,
        size: 48,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              video.fileName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDuration(video.duration),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    video.size,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}