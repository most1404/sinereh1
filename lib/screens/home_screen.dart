import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

import '../main.dart' show AppColors;
import '../models/vpn_config.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../services/ping_service.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';
import 'logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  late final V2ray _v2ray;
  late final PingService _pingService;

  AppSettings _settings = AppSettings();
  List<VpnConfig> _configs = [];
  List<Subscription> _subscriptions = [];
  String? _selectedConfigId;

  V2RayStatus? _status;
  bool _manualConnected = false; // منبع اصلی و مطمئنِ وضعیت اتصال
  bool _isInitialized = false;
  bool _isBusy = false; // اتصال/قطع در حال انجام
  bool _isRefreshingSub = false;
  bool _isTestingAll = false;
  String? _lastError;

  Timer? _subRefreshTimer;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _v2ray = V2ray(onStatusChanged: (status) {
      if (!mounted) return;
      setState(() => _status = status);
    });
    _pingService = PingService(_v2ray);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _settings = await _storage.loadSettings();
    _configs = await _storage.loadConfigs();
    _subscriptions = await _storage.loadSubscriptions();
    _selectedConfigId = await _storage.loadSelectedConfigId();

    await _v2ray.initialize(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );

    setState(() => _isInitialized = true);

    _scheduleSubscriptionTimer();

    // فقط لیست ساب‌اسکریپشن‌ها را بروزرسانی می‌کنیم (سبک، فقط یک دانلود
    // متنی). پینگ‌گرفتن از همه‌ی سرورها را عمداً خودکار انجام نمی‌دهیم،
    // چون تست هم‌زمان ده‌ها سرور منابع/اتصالات پس‌زمینه‌ی زیادی می‌سازد که
    // می‌تواند بعد از چند دقیقه باعث کرش شود. پینگ فقط با تپ روی «تست همه»
    // یا موقع زدن دکمه‌ی اتصال انجام می‌شود.
    if (_subscriptions.isNotEmpty) {
      unawaited(_refreshAllSubscriptions(silent: true));
    }
  }

  @override
  void dispose() {
    _subRefreshTimer?.cancel();
    _liveTimer?.cancel();
    super.dispose();
  }

  /// بعد از برگشتن از صفحه‌ی مدیریت ساب‌ها یا تنظیمات، دوباره از حافظه بخوان
  /// چون آن صفحه‌ها مستقیم روی حافظه تغییر اعمال می‌کنند.
  Future<void> _reloadFromStorage() async {
    _configs = await _storage.loadConfigs();
    _subscriptions = await _storage.loadSubscriptions();
    _settings = await _storage.loadSettings();
    _selectedConfigId = await _storage.loadSelectedConfigId();
    _scheduleSubscriptionTimer();
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // ساب‌اسکریپشن‌ها
  // ---------------------------------------------------------------------

  void _scheduleSubscriptionTimer() {
    _subRefreshTimer?.cancel();
    if (_subscriptions.isEmpty) return;
    _subRefreshTimer = Timer.periodic(
      Duration(hours: _settings.subscriptionRefreshHours),
      (_) => _refreshAllSubscriptions(silent: true),
    );
  }

  Future<void> _refreshAllSubscriptions({bool silent = false}) async {
    if (_subscriptions.isEmpty) {
      if (!silent) _showSnack('اول از «ساب‌اسکریپشن‌ها» یک لینک اضافه کن.');
      return;
    }
    setState(() {
      _isRefreshingSub = true;
      _lastError = null;
    });

    int totalOk = 0;
    final errors = <String>[];

    for (final sub in _subscriptions) {
      try {
        final fresh = await _subscriptionService.fetchSubscription(
          sub.url,
          subscriptionId: sub.id,
        );
        final existingForThis =
            _configs.where((c) => c.subscriptionId == sub.id).toList();
        final merged =
            _subscriptionService.mergeWithExisting(fresh, existingForThis);

        _configs.removeWhere((c) => c.subscriptionId == sub.id);
        _configs.addAll(merged);

        sub.serverCount = merged.length;
        sub.lastUpdated = DateTime.now();
        sub.lastError = null;
        totalOk++;
      } catch (e) {
        sub.lastError = e.toString();
        errors.add('${sub.name}: $e');
      }
    }

    await _storage.saveConfigs(_configs);
    await _storage.saveSubscriptions(_subscriptions);

    if (_selectedConfigId != null &&
        !_configs.any((c) => c.id == _selectedConfigId)) {
      _selectedConfigId = null;
      await _storage.saveSelectedConfigId(null);
    }

    if (mounted) {
      setState(() => _isRefreshingSub = false);
    }

    if (!silent) {
      if (errors.isEmpty) {
        _showSnack('بروزرسانی شد: $totalOk ساب، ${_configs.length} سرور.');
      } else {
        _lastError = errors.join('  •  ');
        _showSnack('برخی ساب‌ها با خطا مواجه شدند.');
      }
    }
  }

  // ---------------------------------------------------------------------
  // پینگ و اتصال
  // ---------------------------------------------------------------------

  VpnConfig? get _selectedConfig {
    if (_selectedConfigId == null) return null;
    try {
      return _configs.firstWhere((c) => c.id == _selectedConfigId);
    } catch (_) {
      return null;
    }
  }

  bool get _isConnected => _manualConnected;
  bool get _isConnecting => _isBusy;

  /// اگر کاربر یک ساب مشخص را «فعال» کرده باشد، فقط سرورهای همان ساب
  /// در نظر گرفته می‌شوند (برای اتصال سریع، لیست پیش‌نمایش، و غیره).
  List<VpnConfig> get _activeConfigs {
    final activeId = _settings.activeSubscriptionId;
    if (activeId == null) return _configs;
    return _configs.where((c) => c.subscriptionId == activeId).toList();
  }

  Future<void> _testAll() async {
    final pool = _activeConfigs;
    if (pool.isEmpty) return;
    if (pool.length > 20) {
      _showSnack('در حال تست ${pool.length} سرور، ممکنه چند دقیقه طول بکشه...');
    }
    setState(() => _isTestingAll = true);
    await _pingService.pingAll(pool);
    await _storage.saveConfigs(_configs);
    if (mounted) setState(() => _isTestingAll = false);
  }

  List<VpnConfig> get _sortedByPing {
    final list = List<VpnConfig>.from(_activeConfigs);
    list.sort((a, b) {
      final da = a.lastDelayMs;
      final db = b.lastDelayMs;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      if (da < 0 && db < 0) return 0;
      if (da < 0) return 1;
      if (db < 0) return -1;
      return da.compareTo(db);
    });
    return list;
  }

  Future<void> _onPowerButtonTap() async {
    if (_isConnected) {
      await _disconnect();
    } else {
      // اگر «سوییچ خودکار» خاموش است و قبلاً سروری انتخاب شده، همان را
      // دوباره وصل کن (بدون تست مجدد). در غیر این صورت سریع‌ترین را پیدا کن.
      final last = _selectedConfig;
      if (!_settings.autoSwitchEnabled && last != null) {
        await _connectTo(last);
      } else {
        await _connectFastest();
      }
    }
  }

  /// حداکثر تعداد سرور که موقع «اتصال به سریع‌ترین» به‌صورت خودکار (بدون
  /// تپ روی «تست همه») پینگ گرفته می‌شود. عدد بزرگ‌تر یعنی شانس بیشتر
  /// برای پیدا کردن بهترین سرور، ولی اتصالات پس‌زمینه‌ی بیشتری هم می‌سازد.
  static const int _maxAutoTestCount = 15;

  Future<void> _connectFastest() async {
    final pool = _activeConfigs;
    if (pool.isEmpty) {
      _showSnack('اول از «ساب‌اسکریپشن‌ها» یک لینک اضافه و بروزرسانی کن.');
      return;
    }
    setState(() => _isBusy = true);
    try {
      // یک تست سریع اولیه، فقط روی چند سرور اول (نه کل لیست) اگر هنوز
      // هیچ‌کدام تست نشده‌اند.
      if (pool.every((c) => c.lastDelayMs == null)) {
        final sample = pool.take(_maxAutoTestCount).toList();
        await _pingService.pingAll(sample);
        await _storage.saveConfigs(_configs);
      }
      final best = _sortedByPing.firstWhere(
        (c) => c.isReachable,
        orElse: () => _sortedByPing.first,
      );
      await _connectTo(best);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _connectTo(VpnConfig config) async {
    setState(() {
      _isBusy = true;
      _lastError = null;
    });
    try {
      final parsed = V2ray.parseFromURL(config.rawLink);
      final granted = await _v2ray.requestPermission();
      if (!granted) {
        _showSnack('اجازه‌ی VPN داده نشد.');
        return;
      }
      final excluded = _settings.excludedAppPackages;
      await _v2ray.startV2Ray(
        remark: config.remark,
        config: parsed.getFullConfiguration(),
        blockedApps: excluded.isEmpty ? null : excluded,
        bypassSubnets: null,
        proxyOnly: false,
        notificationDisconnectButtonName: 'قطع اتصال',
      );
      // منتظر سیگنال نامطمئن پلاگین نمی‌مانیم؛ چون startV2Ray بدون خطا
      // برگشت، همین الان وضعیت را «متصل» در نظر می‌گیریم.
      _manualConnected = true;
      _selectedConfigId = config.id;
      await _storage.saveSelectedConfigId(config.id);
      _startLiveMonitoring();
    } catch (e) {
      _manualConnected = false;
      _lastError = e.toString();
      _showErrorDialog('اتصال ناموفق بود', e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isBusy = true);
    try {
      await _v2ray.stopV2Ray();
      _manualConnected = false;
      _liveTimer?.cancel();
    } catch (e) {
      _showErrorDialog('قطع اتصال ناموفق بود', e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// حین اتصال، هر N ثانیه سرور فعلی و چند سرور دیگر را پینگ می‌کند و
  /// در صورت فعال‌بودن سوییچ خودکار، به سریع‌ترین سرور جابجا می‌شود.
  void _startLiveMonitoring() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      Duration(seconds: _settings.pingIntervalSeconds),
      (_) => _liveTick(),
    );
  }

  bool _liveTickRunning = false;

  /// این متد باید هرگز exception بیرون‌ندهد، چون داخل Timer.periodic صدا
  /// زده می‌شود و یک خطای مدیریت‌نشده اینجا کل اپ را در نسخه‌ی release
  /// کرش می‌دهد.
  ///
  /// نکته‌ی مهم فنی: حین اتصال، تست هم‌زمانِ چند کانفیگ دیگر (که هرکدام
  /// یک هسته‌ی V2Ray جدا نیاز دارند) می‌تواند با تونل فعال تداخل کند و
  /// باعث قطعی فیلترشکن یا کرش برنامه شود. برای همین اینجا فقط از متد
  /// رسمی و امنِ «تست سرور متصل‌شده» استفاده می‌کنیم. اگر همین سرور
  /// فعلی از کار افتاد، آنگاه (و فقط آنگاه) یک failover کامل انجام
  /// می‌دهیم: قطع، تست کامل لیست (که حالا امن است چون تونلی فعال نیست)
  /// و اتصال به بهترین گزینه‌ی بعدی.
  Future<void> _liveTick() async {
    if (_liveTickRunning) return; // از رونویسی چند تیک روی هم جلوگیری کن
    _liveTickRunning = true;
    try {
      if (!_isConnected) return;
      final current = _selectedConfig;
      if (current == null) return;

      final delay = await _pingService.pingConnectedOnly();
      current.lastDelayMs = delay;
      current.lastTestedAt = DateTime.now();
      await _storage.saveConfigs(_configs);
      if (mounted) setState(() {});

      final currentIsDown = delay < 0;
      if (currentIsDown && _settings.autoSwitchEnabled && !_isBusy) {
        await _failoverFromDeadServer(current);
      }
    } catch (_) {
      // هر خطایی اینجا نادیده گرفته می‌شود؛ تیک بعدی دوباره تلاش می‌کند.
    } finally {
      _liveTickRunning = false;
    }
  }

  /// وقتی سرور متصلِ فعلی دیگر جواب نمی‌دهد: قطع می‌کنیم (چون تونل مرده)،
  /// حالا که هیچ تونلی فعال نیست با خیال راحت همه‌ی لیست را تست می‌کنیم،
  /// و به بهترین گزینه‌ی در دسترس وصل می‌شویم.
  Future<void> _failoverFromDeadServer(VpnConfig deadConfig) async {
    try {
      await _v2ray.stopV2Ray();
    } catch (_) {}
    _manualConnected = false;
    _liveTimer?.cancel();
    if (mounted) setState(() {});

    final pool = _activeConfigs.where((c) => c.id != deadConfig.id).take(_maxAutoTestCount).toList();
    if (pool.isEmpty) return;

    await _pingService.pingAll(pool);
    await _storage.saveConfigs(_configs);

    final sorted = List<VpnConfig>.from(pool)
      ..sort((a, b) {
        final da = a.lastDelayMs, db = b.lastDelayMs;
        if (da == null || da < 0) return 1;
        if (db == null || db < 0) return -1;
        return da.compareTo(db);
      });
    final best = sorted.firstWhere((c) => c.isReachable, orElse: () => sorted.first);
    if (!best.isReachable) return; // هیچ سروری در دسترس نیست، بی‌خیال شو

    _showSnack('سرور قبلی از کار افتاد؛ به «${best.remark}» وصل شدیم.');
    await _connectTo(best);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield_rounded, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 8),
            const Text('سینره وی‌پی‌ان'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal_rounded),
            tooltip: 'لاگ‌های فنی',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LogsScreen(v2ray: _v2ray)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: 'ساب‌اسکریپشن‌ها',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
              );
              await _reloadFromStorage();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    settings: _settings,
                    onSave: (s) async {
                      _settings = s;
                      await _storage.saveSettings(s);
                      _scheduleSubscriptionTimer();
                      if (_isConnected) _startLiveMonitoring();
                    },
                  ),
                ),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAllSubscriptions(),
        color: AppColors.accentBlue,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildAutoUpdateBadge(),
            const SizedBox(height: 18),
            _buildPowerButton(),
            const SizedBox(height: 18),
            _buildCurrentServerCard(),
            const SizedBox(height: 18),
            _buildInfoRow(),
            const SizedBox(height: 12),
            _buildTopServersPreview(),
            if (_lastError != null) ...[
              const SizedBox(height: 16),
              Text(_lastError!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoUpdateBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isRefreshingSub
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  )
                : const Icon(Icons.sync_rounded, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              'بروزرسانی خودکار هر ${_settings.subscriptionRefreshHours} ساعت',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    if (_isConnecting) return 'در حال اتصال...';
    if (_isConnected) return 'متصل';
    return 'اتصال قطع است';
  }

  Widget _buildPowerButton() {
    final connected = _isConnected;
    final connecting = _isConnecting;
    final Color glow = connected
        ? AppColors.success
        : (connecting ? AppColors.accent : AppColors.textSecondary);

    return Column(
      children: [
        GestureDetector(
          onTap: connecting ? null : _onPowerButtonTap,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glow.withOpacity(0.25),
                  glow.withOpacity(0.02),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: glow, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: connecting
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.accent,
                        ),
                      )
                    : Icon(
                        Icons.power_settings_new_rounded,
                        size: 56,
                        color: glow,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusLabel(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: glow,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentServerCard() {
    final current = _selectedConfig;
    if (current == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _configs.isEmpty
                      ? 'ابتدا از 🔗 ساب‌اسکریپشن‌ها یک لینک اضافه کن.'
                      : 'روی دکمه‌ی پاور بزن تا به سریع‌ترین سرور وصل شوی، یا از «همه‌ی سرورها» یکی را انتخاب کن.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dns_rounded, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current.remark,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(current.protocol.toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (current.lastDelayMs != null && current.lastDelayMs! >= 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${current.lastDelayMs}ms',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    Subscription? activeSub;
    if (_settings.activeSubscriptionId != null) {
      for (final s in _subscriptions) {
        if (s.id == _settings.activeSubscriptionId) {
          activeSub = s;
          break;
        }
      }
    }
    final countText = activeSub != null
        ? '${_activeConfigs.length} سرور از «${activeSub.name}»'
        : '${_configs.length} سرور از ${_subscriptions.length} ساب';
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.dns_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  countText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isRefreshingSub ? null : () => _refreshAllSubscriptions(),
          icon: _isRefreshingSub
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync, size: 18),
          label: const Text('بروزرسانی'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildTopServersPreview() {
    final top = _sortedByPing.take(_settings.maxServersToPingLive).toList();
    if (top.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.grey.shade600, size: 36),
              const SizedBox(height: 10),
              const Text(
                'هنوز سروری اضافه نشده',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'از 🔗 ساب‌اسکریپشن‌ها، یک لینک اضافه کن',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('سرورها',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                _isTestingAll
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.speed_rounded),
                        onPressed: _testAll,
                        tooltip: 'تست پینگ همه',
                      ),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServersScreen(
                          configs: _activeConfigs,
                          selectedConfigId: _selectedConfigId,
                          pingService: _pingService,
                          onSelect: (c) => _connectTo(c),
                          onPersist: () => _storage.saveConfigs(_configs),
                        ),
                      ),
                    );
                    setState(() {});
                  },
                  child: const Text('همه'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final c in top)
            ListTile(
              leading: Icon(
                c.id == _selectedConfigId ? Icons.check_circle_rounded : Icons.dns_rounded,
                color: c.id == _selectedConfigId ? AppColors.success : AppColors.textSecondary,
              ),
              title: Text(c.remark, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(c.protocol.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              trailing: Text(
                c.lastDelayMs == null
                    ? '—'
                    : (c.lastDelayMs! < 0 ? 'خطا' : '${c.lastDelayMs}ms'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: _isBusy ? null : () => _connectTo(c),
            ),
        ],
      ),
    );
  }
}
