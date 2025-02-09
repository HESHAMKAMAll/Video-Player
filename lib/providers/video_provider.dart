import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';

class FolderVideos {
  final String folderPath;
  final String folderName;
  final List<VideoModel> videos;

  FolderVideos({required this.folderPath, required this.folderName, required this.videos});
}

class VideoProvider extends ChangeNotifier {
  Map<String, FolderVideos> _videosByFolder = {};

  Map<String, FolderVideos> get videosByFolder => _videosByFolder;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  String _error = '';

  String get error => _error;

  final Map<String, bool> _thumbnailLoadingStatus = {};

  bool isThumbnailLoading(String videoPath) => _thumbnailLoadingStatus[videoPath] ?? false;

  final Map<String, String> _loadedThumbnails = {};
  late final FcNativeVideoThumbnail _thumbnailGenerator;
  String? _thumbnailsDirectory;
  final String _cacheKey = 'video_cache_v2'; // تحديث نسخة الكاش
  bool _isInitialized = false;
  bool _isFirstLoad = true;

  VideoProvider() {
    _thumbnailGenerator = FcNativeVideoThumbnail();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    await _initThumbnailsDirectory();
    await _loadCachedData();
    _isInitialized = true;
    if (_isFirstLoad) {
      _startBackgroundScan();
    }
  }

  Future<void> _startBackgroundScan() async {
    _isFirstLoad = false;
    // بدء المسح في الخلفية بعد تحميل البيانات المخزنة مؤقتاً
    Future.microtask(() => _scanStorageLocations(isBackground: true));
  }

  Future<void> _initThumbnailsDirectory() async {
    if (_thumbnailsDirectory != null) return;
    final appDir = await getApplicationDocumentsDirectory();
    _thumbnailsDirectory = '${appDir.path}/thumbnails';
    final directory = Directory(_thumbnailsDirectory!);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = {
        'lastUpdate': DateTime.now().toIso8601String(),
        'folders': _videosByFolder.map((key, value) => MapEntry(key, {
              'folderPath': value.folderPath,
              'folderName': value.folderName,
              'videos': value.videos.map((v) => v.toMap()).toList(),
            })),
      };
      await prefs.setString(_cacheKey, json.encode(cache));
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final data = json.decode(cached) as Map<String, dynamic>;
        final folders = data['folders'] as Map<String, dynamic>;

        _videosByFolder = folders.map((key, value) {
          final folderData = value as Map<String, dynamic>;
          return MapEntry(
            key,
            FolderVideos(
              folderPath: folderData['folderPath'] as String,
              folderName: folderData['folderName'] as String,
              videos: (folderData['videos'] as List).map((v) => VideoModel.fromMap(v as Map<String, dynamic>)).toList(),
            ),
          );
        });
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cache: $e');
    }
  }

  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      await _initThumbnailsDirectory();
      final fileName = videoPath.hashCode.toString();
      final thumbnailPath = '${_thumbnailsDirectory!}/$fileName.jpg';

      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      final bool success = await _thumbnailGenerator.getVideoThumbnail(
        srcFile: videoPath,
        destFile: thumbnailPath,
        width: 200,
        // تقليل حجم الصورة المصغرة
        height: 150,
        quality: 60, // تقليل جودة الصورة المصغرة
      );

      return success ? thumbnailPath : null;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  // تحسين تحميل الصور المصغرة باستخدام مجموعات
  Future<void> loadThumbnailsForVisibleItems(List<String> visiblePaths) async {
    const int batchSize = 3; // عدد الصور المصغرة التي سيتم تحميلها في نفس الوقت

    for (var i = 0; i < visiblePaths.length; i += batchSize) {
      final batch = visiblePaths.skip(i).take(batchSize);
      await Future.wait(
        batch.map((path) async {
          if (!_loadedThumbnails.containsKey(path) && _thumbnailLoadingStatus[path] != true) {
            await loadThumbnailForVideo(path);
          }
        }),
      );
    }
  }

  Future<void> loadThumbnailForVideo(String videoPath) async {
    if (_loadedThumbnails.containsKey(videoPath)) return;
    if (_thumbnailLoadingStatus[videoPath] == true) return;

    _thumbnailLoadingStatus[videoPath] = true;
    notifyListeners();

    try {
      final thumbnailPath = await _generateThumbnail(videoPath);
      if (thumbnailPath != null) {
        _loadedThumbnails[videoPath] = thumbnailPath;
        _updateVideoThumbnail(videoPath, thumbnailPath);
      }
    } finally {
      _thumbnailLoadingStatus[videoPath] = false;
      notifyListeners();
    }
  }

  Future<void> loadVideos() async {
    if (!_isInitialized) await _initialize();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          var status = await Permission.videos.request();
          if (!status.isGranted) throw Exception('تم رفض إذن الوصول للفيديوهات');
        } else {
          var status = await Permission.storage.request();
          if (!status.isGranted) throw Exception('تم رفض إذن الوصول للملفات');
        }
      }

      // إذا كان لدينا بيانات مخزنة مؤقتاً، نستخدمها أولاً
      if (_videosByFolder.isEmpty) {
        await _loadCachedData();
      }

      // بدء المسح في الخلفية
      _startBackgroundScan();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _scanStorageLocations({bool isBackground = false}) async {
    if (!isBackground) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final videoInfo = FlutterVideoInfo();
      final Map<String, FolderVideos> newVideosByFolder = {};
      final List<Directory> storageLocations = await _getStorageLocations();

      for (var directory in storageLocations) {
        await _scanDirectory(directory, videoInfo, newVideosByFolder);
      }

      _videosByFolder = newVideosByFolder;
      await _saveCachedData();
    } catch (e) {
      print('Scan error: $e');
    } finally {
      if (!isBackground) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  void _updateVideoThumbnail(String videoPath, String thumbnailPath) {
    final folderPath = Directory(videoPath).parent.path;
    final folder = _videosByFolder[folderPath];
    if (folder != null) {
      final videoIndex = folder.videos.indexWhere((v) => v.path == videoPath);
      if (videoIndex != -1) {
        final video = folder.videos[videoIndex];
        folder.videos[videoIndex] = VideoModel(
          path: video.path,
          fileName: video.fileName,
          thumbnailPath: thumbnailPath,
          duration: video.duration,
          size: video.size,
          dateAdded: video.dateAdded,
          resolution: video.resolution,
        );
        notifyListeners();
      }
    }
  }

  Future<List<Directory>> _getStorageLocations() async {
    List<Directory> locations = [];
    final internalStorage = Directory('/storage/emulated/0');

    if (await internalStorage.exists()) {
      locations.add(internalStorage);
    }

    try {
      final storageInfo = await Directory('/storage').list().toList();
      for (var item in storageInfo) {
        if (item.path != '/storage/emulated' && item.path != '/storage/self') {
          if (await Directory(item.path).exists()) {
            locations.add(Directory(item.path));
          }
        }
      }
    } catch (e) {
      print('Error accessing storage: $e');
    }

    return locations;
  }

  Future<void> _scanDirectory(Directory directory, FlutterVideoInfo videoInfo, Map<String, FolderVideos> newVideosByFolder) async {
    try {
      await for (var entity in directory.list(recursive: true)) {
        if (entity is File && _isVideoFile(entity.path)) {
          final info = await videoInfo.getVideoInfo(entity.path);
          if (info != null) {
            final video = await _createVideoModel(entity, info);
            final folderPath = entity.parent.path;

            if (!newVideosByFolder.containsKey(folderPath)) {
              newVideosByFolder[folderPath] = FolderVideos(
                folderPath: folderPath,
                folderName: folderPath.split('/').last,
                videos: [],
              );
            }
            newVideosByFolder[folderPath]!.videos.add(video);
          }
        }
      }

      // ترتيب الفيديوهات حسب تاريخ الإضافة
      for (var folder in newVideosByFolder.values) {
        folder.videos.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      }
    } catch (e) {
      print('Error scanning directory ${directory.path}: $e');
    }
  }

  Future<VideoModel> _createVideoModel(File entity, info) async {
    return VideoModel(
      path: entity.path,
      fileName: entity.path.split('/').last,
      thumbnailPath: _loadedThumbnails[entity.path] ?? '',
      duration: Duration(milliseconds: info.duration?.toInt() ?? 0),
      size: await _getFileSize(entity),
      dateAdded: await entity.lastModified(),
      resolution: '${info.width}x${info.height}',
    );
  }

  // تنظيف الذاكرة المؤقتة القديمة
  Future<void> cleanupOldThumbnails() async {
    try {
      await _initThumbnailsDirectory();
      final directory = Directory(_thumbnailsDirectory!);
      if (await directory.exists()) {
        final files = await directory.list().toList();
        for (var file in files) {
          if (file is File && !_loadedThumbnails.values.contains(file.path)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning up thumbnails: $e');
    }
  }

  Future<String> _getFileSize(File file) async {
    final bytes = await file.length();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool _isVideoFile(String path) {
    final extensions = ['.mp4', '.avi', '.mov', '.mkv', '.flv', '.wmv', '.3gp', '.webm', '.m4v'];
    return extensions.any((ext) => path.toLowerCase().endsWith(ext));
  }

  refreshVideos() {
    _loadedThumbnails.clear();
    loadVideos();
  }

  @override
  void dispose() {
    cleanupOldThumbnails();
    super.dispose();
  }
}
