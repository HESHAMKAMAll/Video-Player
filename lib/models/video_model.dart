class VideoModel {
  final String path;
  final String fileName;
  final String thumbnailPath;
  final Duration duration;
  final String size;
  final DateTime dateAdded;
  final String resolution;

  VideoModel({
    required this.path,
    required this.fileName,
    required this.thumbnailPath,
    required this.duration,
    required this.size,
    required this.dateAdded,
    required this.resolution,
  });

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      path: map['path'] ?? '',
      fileName: map['fileName'] ?? '',
      thumbnailPath: map['thumbnailPath'] ?? '',
      duration: Duration(milliseconds: map['duration'] ?? 0),
      size: map['size'] ?? '',
      dateAdded: DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] ?? 0),
      resolution: map['resolution'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'fileName': fileName,
      'thumbnailPath': thumbnailPath,
      'duration': duration.inMilliseconds,
      'size': size,
      'dateAdded': dateAdded.millisecondsSinceEpoch,
      'resolution': resolution,
    };
  }

  @override
  String toString() {
    return 'VideoModel(path: $path, fileName: $fileName, thumbnailPath: $thumbnailPath, '
        'duration: $duration, size: $size, dateAdded: $dateAdded, resolution: $resolution)';
  }
}