/**
 * 翻译配置模型
 * 存储用户自定义的翻译源配置信息
 */
class TranslationConfig {
  /** 翻译服务提供商标识 (e.g., 'google', 'baidu', 'youdao') */
  String provider;

  /** API Key / Access Token */
  String apiKey;

  /** App ID (部分服务商需要，如百度翻译) */
  String? appId;

  /** API Endpoint (部分服务商支持自定义接口地址) */
  String? endpoint;

  /** 是否启用 */
  bool isEnabled;

  /**
   * 构造函数
   * @param provider 服务商标识
   * @param apiKey API Key
   * @param appId App ID (可选)
   * @param endpoint 自定义接口地址 (可选)
   * @param isEnabled 是否启用，默认为 true
   */
  TranslationConfig({
    required this.provider,
    required this.apiKey,
    this.appId,
    this.endpoint,
    this.isEnabled = true,
  });

  /**
   * 从 JSON Map 创建实例
   * @param json JSON Map
   * @return TranslationConfig 实例
   */
  factory TranslationConfig.fromJson(Map<String, dynamic> json) {
    return TranslationConfig(
      provider: json['provider'] as String,
      apiKey: json['apiKey'] as String,
      appId: json['appId'] as String?,
      endpoint: json['endpoint'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  /**
   * 转换为 JSON Map
   * @return Map<String, dynamic>
   */
  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'apiKey': apiKey,
      'appId': appId,
      'endpoint': endpoint,
      'isEnabled': isEnabled,
    };
  }

  /**
   * 复制并修改对象
   * @return 新的 TranslationConfig 实例
   */
  TranslationConfig copyWith({
    String? provider,
    String? apiKey,
    String? appId,
    String? endpoint,
    bool? isEnabled,
  }) {
    return TranslationConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      appId: appId ?? this.appId,
      endpoint: endpoint ?? this.endpoint,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
