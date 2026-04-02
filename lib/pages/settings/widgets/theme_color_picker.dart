/*
 * @Author: fukaidong qiji777@yeah.net
 * @Date: 2026-04-02 20:34:57
 * @LastEditors: fukaidong qiji777@yeah.net
 * @LastEditTime: 2026-04-02 20:35:00
 * @Description: .
 */
import 'package:flutter/material.dart';

/**
 * 主题颜色选择器组件
 */
class ThemeColorPicker extends StatelessWidget {
  final Color selectedColor;
  final List<Color> presetColors;
  final ValueChanged<Color> onColorSelected;

  const ThemeColorPicker({
    super.key,
    required this.selectedColor,
    required this.presetColors,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: presetColors.map((color) {
        final isSelected = selectedColor.value == color.value;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 20, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
