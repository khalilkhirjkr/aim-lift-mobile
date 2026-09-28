// lib/screens/incident_list_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import '../config.dart';
import '../services/token_store.dart';

// --------------------------------------------------
// INCIDENT MODEL
// --------------------------------------------------
class Incident {
  final int id;
  final String incidentType;
  final DateTime timestamp;
  final String premiseName;
  final String liftIdentifier;
  final String status;
  final DateTime? timeAttended;
  final bool isEmergency;
  final double? latitude;
  final double? longitude;

  Incident({
    required this.id,
    required this.incidentType,
    required this.timestamp,
    required this.premiseName,
    required this.liftIdentifier,
    required this.status,
    required this.isEmergency,
    this.timeAttended,
    this.latitude,
    this.longitude,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Incident(
      id: json['id'],
      incidentType: json['incident_type'] ?? 'N/A',
      timestamp: DateTime.parse(json['timestamp']),
      premiseName: json['premise_name'] ?? 'N/A',
      liftIdentifier: json['lift_identifier'] ?? 'N/A',
      status: json['status'] ?? 'N/A',
      timeAttended: json['time_attended'] != null
          ? DateTime.parse(json['time_attended'])
          : null,
      isEmergency: json['is_emergency'] ?? false,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
    );
  }

  bool metSla() {
    if (timeAttended == null) return false;
    final diff = timeAttended!.difference(timestamp);
    final slaThreshold = Duration(hours: isEmergency ? 4 : 24);
    return diff <= slaThreshold;
  }
}

// --------------------------------------------------
// MAIN INCIDENT LIST SCREEN
// --------------------------------------------------
class IncidentListScreen extends StatefulWidget {
  const IncidentListScreen({super.key});

  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  bool _isLoading = true;
  bool _isFetching = false;
  String? _error;
  List<Incident> _incidents = [];
  int _activeIncidentsCount = 0;
  int _slaPercentage = 100;
  List<Marker> _markers = [];
  final MapController _mapController = MapController();
  Timer? _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 10);

  // Hardcoded user info
  final String _userName = "Ir. Ts. Muhammad Khalil";
  final String _userGroup = "JKR";

  static final LatLng _kualaLumpur = LatLng(3.1390, 101.6869);
  static const double _initialZoom = 11.0;
  static const double _incidentZoom = 14.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (mounted) _fetchData();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------
  // FETCH INCIDENT DATA WITH JWT
  // --------------------------------------------------
  Future<void> _fetchData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final token = await TokenStore.read();

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _error = "User not authenticated. Please log in again.";
            _isLoading = false;
          });
        }
        return;
      }

      const apiBaseUrl = AppConfig.apiBaseUrl; // configured in lib/config.dart
      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(Uri.parse('$apiBaseUrl/incidents/'), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final incidents = data.map((e) => Incident.fromJson(e)).toList();

        _calculateKPIs(incidents);
        _updateMarkersAndFocus(incidents);

        if (mounted) {
          setState(() {
            _incidents = incidents;
            _isLoading = false;
            _error = null;
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        if (mounted) {
          setState(() {
            _error = "Session expired or unauthorized. Please log in again.";
            _isLoading = false;
          });
        }
        print("🚫 Auth failed with ${response.statusCode}");
      } else {
        if (mounted) {
          setState(() {
            _error = "Failed to load incidents (${response.statusCode}).";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("❌ Network error: $e");
      if (mounted) {
        setState(() {
          _error = 'Failed to connect to server. Check network.';
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  // --------------------------------------------------
  // KPI + MAP UPDATES
  // --------------------------------------------------
  void _calculateKPIs(List<Incident> incidents) {
    _activeIncidentsCount = incidents
        .where((i) => i.status == 'Detected')
        .length;
    final attended = incidents.where((i) => i.timeAttended != null).toList();
    if (attended.isNotEmpty) {
      final met = attended.where((i) => i.metSla()).length;
      _slaPercentage = ((met / attended.length) * 100).round();
    } else {
      _slaPercentage = 100;
    }
  }

  // ✅ FIXED: safely move map only after FlutterMap is ready
  void _updateMarkersAndFocus(List<Incident> incidents) {
    final markers = <Marker>[];
    final active = incidents.where((i) => i.status == 'Detected').toList();

    for (var inc in active) {
      if (inc.latitude != null && inc.longitude != null) {
        markers.add(
          Marker(
            width: 80,
            height: 80,
            point: LatLng(inc.latitude!, inc.longitude!),
            child: const Icon(Icons.location_pin, color: Colors.red, size: 35),
          ),
        );
      }
    }

    setState(() => _markers = markers);

    // ✅ Wait for map to build, then safely move
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Wait for first event from map — ensures controller is initialized
        await _mapController.mapEventStream.first;

        if (active.isNotEmpty && active.first.latitude != null) {
          _mapController.move(
            LatLng(active.first.latitude!, active.first.longitude!),
            _incidentZoom,
          );
        } else {
          _mapController.move(_kualaLumpur, _initialZoom);
        }
      } catch (e) {
        print("⚠️ Map not ready yet: $e");
      }
    });
  }

  Future<void> _handleLogout() async {
    await TokenStore.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // --------------------------------------------------
  // UI SECTION
  // --------------------------------------------------
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(''),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Image.asset('assets/images/AIMLogo.png', fit: BoxFit.contain),
      ),
      actions: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _userName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              _userGroup,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: CircleAvatar(
            backgroundImage: AssetImage('assets/images/man.png'),
            radius: 20,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildMapCard(),
                    const SizedBox(height: 12),
                    _buildKpiRow(),
                    const SizedBox(height: 12),
                    Expanded(child: _buildIncidentList()),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMapCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 150,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _kualaLumpur,
            initialZoom: _initialZoom,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.aim_lift_app',
            ),
            MarkerLayer(markers: _markers),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow() {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard('Active', _activeIncidentsCount.toString(), ''),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard('Attended', _slaPercentage.toString(), '%'),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String unit) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '$value$unit',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 7),
            child: Text(
              'Incident Details',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Expanded(
            child: _incidents.isEmpty
                ? const Center(child: Text('No incidents found.'))
                : ListView.builder(
                    itemCount: _incidents.length,
                    itemBuilder: (context, index) =>
                        _IncidentCard(incident: _incidents[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// INCIDENT CARD WIDGET
// --------------------------------------------------
class _IncidentCard extends StatelessWidget {
  final Incident incident;
  const _IncidentCard({required this.incident});

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd-MMM-yyyy hh:mm a').format(dt.toLocal());
  }

  Future<void> _launchMaps(
    double? lat,
    double? lng,
    BuildContext context,
  ) async {
    if (lat == null || lng == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location coordinates are not available.'),
        ),
      );
      return;
    }

    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    print('🌍 Launching: $googleMapsUrl');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $googleMapsUrl';
      }
    } catch (e) {
      print('Error launching maps: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                incident.incidentType,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                label: Text(
                  incident.status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.blue[100],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_city_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  incident.premiseName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.elevator_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  incident.liftIdentifier,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_filled, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Occurred: ${_formatDateTime(incident.timestamp)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.person_pin_circle_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Attended: ${_formatDateTime(incident.timeAttended)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          if (incident.latitude != null && incident.longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text(
                    'Get Direction',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue[700],
                  ),
                  onPressed: () => _launchMaps(
                    incident.latitude,
                    incident.longitude,
                    context,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
