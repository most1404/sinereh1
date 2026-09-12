import 'dart:async';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import '../models/vpn_config.dart';

/// تست تاخیر (ping) روی لیستی از کانفیگ‌ها، با محدودیت همزمانی تا فشار
/// زیادی روی شبکه/باتری وارد نشود. نتیجه مستقیماً روی خودِ آبجکت‌های
/// VpnConfig نوشته می‌شود (lastDelayMs / lastTestedAt).
class PingService {
  final V2ray v2ray;
  PingService(this.v2ray);

  Future<void> pingAll(
    List<VpnConfig> configs, {
    int concurrency = 2,
    Duration perRequestTimeout = const Duration(seconds: 5),
  }) async {
    final queue = List<VpnConfig>.from(configs);
    final workers = List.generate(concurrency, (_) => _worker(queue, perRequestTimeout));
    await Future.wait(workers);
  }

  Future<void> _worker(List<VpnConfig> queue, Duration timeout) async {
    while (queue.isNotEmpty) {
      final VpnConfig config;
      try {
        config = queue.removeLast();
      } catch (_) {
        return; // یکی دیگر آخرین آیتم را برداشت
      }
      await pingOne(config, timeout: timeout);
    }
  }

  Future<int> pingOne(
    VpnConfig config, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final parsed = V2ray.parseFromURL(config.rawLink);
      final delay = await v2ray
          .getServerDelay(config: parsed.getFullConfiguration())
          .timeout(timeout);
      config.lastDelayMs = delay;
    } catch (_) {
      config.lastDelayMs = -1; // غیرقابل‌دسترس / تایم‌اوت
    }
    config.lastTestedAt = DateTime.now();
    return config.lastDelayMs ?? -1;
  }

  /// برخلاف pingOne (که یک کانفیگ دلخواه را تست می‌کند)، این متد فقط
  /// همان تونل V2Ray که الان واقعاً متصل است را تست می‌کند. این تنها
  /// روش امنیه که باید حین اتصال استفاده بشه، چون تست هم‌زمانِ چند
  /// کانفیگ دیگر با تونل فعال می‌تونه باعث قطعی فیلترشکن یا کرش بشه.
  Future<int> pingConnectedOnly({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      return await v2ray.getConnectedServerDelay().timeout(timeout);
    } catch (_) {
      return -1;
    }
  }
}
