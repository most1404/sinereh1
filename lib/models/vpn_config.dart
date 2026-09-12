/// یک منبع ساب‌اسکریپشن که کاربر اضافه کرده است.
class Subscription {
  final String id; // خودِ آدرس، به‌عنوان شناسه‌ی یکتا
  final String url;
  String name; // نام نمایشی (پیش‌فرض از دامنه‌ی آدرس ساخته می‌شود)
  DateTime? lastUpdated;
  String? lastError; // آخرین خطای بروزرسانی (اگر بود)
  int serverCount; // تعداد سرورهایی که آخرین بار از این ساب استخراج شد

  Subscription({
    required this.id,
    required this.url,
    required this.name,
    this.lastUpdated,
    this.lastError,
    this.serverCount = 0,
  });

  factory Subscription.create(String url) {
    String name;
    try {
      name = Uri.parse(url).host;
      if (name.isEmpty) name = url;
    } catch (_) {
      name = url;
    }
    return Subscription(id: url, url: url, name: name);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'lastError': lastError,
        'serverCount': serverCount,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        url: json['url'] as String,
        name: json['name'] as String? ?? json['url'] as String,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.tryParse(json['lastUpdated'] as String)
            : null,
        lastError: json['lastError'] as String?,
        serverCount: json['serverCount'] as int? ?? 0,
      );
}

/// یک کانفیگ سرور V2Ray/Xray به همراه آخرین وضعیت پینگ آن.
class VpnConfig {
  final String id; // شناسه‌ی یکتا (پایدار بین بروزرسانی‌ها، بر اساس خودِ لینک)
  final String rawLink; // لینک اصلی vmess://, vless://, trojan://, ss://
  final String subscriptionId; // به کدام ساب‌اسکریپشن تعلق دارد
  String remark; // نام نمایشی سرور
  String protocol; // پروتکل استخراج‌شده از لینک

  /// آخرین تاخیر اندازه‌گیری‌شده به میلی‌ثانیه.
  /// null یعنی هنوز تست نشده، -1 یعنی تست ناموفق بوده (سرور غیرقابل‌دسترس).
  int? lastDelayMs;

  DateTime? lastTestedAt;

  VpnConfig({
    required this.id,
    required this.rawLink,
    required this.subscriptionId,
    required this.remark,
    required this.protocol,
    this.lastDelayMs,
    this.lastTestedAt,
  });

  bool get isReachable => lastDelayMs != null && lastDelayMs! >= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rawLink': rawLink,
        'subscriptionId': subscriptionId,
        'remark': remark,
        'protocol': protocol,
        'lastDelayMs': lastDelayMs,
        'lastTestedAt': lastTestedAt?.toIso8601String(),
      };

  factory VpnConfig.fromJson(Map<String, dynamic> json) => VpnConfig(
        id: json['id'] as String,
        rawLink: json['rawLink'] as String,
        subscriptionId: json['subscriptionId'] as String? ?? '',
        remark: json['remark'] as String,
        protocol: json['protocol'] as String,
        lastDelayMs: json['lastDelayMs'] as int?,
        lastTestedAt: json['lastTestedAt'] != null
            ? DateTime.tryParse(json['lastTestedAt'] as String)
            : null,
      );
}

/// تنظیمات قابل‌ذخیره‌ی برنامه (لیست ساب‌اسکریپشن‌ها جداگانه ذخیره می‌شود).
class AppSettings {
  int subscriptionRefreshHours; // هر چند ساعت ساب‌اسکریپشن‌ها بروزرسانی شوند
  int pingIntervalSeconds; // هر چند ثانیه حین اتصال پینگ گرفته شود
  bool autoSwitchEnabled; // آیا خودکار به سریع‌ترین سرور سوییچ شود
  int switchImprovementMs; // حداقل بهبود پینگ (ms) برای توجیه سوییچ
  int maxServersToPingLive; // حداکثر تعداد سرور برای پینگ زنده حین اتصال (برای صرفه‌جویی باتری)
  List<String> excludedAppPackages; // برنامه‌هایی که از تونل VPN رد نمی‌شوند (ترافیک مستقیم)
  String? activeSubscriptionId; // اگر مقدار داشته باشد، فقط سرورهای همین ساب استفاده می‌شوند

  AppSettings({
    this.subscriptionRefreshHours = 3,
    this.pingIntervalSeconds = 60,
    this.autoSwitchEnabled = true,
    this.switchImprovementMs = 80,
    this.maxServersToPingLive = 8,
    List<String>? excludedAppPackages,
    this.activeSubscriptionId,
  }) : excludedAppPackages = excludedAppPackages ?? [];

  Map<String, dynamic> toJson() => {
        'subscriptionRefreshHours': subscriptionRefreshHours,
        'pingIntervalSeconds': pingIntervalSeconds,
        'autoSwitchEnabled': autoSwitchEnabled,
        'switchImprovementMs': switchImprovementMs,
        'maxServersToPingLive': maxServersToPingLive,
        'excludedAppPackages': excludedAppPackages,
        'activeSubscriptionId': activeSubscriptionId,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        subscriptionRefreshHours: json['subscriptionRefreshHours'] ?? 3,
        pingIntervalSeconds: json['pingIntervalSeconds'] ?? 60,
        autoSwitchEnabled: json['autoSwitchEnabled'] ?? true,
        switchImprovementMs: json['switchImprovementMs'] ?? 80,
        maxServersToPingLive: json['maxServersToPingLive'] ?? 8,
        excludedAppPackages: (json['excludedAppPackages'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        activeSubscriptionId: json['activeSubscriptionId'] as String?,
      );
}
