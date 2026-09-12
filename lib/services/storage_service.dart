import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';

/// لایه‌ی ساده‌ی ذخیره‌سازی روی SharedPreferences.
/// همه‌چیز به‌صورت JSON رشته‌ای ذخیره می‌شود تا وابستگی به دیتابیس نداشته باشیم.
class StorageService {
  static const _kSettingsKey = 'app_settings_v1';
  static const _kConfigsKey = 'vpn_configs_v2';
  static const _kSubscriptionsKey = 'subscriptions_v1';
  static const _kSelectedConfigIdKey = 'selected_config_id_v1';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettingsKey);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<VpnConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kConfigsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => VpnConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConfigs(List<VpnConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kConfigsKey,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<Subscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSubscriptionsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSubscriptions(List<Subscription> subs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSubscriptionsKey,
      jsonEncode(subs.map((s) => s.toJson()).toList()),
    );
  }

  Future<String?> loadSelectedConfigId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedConfigIdKey);
  }

  Future<void> saveSelectedConfigId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kSelectedConfigIdKey);
    } else {
      await prefs.setString(_kSelectedConfigIdKey, id);
    }
  }
}
