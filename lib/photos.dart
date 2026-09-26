import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Lưu ảnh thuốc trong bộ nhớ riêng của app (thư mục "anh_thuoc").
/// Trong danh sách thuốc chỉ lưu tên file ảnh.
class PhotoStore {
  PhotoStore._();

  static String? _dir;
  static final ImagePicker _picker = ImagePicker();

  static Future<void> init() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/anh_thuoc');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _dir = dir.path;
    } catch (e) {
      debugPrint('Không mở được thư mục ảnh: $e');
    }
  }

  /// File ảnh theo tên đã lưu, hoặc null nếu không có.
  static File? fileFor(String? name) {
    if (name == null || name.isEmpty || _dir == null) return null;
    final f = File('$_dir/$name');
    return f.existsSync() ? f : null;
  }

  /// Chụp ảnh (camera) hoặc chọn ảnh có sẵn (thư viện), rồi lưu vào app.
  /// Trả về tên file, hoặc null nếu người dùng huỷ.
  static Future<String?> pick({required bool fromCamera}) async {
    if (_dir == null) await init();
    final dir = _dir;
    if (dir == null) return null;
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (picked == null) return null;
    final name = 'thuoc_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy('$dir/$name');
    try {
      await File(picked.path).delete(); // xoá bản tạm của máy ảnh
    } catch (_) {}
    return name;
  }

  static Future<void> delete(String? name) async {
    final f = fileFor(name);
    if (f == null) return;
    try {
      await f.delete();
    } catch (_) {}
  }
}
