/*
 * @Author: fukaidong qiji777@yeah.net
 * @Date: 2026-04-07 18:57:51
 * @LastEditors: fukaidong qiji777@yeah.net
 * @LastEditTime: 2026-04-07 19:12:42
 * @Description: .
 */
import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('.flutter-plugins-dependencies');
  if (!file.existsSync()) {
    print('No .flutter-plugins-dependencies found.');
    return;
  }

  final content = file.readAsStringSync();
  final data = json.decode(content);
  final windowsPlugins = data['plugins']['windows'] as List;

  final symlinksDir = Directory('windows/flutter/ephemeral/.plugin_symlinks');
  if (!symlinksDir.existsSync()) {
    symlinksDir.createSync(recursive: true);
  }

  for (final plugin in windowsPlugins) {
    final name = plugin['name'];
    final path = plugin['path'];
    final linkPath = '${symlinksDir.path}/$name'.replaceAll('/', '\\');
    
    final link = Link(linkPath);
    if (link.existsSync()) {
      link.deleteSync();
    }
    
    print('Creating junction for $name -> $path');
    final result = Process.runSync('powershell', ['-Command', 'New-Item -ItemType Junction -Path "$linkPath" -Target "$path"']);
    print(result.stdout);
    if (result.stderr.toString().isNotEmpty) {
      print('ERROR: ${result.stderr}');
    }
  }
}
