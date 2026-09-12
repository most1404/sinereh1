import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import '../models/vpn_config.dart';

const List<String> _kSupportedSchemes = [
  'vmess://',
  'vless://',
  'trojan://',
  'ss://',
];

class SubscriptionFetchException implements Exception {
  final String message;
  SubscriptionFetchException(this.message);
  @override
  String toString() => message;
}

class SubscriptionService {
  /// یک لینک ساب‌اسکریپشن را می‌گیرد، دانلود می‌کند، در صورت نیاز base64 را
  /// دیکد می‌کند و لینک‌های vmess/vless/trojan/ss داخلش را به VpnConfig تبدیل می‌کند.
  /// [subscriptionId] برای مشخص‌کردن اینکه هر کانفیگ متعلق به کدام ساب است.
  Future<List<VpnConfig>> fetchSubscription(
    String url, {
    required String subscriptionId,
  }) async {
    if (url.trim().isEmpty) {
      throw SubscriptionFetchException('آدرس ساب‌اسکریپشن خالی است.');
    }

    late http.Response response;
    try {
      response = await http
          .get(Uri.parse(url.trim()))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw SubscriptionFetchException('اتصال به لینک ساب‌اسکریپشن ناموفق بود: $e');
    }

    if (response.statusCode != 200) {
      throw SubscriptionFetchException(
        'سرور ساب‌اسکریپشن خطای HTTP ${response.statusCode} برگرداند.',
      );
    }

    final body = response.body.trim();
    final decodedText = _decodeBody(body);
    final lines = decodedText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => _kSupportedSchemes.any((s) => l.startsWith(s)))
        .toList();

    if (lines.isEmpty) {
      throw SubscriptionFetchException(
        'هیچ کانفیگ قابل‌شناسایی (vmess/vless/trojan/ss) در ساب‌اسکریپشن پیدا نشد.',
      );
    }

    final result = <VpnConfig>[];
    final seen = <String>{};
    for (final link in lines) {
      if (seen.contains(link)) continue;
      seen.add(link);
      try {
        final parsed = V2ray.parseFromURL(link);
        final protocol = link.split('://').first;
        result.add(
          VpnConfig(
            id: link, // خودِ لینک به‌عنوان شناسه‌ی پایدار
            rawLink: link,
            subscriptionId: subscriptionId,
            remark: parsed.remark.trim().isEmpty
                ? '$protocol-${result.length + 1}'
                : parsed.remark.trim(),
            protocol: protocol,
          ),
        );
      } catch (_) {
        // لینک نامعتبر یا پروتکل پشتیبانی‌نشده -> نادیده گرفته می‌شود
        continue;
      }
    }

    if (result.isEmpty) {
      throw SubscriptionFetchException(
        'هیچ کانفیگ معتبری پس از پارس کردن باقی نماند.',
      );
    }
    return result;
  }

  String _decodeBody(String body) {
    // اگر محتوا از قبل شامل لینک‌های خام است، همان را برگردان.
    if (_kSupportedSchemes.any((s) => body.contains(s))) {
      return body;
    }
    // در غیر این صورت تلاش برای دیکد base64 (رایج‌ترین فرمت ساب‌اسکریپشن).
    try {
      var normalized = body.replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized.padRight(
        normalized.length + (4 - normalized.length % 4) % 4,
        '=',
      );
      return utf8.decode(base64.decode(padded));
    } catch (_) {
      // نتوانستیم دیکد کنیم؛ همان متن خام را برگردان تا فیلتر بالا تصمیم بگیرد.
      return body;
    }
  }

  /// ادغام هوشمند: کانفیگ‌های جدید یک ساب را می‌گیرد ولی تاریخچه‌ی پینگِ
  /// کانفیگ‌های قبلیِ هنوز موجود (با همان id) را حفظ می‌کند.
  List<VpnConfig> mergeWithExisting(
    List<VpnConfig> freshConfigs,
    List<VpnConfig> existingConfigs,
  ) {
    final existingById = {for (final c in existingConfigs) c.id: c};
    for (final fresh in freshConfigs) {
      final old = existingById[fresh.id];
      if (old != null) {
        fresh.lastDelayMs = old.lastDelayMs;
        fresh.lastTestedAt = old.lastTestedAt;
      }
    }
    return freshConfigs;
  }
}
