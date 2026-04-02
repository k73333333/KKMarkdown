import 'package:flutter/material.dart';
import '../../../models/translation_config.dart';

/**
 * API 配置卡片组件
 */
class ApiConfigCard extends StatefulWidget {
  final TranslationConfig config;
  final VoidCallback onChanged;

  const ApiConfigCard({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<ApiConfigCard> createState() => _ApiConfigCardState();
}

class _ApiConfigCardState extends State<ApiConfigCard> {
  late TextEditingController _apiKeyController;
  late TextEditingController _appIdController;
  late TextEditingController _endpointController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.config.apiKey);
    _appIdController = TextEditingController(text: widget.config.appId);
    _endpointController = TextEditingController(text: widget.config.endpoint);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _appIdController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  config.provider.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: config.isEnabled,
                  onChanged: (value) {
                    setState(() {
                      config.isEnabled = value;
                    });
                    widget.onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key / Access Token',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                config.apiKey = value;
                widget.onChanged();
              },
              obscureText: true,
            ),
            if (config.provider == 'baidu') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _appIdController,
                decoration: const InputDecoration(
                  labelText: 'App ID',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  config.appId = value;
                  widget.onChanged();
                },
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: '自定义 Endpoint (可选)',
                border: OutlineInputBorder(),
                hintText: 'https://api.example.com/v1',
              ),
              onChanged: (value) {
                config.endpoint = value;
                widget.onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
