import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Handles all image processing: compression, background removal, trimming.
///
/// Best practices applied:
/// - Images are compressed before saving to local storage.
/// - Only the RELATIVE file path (String) is stored in the database — never
///   binary data or absolute paths. This prevents path invalidation when the
///   iOS app container UUID changes between launches.
/// - Stickers with transparency → PNG (compressed, max 512px).
/// - Images without bg removal → JPEG quality 70 (max 512px).
/// - Temp files from picker/cropper are cleaned up after processing.
class ImageService {
  static const _uuid = Uuid();
  
  /// Cached base directory so we don't call getApplicationDocumentsDirectory()
  /// on every image load.
  String? _cachedBaseDir;

  /// Max dimension for saved stickers — keeps files small & app fast.
  static const int _maxStickerSize = 512;

  /// JPEG quality for images saved without background removal.
  static const int _jpegQuality = 70;

  /// PNG compression level (0-9, higher = smaller file but slower).
  static const int _pngCompression = 6;

  /// Returns the app's documents directory path (cached after first call).
  Future<String> _getBaseDir() async {
    if (_cachedBaseDir != null) return _cachedBaseDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cachedBaseDir = appDir.path;
    return _cachedBaseDir!;
  }

  /// Resolves a stored image path to a valid absolute path.
  ///
  /// - Relative path (e.g. "stickers/abc.png") → joined with the current
  ///   documents directory.
  /// - Legacy absolute path (e.g. "/old-uuid-dir/.../stickers/abc.png") →
  ///   the "stickers/…" tail is extracted and re-joined with the current
  ///   documents directory so the file is found even after an iOS container
  ///   UUID change.
  Future<String> resolveImagePath(String storedPath) async {
    final baseDir = await _getBaseDir();

    if (!storedPath.startsWith('/')) {
      // Already a relative path — just join it.
      return p.join(baseDir, storedPath);
    }

    // Absolute path — check if it still exists on disk.
    if (await File(storedPath).exists()) return storedPath;

    // The absolute path is stale (iOS container changed).
    // Try to extract the relative portion starting from "stickers/".
    final marker = '${p.separator}stickers${p.separator}';
    final idx = storedPath.indexOf(marker);
    if (idx != -1) {
      final relativeTail = storedPath.substring(idx + 1); // "stickers/xxx.png"
      return p.join(baseDir, relativeTail);
    }

    // Fallback: return the original path (may be broken, but nothing else to do).
    return storedPath;
  }

  /// Removes background, trims, compresses, and saves as PNG to local storage.
  /// Returns the RELATIVE file path (String) to store in the database.
  Future<String> processImage(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('Could not decode image');

    // 1. Resize to max sticker size for performance & storage savings
    final resized = _resizeImage(original, _maxStickerSize);

    // 2. Remove background using flood fill from edges
    final processed = _removeBackground(resized);

    // 3. Smooth edges
    final smoothed = _smoothEdges(processed);

    // 4. Trim transparent areas to fit sticker content tightly
    final trimmed = _trimTransparent(smoothed);

    // 5. Save as compressed PNG (supports transparency)
    final paths = await _getStickerPaths('png');
    final pngBytes = img.encodePng(trimmed, level: _pngCompression);
    await File(paths.absolute).writeAsBytes(pngBytes);

    // 6. Clean up temp source file (from picker/cropper cache)
    _tryDeleteTemp(sourcePath);

    // Return RELATIVE path to store in DB
    return paths.relative;
  }

  /// Compresses and saves the image WITHOUT background removal.
  /// Saves as JPEG (smaller than PNG when no transparency is needed).
  /// Returns the local file path (String) to store in the database.
  Future<String> saveOriginal(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      // Fallback: just copy the file if we can't decode it
      final ext = p.extension(sourcePath).replaceAll('.', '');
      final paths = await _getStickerPaths(ext.isNotEmpty ? ext : 'jpg');
      await File(sourcePath).copy(paths.absolute);
      return paths.relative;
    }

    // 1. Resize to max sticker size
    final resized = _resizeImage(original, _maxStickerSize);

    // 2. Save as compressed JPEG (no transparency needed)
    final paths = await _getStickerPaths('jpg');
    final jpegBytes = img.encodeJpg(resized, quality: _jpegQuality);
    await File(paths.absolute).writeAsBytes(jpegBytes);

    // 3. Clean up temp source file
    _tryDeleteTemp(sourcePath);

    // Return RELATIVE path to store in DB
    return paths.relative;
  }

  /// Deletes the sticker file from local storage when a button is removed.
  /// Accepts both relative and absolute paths.
  Future<void> deleteImage(String imagePath) async {
    try {
      final resolvedPath = await resolveImagePath(imagePath);
      final file = File(resolvedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore errors — file may already be gone
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns both the absolute and relative paths for a new sticker file.
  Future<_StickerPaths> _getStickerPaths(String extension) async {
    final baseDir = await _getBaseDir();
    final stickersDir = Directory(p.join(baseDir, 'stickers'));
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }
    final fileName = '${_uuid.v4()}.$extension';
    return _StickerPaths(
      absolute: p.join(stickersDir.path, fileName),
      relative: p.join('stickers', fileName),
    );
  }

  /// Tries to delete a temp file (from picker/cropper cache).
  /// Silently ignores errors — temp files are not critical.
  void _tryDeleteTemp(String path) {
    try {
      final file = File(path);
      // Only delete if it's in a cache/temp directory — not user's gallery
      if (path.contains('cache') || path.contains('tmp') || path.contains('Caches')) {
        file.delete().ignore();
      }
    } catch (_) {}
  }

  img.Image _resizeImage(img.Image image, int maxSize) {
    if (image.width <= maxSize && image.height <= maxSize) return image;

    if (image.width > image.height) {
      return img.copyResize(image, width: maxSize);
    } else {
      return img.copyResize(image, height: maxSize);
    }
  }

  img.Image _removeBackground(img.Image source) {
    final width = source.width;
    final height = source.height;

    final result = img.Image(width: width, height: height, numChannels: 4);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = source.getPixel(x, y);
        result.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(),
            pixel.b.toInt(), pixel.a.toInt());
      }
    }

    // Sample background color from corners
    final bgColors = <img.Pixel>[
      source.getPixel(0, 0),
      source.getPixel(width - 1, 0),
      source.getPixel(0, height - 1),
      source.getPixel(width - 1, height - 1),
    ];

    int avgR = 0, avgG = 0, avgB = 0;
    for (final c in bgColors) {
      avgR += c.r.toInt();
      avgG += c.g.toInt();
      avgB += c.b.toInt();
    }
    avgR ~/= bgColors.length;
    avgG ~/= bgColors.length;
    avgB ~/= bgColors.length;

    const tolerance = 45;
    final visited = List.generate(height, (_) => List.filled(width, false));
    final queue = <List<int>>[];

    for (int x = 0; x < width; x++) {
      queue.add([x, 0]);
      queue.add([x, height - 1]);
    }
    for (int y = 0; y < height; y++) {
      queue.add([0, y]);
      queue.add([width - 1, y]);
    }

    while (queue.isNotEmpty) {
      final point = queue.removeAt(0);
      final x = point[0];
      final y = point[1];

      if (x < 0 || x >= width || y < 0 || y >= height) continue;
      if (visited[y][x]) continue;
      visited[y][x] = true;

      final pixel = source.getPixel(x, y);
      final dr = (pixel.r.toInt() - avgR).abs();
      final dg = (pixel.g.toInt() - avgG).abs();
      final db = (pixel.b.toInt() - avgB).abs();

      if (dr <= tolerance && dg <= tolerance && db <= tolerance) {
        result.setPixelRgba(x, y, 0, 0, 0, 0);
        queue.add([x + 1, y]);
        queue.add([x - 1, y]);
        queue.add([x, y + 1]);
        queue.add([x, y - 1]);
      }
    }

    return result;
  }

  img.Image _smoothEdges(img.Image image) {
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height, numChannels: 4);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final a = pixel.a.toInt();

        if (a > 0 && a < 255) {
          result.setPixelRgba(
              x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), a);
          continue;
        }

        if (a == 255) {
          bool isEdge = false;
          for (final dx in [-1, 0, 1]) {
            for (final dy in [-1, 0, 1]) {
              if (dx == 0 && dy == 0) continue;
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                if (image.getPixel(nx, ny).a.toInt() == 0) {
                  isEdge = true;
                  break;
                }
              }
            }
            if (isEdge) break;
          }

          if (isEdge) {
            result.setPixelRgba(
                x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 200);
          } else {
            result.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(),
                pixel.b.toInt(), 255);
          }
        } else {
          result.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    return result;
  }

  img.Image _trimTransparent(img.Image image) {
    final width = image.width;
    final height = image.height;

    int minX = width, minY = height, maxX = 0, maxY = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (image.getPixel(x, y).a.toInt() > 0) {
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    if (maxX < minX || maxY < minY) return image;

    const padding = 4;
    minX = max(0, minX - padding);
    minY = max(0, minY - padding);
    maxX = min(width - 1, maxX + padding);
    maxY = min(height - 1, maxY + padding);

    final trimW = maxX - minX + 1;
    final trimH = maxY - minY + 1;

    final trimmed = img.Image(width: trimW, height: trimH, numChannels: 4);

    for (int y = 0; y < trimH; y++) {
      for (int x = 0; x < trimW; x++) {
        final srcPixel = image.getPixel(minX + x, minY + y);
        trimmed.setPixelRgba(x, y, srcPixel.r.toInt(), srcPixel.g.toInt(),
            srcPixel.b.toInt(), srcPixel.a.toInt());
      }
    }

    return trimmed;
  }
}

/// Helper to hold both absolute and relative paths.
class _StickerPaths {
  final String absolute;
  final String relative;

  const _StickerPaths({required this.absolute, required this.relative});
}
