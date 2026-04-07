import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/logger.dart';

/**
 * 文件和图片操作的逻辑混入
 */
mixin FileAndImageHandler<T extends StatefulWidget> on State<T> {
  final Map<String, String> imageBase64Cache = {};

  /**
   * 将图片字节数据插入到当前光标位置
   */
  void insertImageToBase64(Uint8List imageBytes,
      TextEditingController controller, VoidCallback onUpdate,
      {String extension = 'png'}) {
    final base64String =
        'data:image/$extension;base64,${base64Encode(imageBytes)}';
    final imageId = 'img_${DateTime.now().millisecondsSinceEpoch}';
    imageBase64Cache[imageId] = base64String;

    final imageMarkdown = '![]($imageId)\n';

    final text = controller.text;
    final selection = controller.selection;

    String newText;
    int newOffset;

    if (selection.baseOffset == -1) {
      newText = text + '\n' + imageMarkdown;
      newOffset = newText.length;
    } else {
      newText =
          text.replaceRange(selection.start, selection.end, imageMarkdown);
      newOffset = selection.start + imageMarkdown.length;
    }

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    onUpdate();
  }

  /**
   * 处理剪贴板粘贴事件
   */
  Future<void> handlePaste(
      TextEditingController controller, VoidCallback onUpdate) async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        insertImageToBase64(imageBytes, controller, onUpdate);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已从剪贴板粘贴图片')),
          );
        }
      }
    } catch (e) {
      Logger.error('读取剪贴板图片失败', e);
    }
  }

  /**
   * 从本地选择图片并插入
   */
  Future<void> insertImageFromFile(
      TextEditingController controller, VoidCallback onUpdate) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final bytes = await file.readAsBytes();

        String ext = path.split('.').last.toLowerCase();
        if (ext == 'jpg') ext = 'jpeg';

        insertImageToBase64(bytes, controller, onUpdate, extension: ext);
      }
    } catch (e) {
      Logger.error('选择图片失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('插入图片失败: $e')),
        );
      }
    }
  }

  /**
   * 打开文件
   * 
   * @param controller 文本控制器
   * @param onUpdate UI更新回调
   * @return 成功打开返回 true，否则返回 false
   */
  Future<bool> openFile(
      TextEditingController controller, VoidCallback onUpdate) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        String content = await file.readAsString();

        final RegExp base64RegExp =
            RegExp(r'!\[([^\]]*)\]\((data:image\/[^;]+;base64,[^\)]+)\)');
        content = content.replaceAllMapped(base64RegExp, (match) {
          final alt = match.group(1) ?? '';
          final base64 = match.group(2)!;
          final imageId =
              'img_${DateTime.now().millisecondsSinceEpoch}_${match.start}';
          imageBase64Cache[imageId] = base64;
          return '![$alt]($imageId)';
        });

        controller.text = content;
        onUpdate();

        if (mounted) {
          Provider.of<AppProvider>(context, listen: false)
              .setCurrentFilePath(path);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件读取成功')),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('打开文件失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: $e')),
        );
      }
      return false;
    }
  }

  /**
   * 从指定路径打开文件
   * 
   * @param path 文件绝对路径
   * @param controller 文本控制器
   * @param onUpdate UI更新回调
   * @return 成功打开返回 true，否则返回 false
   */
  Future<bool> openFileFromPath(String path, TextEditingController controller,
      VoidCallback onUpdate) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件不存在')),
          );
        }
        return false;
      }
      
      String content = await file.readAsString();

      final RegExp base64RegExp =
          RegExp(r'!\[([^\]]*)\]\((data:image\/[^;]+;base64,[^\)]+)\)');
      content = content.replaceAllMapped(base64RegExp, (match) {
        final alt = match.group(1) ?? '';
        final base64 = match.group(2)!;
        final imageId =
            'img_${DateTime.now().millisecondsSinceEpoch}_${match.start}';
        imageBase64Cache[imageId] = base64;
        return '![$alt]($imageId)';
      });

      controller.text = content;
      onUpdate();

      if (mounted) {
        Provider.of<AppProvider>(context, listen: false)
            .setCurrentFilePath(path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件读取成功')),
        );
      }
      return true;
    } catch (e) {
      Logger.error('打开文件失败: $path', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: $e')),
        );
      }
      return false;
    }
  }

  /**
   * 获取替换回真实 Base64 后的完整文本用于保存
   */
  String getContentToSave(String text) {
    String contentToSave = text;
    final RegExp imgIdRegExp = RegExp(r'!\[([^\]]*)\]\((img_[a-zA-Z0-9_]+)\)');
    contentToSave = contentToSave.replaceAllMapped(imgIdRegExp, (match) {
      final alt = match.group(1) ?? '';
      final imageId = match.group(2)!;
      final base64 = imageBase64Cache[imageId];
      if (base64 != null) {
        return '![$alt]($base64)';
      }
      return match.group(0)!;
    });
    return contentToSave;
  }

  /**
   * 保存文件
   */
  Future<void> saveFile(String text) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final currentPath = appProvider.currentFilePath;

    if (currentPath != null && currentPath.isNotEmpty) {
      try {
        final file = File(currentPath);
        await file.writeAsString(getContentToSave(text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
        }
      } catch (e) {
        Logger.error('保存文件失败', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存文件失败: $e')),
          );
        }
      }
    } else {
      await saveAsFile(text);
    }
  }

  /**
   * 另存为文件
   */
  Future<void> saveAsFile(String text) async {
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '另存为',
        fileName: '未命名.md',
        type: FileType.custom,
        allowedExtensions: ['md', 'txt'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(getContentToSave(text));

        if (mounted) {
          Provider.of<AppProvider>(context, listen: false)
              .setCurrentFilePath(outputFile);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
        }
      }
    } catch (e) {
      Logger.error('另存为失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('另存为失败: $e')),
        );
      }
    }
  }
}
