import 'package:flutter/material.dart';
import '../models/vpn_config.dart';
import '../services/ping_service.dart';

class ServersScreen extends StatefulWidget {
  final List<VpnConfig> configs;
  final String? selectedConfigId;
  final PingService pingService;
  final void Function(VpnConfig config) onSelect;
  final Future<void> Function() onPersist;

  const ServersScreen({
    super.key,
    required this.configs,
    required this.selectedConfigId,
    required this.pingService,
    required this.onSelect,
    required this.onPersist,
  });

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  bool _testingAll = false;

  List<VpnConfig> get _sorted {
    final list = List<VpnConfig>.from(widget.configs);
    list.sort((a, b) {
      final da = a.lastDelayMs, db = b.lastDelayMs;
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

  Future<void> _testAll() async {
    setState(() => _testingAll = true);
    await widget.pingService.pingAll(widget.configs);
    await widget.onPersist();
    if (mounted) setState(() => _testingAll = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('همه‌ی سرورها (${widget.configs.length})'),
        actions: [
          IconButton(
            icon: _testingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.speed),
            onPressed: _testingAll ? null : _testAll,
            tooltip: 'تست پینگ همه',
          ),
        ],
      ),
      body: widget.configs.isEmpty
          ? const Center(child: Text('سروری وجود ندارد.'))
          : ListView.separated(
              itemCount: _sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = _sorted[index];
                final isSelected = c.id == widget.selectedConfigId;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.dns_outlined,
                    color: isSelected ? Colors.green : null,
                  ),
                  title: Text(c.remark, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(c.protocol.toUpperCase()),
                  trailing: Text(
                    c.lastDelayMs == null
                        ? '—'
                        : (c.lastDelayMs! < 0 ? 'خطا' : '${c.lastDelayMs}ms'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: c.lastDelayMs != null && c.lastDelayMs! >= 0
                          ? (c.lastDelayMs! < 150
                              ? Colors.green
                              : (c.lastDelayMs! < 400 ? Colors.orange : Colors.red))
                          : Colors.grey,
                    ),
                  ),
                  onTap: () {
                    widget.onSelect(c);
                    Navigator.pop(context);
                  },
                );
              },
            ),
    );
  }
}
