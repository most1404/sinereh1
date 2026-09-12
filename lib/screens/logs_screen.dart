import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// این صفحه لاگ‌های واقعیِ هسته‌ی V2Ray/Xray را نشان می‌دهد — دقیقاً همان
/// چیزی که وقتی اتصال شکست می‌خورد یا فیلترشکن کار نمی‌کند، علت واقعی‌اش
/// را مشخص می‌کند. خیلی دقیق‌تر از حدس‌زدن از روی توضیح یا اسکرین‌شاته.
class LogsScreen extends StatefulWidget {
  final V2ray v2ray;
  const LogsScreen({super.key, required this.v2ray});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<String> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await widget.v2ray.getLogs();
      setState(() => _logs = logs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    try {
      await widget.v2ray.clearLogs();
    } catch (_) {}
    await _load();
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('همه‌ی لاگ‌ها کپی شد.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لاگ‌های فنی'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load, tooltip: 'بروزرسانی'),
          IconButton(icon: const Icon(Icons.copy_rounded), onPressed: _logs.isEmpty ? null : _copyAll, tooltip: 'کپی همه'),
          IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _clear, tooltip: 'پاک کردن'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('خطا در خواندن لاگ‌ها:\n$_error', textAlign: TextAlign.center),
                  ),
                )
              : _logs.isEmpty
                  ? const Center(child: Text('هنوز لاگی ثبت نشده.\nیک‌بار وصل/قطع کن، بعد اینجا رو بروزرسانی کن.', textAlign: TextAlign.center))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: SelectableText(
                          _logs[index],
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
    );
  }
}
