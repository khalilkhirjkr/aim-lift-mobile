import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/token_store.dart';

class LiftHealthScreen extends StatefulWidget {
  const LiftHealthScreen({super.key});

  @override
  State<LiftHealthScreen> createState() => _LiftHealthScreenState();
}

class _LiftHealthScreenState extends State<LiftHealthScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _healthData = {};
  Map<String, dynamic> _sensorData = {};

  @override
  void initState() {
    super.initState();
    _fetchHealthData();

    // 🔁 Auto refresh every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (_) => _fetchHealthData());
  }

  Future<String?> _getAuthToken() async {
    return TokenStore.read();
  }

  Future<void> _fetchHealthData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _error = 'Not authenticated.';
        });
        return;
      }

      // Base URL is configured in lib/config.dart
      final apiUrl = '${AppConfig.apiBaseUrl}/lifts/1/health/';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _healthData = data;
          _sensorData = Map<String, dynamic>.from(
            data['sensor_readings'] ?? {},
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to fetch data. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error fetching data: $e';
      });
    }
  }

  // --- 🧩 Custom AppBar (matches IncidentListScreen) ---
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        '',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Image.asset('assets/images/AIMLogo.png'),
      ),
      actions: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Text(
              'Ir. Ts. Muhammad Khalil',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text('JKR', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: CircleAvatar(
            backgroundImage: AssetImage('assets/images/man.png'),
            radius: 20,
          ),
        ),
      ],
    );
  }

  // --- 🧠 Health Status Card ---
  Widget _buildHealthStatusCard() {
    if (_healthData.isEmpty) return const SizedBox.shrink();

    final status = _healthData['status'] ?? 'Unknown';
    final predicted = _healthData['predicted'] ?? '-';
    final confidence = _healthData['confidence'] ?? 0.0;

    Color bgColor = Colors.green[50]!;
    Color textColor = Colors.green[800]!;

    if (status == 'Failure Warning') {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Current Health Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Predicted: $predicted',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          Text(
            'Confidence: ${confidence.toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // --- 📊 Dynamic Sensor Grid (scrollable only) ---
  Widget _buildSensorReadings(Map<String, dynamic> sensorData) {
    if (sensorData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No sensor data available.'),
        ),
      );
    }

    final labels = sensorData.keys.toList();
    final values = sensorData.values.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.3,
        ),
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final label = labels[index];
          final value = values[index];
          final displayValue = (value is num)
              ? value.toStringAsFixed(2)
              : value.toString();

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2, // ✅ allows wrapping of long labels
                ),
                const SizedBox(height: 6),
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchHealthData,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🧩 Fixed health card
                _buildHealthStatusCard(),

                // 🧩 Section title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Latest Sensor Readings",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                // 🧩 Scrollable sensor grid
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchHealthData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: _buildSensorReadings(_sensorData),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
