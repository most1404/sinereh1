import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

/// این صفحه لیست برنامه‌های نصب‌شده روی گوشی را نشان می‌دهد تا کاربر
/// انتخاب کند کدام‌ها از تونل VPN «رد نشوند» (ترافیک مستقیم/بدون فیلترشکن).
/// خروجی یک لیست از packageName هاست که به‌عنوان blockedApps به
/// flutter_v2ray_client داده می‌شود.
class AppFilterScreen extends StatefulWidget {
  final List<String> initiallyExcluded;
  final Future<void> Function(List<String>) onSave;

  const AppFilterScreen({
    super.key,
    required this.initiallyExcluded,
    required this.onSave,
  });

  @override
  State<AppFilterScreen> createState() => _AppFilterScreenState();
}

class _AppFilterScreenState extends State<AppFilterScreen> {
  List<AppInfo> _apps = [];
  bool _loading = true;
  String? _error;
  late Set<String> _excluded;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _excluded = widget.initiallyExcluded.toSet();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() => _apps = apps);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AppInfo> get _filtered {
    if (_query.trim().isEmpty) return _apps;
    final q = _query.trim().toLowerCase();
    return _apps
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _save() async {
    await widget.onSave(_excluded.toList());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفکیک برنامه‌ها'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'برنامه‌هایی که تیک بخورند، از تونل VPN رد نمی‌شوند و '
                  'با اینترنت مستقیم گوشی کار می‌کنند.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'جستجوی برنامه...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          if (_excluded.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('${_excluded.length} برنامه انتخاب شده',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text('خطا در خواندن لیست برنامه‌ها:\n$_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadApps, child: const Text('تلاش دوباره')),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(child: Text('برنامه‌ای پیدا نشد.'));
    }
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final app = _filtered[index];
        final isExcluded = _excluded.contains(app.packageName);
        return CheckboxListTile(
          value: isExcluded,
          onChanged: (v) {
            setState(() {
              if (v == true) {
                _excluded.add(app.packageName);
              } else {
                _excluded.remove(app.packageName);
              }
            });
          },
          secondary: app.icon != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(app.icon!, width: 36, height: 36),
                )
              : const Icon(Icons.apps_rounded),
          title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(app.packageName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }
}
