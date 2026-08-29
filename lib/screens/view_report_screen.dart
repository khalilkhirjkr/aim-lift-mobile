// lib/screens/view_report_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class ViewReportScreen extends StatefulWidget {
  final int incidentId;

  const ViewReportScreen({super.key, required this.incidentId});

  @override
  State<ViewReportScreen> createState() => _ViewReportScreenState();
}

class _ViewReportScreenState extends State<ViewReportScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/report/view/${widget.incidentId}/',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _error = 'No report data found (404).';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${response.statusCode}: Failed to load analytics.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildTextBox(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            height: 2,
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.isEmpty ? "No data recorded." : value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Report Details'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _fetchReportData,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : _reportData == null
          ? const Center(child: Text("No report data found."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _reportData!['report_acknowledged_by_jkr']
                          ? Colors.blue
                          : _reportData!['contractor_acknowledgement']
                          ? Colors.orange
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _reportData!['report_acknowledged_by_jkr']
                            ? "Acknowledged by JKR"
                            : _reportData!['contractor_acknowledgement']
                            ? "Acknowledged by Contractor"
                            : "Pending Review",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔹 A. Incident Details
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            "Premise",
                            _reportData!['premise_name'] ?? "N/A",
                          ),
                          _buildInfoRow(
                            "Lift ID",
                            _reportData!['lift_identifier'] ?? "N/A",
                          ),
                          _buildInfoRow(
                            "Incident Type",
                            _reportData!['incident_type'] ?? "N/A",
                          ),
                          _buildInfoRow(
                            "Status",
                            _reportData!['status'] ?? "N/A",
                          ),
                          _buildInfoRow(
                            "Report Submitted At",
                            _reportData!['report_submitted_at'] ?? "N/A",
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔹 B. Incident Description
                  _buildTextBox(
                    "Symptom",
                    _reportData!['symptom'] ?? "No symptom provided.",
                  ),
                  _buildTextBox(
                    "Direct Cause",
                    _reportData!['direct_cause'] ?? "No direct cause recorded.",
                  ),

                  // 🔹 C. Root Cause (4M)
                  const SizedBox(height: 8),
                  const Text(
                    "Root Cause Analysis (4M)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 2,
                    ),
                  ),
                  _buildInfoRow("Method", _reportData!['rc_method'] ?? "N/A"),
                  _buildInfoRow("Man", _reportData!['rc_man'] ?? "N/A"),
                  _buildInfoRow(
                    "Material",
                    _reportData!['rc_material'] ?? "N/A",
                  ),
                  _buildInfoRow("Machine", _reportData!['rc_machine'] ?? "N/A"),

                  const SizedBox(height: 12),

                  // 🔹 D. Corrective Actions
                  _buildTextBox(
                    "Corrective Action",
                    _reportData!['corrective_action'] ?? "",
                  ),
                  _buildTextBox(
                    "Permanent Action",
                    _reportData!['permanent_action'] ?? "",
                  ),

                  // 🔹 Attachments
                  if (_reportData!['corrective_action_proof'] != null)
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Proof: ${_reportData!['corrective_action_proof']}",
                            ),
                          ),
                        );
                      },
                      child: const Text("View Corrective Proof"),
                    ),
                  if (_reportData!['permanent_action_proof'] != null)
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Proof: ${_reportData!['permanent_action_proof']}",
                            ),
                          ),
                        );
                      },
                      child: const Text("View Permanent Proof"),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
