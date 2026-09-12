import 'package:flutter/material.dart';
import '../models/vpn_config.dart';
import 'app_filter_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final Future<void> Function(AppSettings) onSave;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _refreshHours;
  late double _pingSeconds;
  late double _switchImprovement;
  late double _maxLiveServers;
  late bool _autoSwitch;
  late List<String> _excludedApps;

  @override
  void initState() {
    super.initState();
    _refreshHours = widget.settings.subscriptionRefreshHours.toDouble();
    _pingSeconds = widget.settings.pingIntervalSeconds.toDouble();
    _switchImprovement = widget.settings.switchImprovementMs.toDouble();
    _maxLiveServers = widget.settings.maxServersToPingLive.toDouble();
    _autoSwitch = widget.settings.autoSwitchEnabled;
    _excludedApps = List<String>.from(widget.settings.excludedAppPackages);
  }

  Future<void> _save() async {
    final newSettings = AppSettings(
      subscriptionRefreshHours: _refreshHours.round(),
      pingIntervalSeconds: _pingSeconds.round(),
      autoSwitchEnabled: _autoSwitch,
      switchImprovementMs: _switchImprovement.round(),
      maxServersToPingLive: _maxLiveServers.round(),
      excludedAppPackages: _excludedApps,
    );
    await widget.onSave(newSettings);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: const Text('تفکیک برنامه‌ها'),
              subtitle: Text(
                _excludedApps.isEmpty
                    ? 'همه‌ی برنامه‌ها از VPN رد می‌شوند'
                    : '${_excludedApps.length} برنامه از VPN مستثنا هستند',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppFilterScreen(
                      initiallyExcluded: _excludedApps,
                      onSave: (list) async {
                        setState(() => _excludedApps = list);
                      },
                    ),
                  ),
                );
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('بروزرسانی خودکار ساب‌اسکریپشن‌ها هر ${_refreshHours.round()} ساعت'),
          Slider(
            value: _refreshHours,
            min: 1,
            max: 24,
            divisions: 23,
            label: '${_refreshHours.round()}h',
            onChanged: (v) => setState(() => _refreshHours = v),
          ),
          const Divider(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('اتصال خودکار به بهترین سرور'),
            subtitle: const Text(
              'روشن: هم موقع زدن دکمه‌ی اتصال، هم حین استفاده، همیشه سریع‌ترین '
              'سرور پیدا و انتخاب می‌شود.\n'
              'خاموش: فقط به همان سروری که خودت قبلاً انتخاب کرده‌ای وصل '
              'می‌شود و جابجا نمی‌کند.',
            ),
            value: _autoSwitch,
            onChanged: (v) => setState(() => _autoSwitch = v),
          ),
          Text('فاصله‌ی پینگ‌گیری زنده: هر ${_pingSeconds.round()} ثانیه'),
          Slider(
            value: _pingSeconds,
            min: 10,
            max: 120,
            divisions: 22,
            label: '${_pingSeconds.round()}s',
            onChanged: (v) => setState(() => _pingSeconds = v),
          ),
          Text('حداقل بهبود پینگ برای سوییچ: ${_switchImprovement.round()}ms'),
          Slider(
            value: _switchImprovement,
            min: 20,
            max: 300,
            divisions: 28,
            label: '${_switchImprovement.round()}ms',
            onChanged: (v) => setState(() => _switchImprovement = v),
          ),
          Text('حداکثر تعداد سرور برای پینگ زنده: ${_maxLiveServers.round()}'),
          Slider(
            value: _maxLiveServers,
            min: 2,
            max: 20,
            divisions: 18,
            label: '${_maxLiveServers.round()}',
            onChanged: (v) => setState(() => _maxLiveServers = v),
          ),
          const SizedBox(height: 8),
          const Text(
            'توجه: کاهش این عدد باتری کمتری مصرف می‌کند اما شانس پیدا کردن سریع‌ترین سرور را کم می‌کند.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
