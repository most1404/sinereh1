import 'package:flutter/material.dart';
import '../models/vpn_config.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';

/// این صفحه خودش مستقیم با StorageService کار می‌کند (بدون وابستگی به
/// صفحه‌ی اصلی) تا افزودن/حذف/بروزرسانی هر ساب‌اسکریپشن ساده و مستقل باشد.
/// صفحه‌ی اصلی بعد از بسته‌شدن این صفحه، دوباره از حافظه می‌خواند.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final StorageService _storage = StorageService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  List<Subscription> _subscriptions = [];
  List<VpnConfig> _configs = [];
  AppSettings _settings = AppSettings();
  bool _loading = true;
  final Set<String> _refreshingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _subscriptions = await _storage.loadSubscriptions();
    _configs = await _storage.loadConfigs();
    _settings = await _storage.loadSettings();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setActiveSubscription(String? id) async {
    setState(() => _settings.activeSubscriptionId = id);
    await _storage.saveSettings(_settings);
  }

  int _countFor(String subscriptionId) =>
      _configs.where((c) => c.subscriptionId == subscriptionId).length;

  Future<void> _addSubscription() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن ساب‌اسکریپشن جدید'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com/sub',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;
    if (_subscriptions.any((s) => s.id == url)) {
      _showSnack('این لینک قبلاً اضافه شده.');
      return;
    }

    final sub = Subscription.create(url);
    setState(() {
      _subscriptions.add(sub);
      _refreshingIds.add(sub.id);
    });
    await _storage.saveSubscriptions(_subscriptions);
    await _refreshOne(sub);
  }

  Future<void> _removeSubscription(Subscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف ساب‌اسکریپشن'),
        content: Text('«${sub.name}» و همه‌ی ${_countFor(sub.id)} سرور مربوط به آن حذف شوند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _subscriptions.removeWhere((s) => s.id == sub.id);
      _configs.removeWhere((c) => c.subscriptionId == sub.id);
    });
    await _storage.saveSubscriptions(_subscriptions);
    await _storage.saveConfigs(_configs);
    _showSnack('«${sub.name}» حذف شد.');
  }

  Future<void> _refreshOne(Subscription sub) async {
    setState(() => _refreshingIds.add(sub.id));
    try {
      final fresh = await _subscriptionService.fetchSubscription(
        sub.url,
        subscriptionId: sub.id,
      );
      final existingForThis =
          _configs.where((c) => c.subscriptionId == sub.id).toList();
      final merged = _subscriptionService.mergeWithExisting(fresh, existingForThis);

      _configs.removeWhere((c) => c.subscriptionId == sub.id);
      _configs.addAll(merged);

      sub.serverCount = merged.length;
      sub.lastUpdated = DateTime.now();
      sub.lastError = null;
    } catch (e) {
      sub.lastError = e.toString();
    } finally {
      await _storage.saveConfigs(_configs);
      await _storage.saveSubscriptions(_subscriptions);
      if (mounted) {
        setState(() => _refreshingIds.remove(sub.id));
      }
    }
  }

  Future<void> _refreshAll() async {
    for (final sub in List<Subscription>.from(_subscriptions)) {
      await _refreshOne(sub);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ساب‌اسکریپشن‌ها'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'بروزرسانی همه',
            onPressed: _subscriptions.isEmpty ? null : _refreshAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubscription,
        icon: const Icon(Icons.add),
        label: const Text('افزودن ساب'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subscriptions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_off_rounded,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'هنوز هیچ ساب‌اسکریپشنی اضافه نکرده‌ای',
                          style: TextStyle(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'با دکمه‌ی «افزودن ساب» پایین صفحه شروع کن',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'برای اتصال، روی یکی بزن تا فقط از همون استفاده بشه',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: RadioListTile<String?>(
                        value: null,
                        groupValue: _settings.activeSubscriptionId,
                        onChanged: (_) => _setActiveSubscription(null),
                        title: const Text('همه‌ی ساب‌ها با هم',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${_configs.length} سرور از مجموع همه'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final sub in _subscriptions) ...[
                      _buildSubscriptionCard(sub),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSubscriptionCard(Subscription sub) {
    final refreshing = _refreshingIds.contains(sub.id);
    return Card(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Radio<String?>(
                                  value: sub.id,
                                  groupValue: _settings.activeSubscriptionId,
                                  onChanged: (v) => _setActiveSubscription(v),
                                ),
                                Expanded(
                                  child: Text(
                                    sub.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                refreshing
                                    ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.refresh_rounded),
                                        onPressed: () => _refreshOne(sub),
                                        tooltip: 'بروزرسانی',
                                      ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: Colors.redAccent),
                                  onPressed: () => _removeSubscription(sub),
                                  tooltip: 'حذف',
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                sub.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.dns_rounded,
                                      size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text('${_countFor(sub.id)} سرور',
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  if (sub.lastError != null)
                                    Expanded(
                                      child: Text(
                                        'خطا: ${sub.lastError}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.redAccent),
                                      ),
                                    )
                                  else if (sub.lastUpdated != null)
                                    Text(
                                      'آخرین بروزرسانی: ${_formatTime(sub.lastUpdated!)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'همین الان';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    return '${diff.inDays} روز پیش';
  }
}
