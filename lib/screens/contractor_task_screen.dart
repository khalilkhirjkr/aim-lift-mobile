import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'submit_report_screen.dart';
import 'view_report_screen.dart';
import '../config.dart';
import '../services/token_store.dart';

class ContractorTaskScreen extends StatefulWidget {
  const ContractorTaskScreen({super.key});

  @override
  State<ContractorTaskScreen> createState() => _ContractorTaskScreenState();
}

class _ContractorTaskScreenState extends State<ContractorTaskScreen> {
  bool _isLoading = true;
  String? _error;
  double reportOnTime = 0;
  double contractorReliability = 0;
  List incidents = [];

  final String baseUrl = AppConfig.apiBaseUrl; // configured in lib/config.dart
  Timer? _refreshTimer;

  final String _userName = "Ir. Ts. Muhammad Khalil";
  final String _userGroup = "JKR";

  @override
  void initState() {
    super.initState();
    _fetchDashboardData(initial: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchDashboardData(initial: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

  Future<void> _fetchDashboardData({bool initial = false}) async {
    if (initial) setState(() => _isLoading = true);

    try {
      final token = await TokenStore.read();
      if (token == null) {
        if (initial) setState(() => _error = 'Not authenticated.');
        return;
      }

      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      };

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/contractor/dashboard/'), headers: headers),
        http.get(Uri.parse('$baseUrl/incidents/'), headers: headers),
      ]);

      final dashboardRes = results[0];
      final incidentsRes = results[1];

      if (dashboardRes.statusCode == 200 && incidentsRes.statusCode == 200) {
        final dashboardData = jsonDecode(dashboardRes.body);
        final incidentsData = jsonDecode(incidentsRes.body);

        if (mounted) {
          setState(() {
            reportOnTime = dashboardData["report_on_time"]?.toDouble() ?? 100;
            contractorReliability =
                dashboardData["contractor_reliability"]?.toDouble() ?? 100;
            incidents = incidentsData;
            _error = null;
            _isLoading = false;
          });
        }
      } else {
        if (initial && mounted) {
          setState(() {
            _error =
                "Server responded with ${dashboardRes.statusCode} / ${incidentsRes.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (initial && mounted) {
        setState(() {
          _error = "Network error: $e";
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(String? dt) {
    if (dt == null) return '-';
    try {
      final parsed = DateTime.parse(dt).toLocal();
      return DateFormat('dd-MMM-yyyy hh:mm a').format(parsed);
    } catch (_) {
      return dt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                  child: _buildKpiRow(),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    "Incident Reports & Actions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _fetchDashboardData(initial: true),
                    child: incidents.isEmpty
                        ? const Center(child: Text("No incidents found."))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: incidents.length,
                            itemBuilder: (context, index) {
                              final i = incidents[index];
                              return _buildIncidentCard(i);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiRow() {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            "Report Submission On-Time",
            reportOnTime,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard(
            "Contractor Reliability\n(JKR Acknowledged)",
            contractorReliability,
            Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, double value, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              "${value.toStringAsFixed(0)}%",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(Map i) {
    final String status = i["status"] ?? "N/A";
    final String incidentType = i["incident_type"] ?? "Unknown";

    // 🔹 Button label & color logic
    String buttonLabel = "Submit Report";
    Color buttonColor = Colors.blue;

    if (status == "Resolved" || status == "JKR Approved") {
      buttonLabel = "See Report";
      buttonColor = Colors.grey.shade700;
    } else if (status == "Pending Review" || status == "Correction Required") {
      buttonLabel = "View Report";
      buttonColor = Colors.orange.shade700;
    }

    // 🔹 Status badge colors
    Color badgeColor;
    Color textColor;

    switch (status) {
      case "Pending Submission":
        badgeColor = const Color(0xFFFFF3CD);
        textColor = const Color(0xFF856404);
        break;
      case "Pending Review":
        badgeColor = const Color(0xFFD1ECF1);
        textColor = const Color(0xFF0C5460);
        break;
      case "Correction Required":
        badgeColor = const Color(0xFFF8D7DA);
        textColor = const Color(0xFF721C24);
        break;
      case "Resolved":
        badgeColor = const Color(0xFFD4EDDA);
        textColor = const Color(0xFF155724);
        break;
      case "JKR Approved":
        badgeColor = const Color(0xFFDDEAFE);
        textColor = const Color(0xFF004085);
        break;
      default:
        badgeColor = Colors.grey.shade200;
        textColor = Colors.black87;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  incidentType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              i["premise_name"] ?? "N/A",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              "Lift ID: ${i["lift_identifier"] ?? '-'}",
              style: const TextStyle(fontSize: 13),
            ),
            const Divider(height: 16),
            _buildInfoRow("Detected", _formatDateTime(i["timestamp"])),
            _buildInfoRow("Attended", _formatDateTime(i["time_attended"])),
            _buildInfoRow("Report Due", _formatDateTime(i["report_due"])),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  if (buttonLabel == "Submit Report") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SubmitReportScreen(incidentData: i),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ViewReportScreen(incidentId: i["id"]),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
