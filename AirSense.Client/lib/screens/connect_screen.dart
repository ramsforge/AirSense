import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/discovery_service.dart';
import '../services/network_service.dart';
import 'controller_screen.dart';

class ConnectScreen extends StatefulWidget {
  final NetworkService network;

  const ConnectScreen({super.key, required this.network});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController =
      TextEditingController(text: '9050');
  bool _isScanning = false;
  bool _isConnecting = false;
  List<DiscoveredHost> _discoveredHosts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
    _startScan();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('last_host_ip') ?? '';
    if (savedIp.isNotEmpty && mounted) {
      _ipController.text = savedIp;
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    final hosts = await DiscoveryService.findHosts();
    if (mounted) {
      setState(() {
        _discoveredHosts = hosts;
        _isScanning = false;
      });
    }
  }

  Future<void> _connect(String ip, int port) async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final success = await widget.network.connect(ip, port);

    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_host_ip', ip);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ControllerScreen(network: widget.network),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              'Could not connect to $ip:$port. Ensure AirSense.Server is running.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: Color(0xFF00C8FF)),
            SizedBox(width: 10),
            Text('AirSense', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF161A23),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00C8FF),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Rescan LAN',
            onPressed: _startScan,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C2230), Color(0xFF131720)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E384C)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_tethering,
                      size: 36, color: Color(0xFF00C8FF)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wi-Fi LAN Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ensure your phone and PC are connected to the same Wi-Fi router.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text(
              'DISCOVERED COMPUTERS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            if (_discoveredHosts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A23),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF222938)),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isScanning
                          ? Icons.radar
                          : Icons.phonelink_off_outlined,
                      size: 32,
                      color: Colors.white30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning
                          ? 'Searching for AirSense Host on LAN...'
                          : 'No PCs found automatically. Enter IP below.',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ..._discoveredHosts.map(
                (host) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B212D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2D374A)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF2A3447),
                        child: Icon(Icons.computer,
                            color: Color(0xFF00C8FF), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              host.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${host.ip}:${host.port}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isConnecting
                            ? null
                            : () => _connect(host.ip, host.port),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003791),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 30),
            const Text(
              'MANUAL CONNECTION',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Host IP Address',
                      hintText: 'e.g. 192.168.1.50',
                      labelStyle: const TextStyle(color: Colors.white54),
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF161A23),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF283042)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF283042)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Port',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF161A23),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF283042)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF283042)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isConnecting ? 'Connecting...' : 'Connect to Host',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isConnecting
                    ? null
                    : () {
                        final ip = _ipController.text.trim();
                        final port =
                            int.tryParse(_portController.text.trim()) ?? 9050;
                        if (ip.isNotEmpty) {
                          _connect(ip, port);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
