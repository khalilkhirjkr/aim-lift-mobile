import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class SubmitReportScreen extends StatefulWidget {
  final Map incidentData;
  const SubmitReportScreen({super.key, required this.incidentData});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController directCauseController = TextEditingController();
  final TextEditingController rcMachineController = TextEditingController();
  final TextEditingController rcMethodController = TextEditingController();
  final TextEditingController rcManController = TextEditingController();
  final TextEditingController rcMaterialController = TextEditingController();
  final TextEditingController correctiveActionController =
      TextEditingController();
  final TextEditingController permanentActionController =
      TextEditingController();

  bool contractorAcknowledgement = false;
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('authToken');
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/submit_report/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "incident_id": widget.incidentData["id"],
          "direct_cause": directCauseController.text,
          "rc_machine": rcMachineController.text,
          "rc_method": rcMethodController.text,
          "rc_man": rcManController.text,
          "rc_material": rcMaterialController.text,
          "corrective_action": correctiveActionController.text,
          "permanent_action": permanentActionController.text,
          "acknowledged": contractorAcknowledgement,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report submitted successfully!")),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Network error: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.incidentData;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Submit Incident Report"),
        centerTitle: true,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(i),
                    const SizedBox(height: 12),
                    _buildTextField("Direct Cause", directCauseController),
                    const SizedBox(height: 12),
                    const Text(
                      "Root Cause Analysis (4M)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _buildTextField("Machine (Equipment)", rcMachineController),
                    _buildTextField("Method", rcMethodController),
                    _buildTextField("Man (Personnel)", rcManController),
                    _buildTextField("Material", rcMaterialController),
                    const SizedBox(height: 12),
                    const Text(
                      "Rectification Works",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _buildTextField(
                      "Corrective Action Taken",
                      correctiveActionController,
                    ),
                    _buildTextField(
                      "Permanent Action",
                      permanentActionController,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text(
                        "I hereby declare that all information provided is accurate.",
                      ),
                      value: contractorAcknowledgement,
                      onChanged: (val) => setState(
                        () => contractorAcknowledgement = val ?? false,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: const Text("Submit Report"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(Map i) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Premise: ${i["premise_name"] ?? 'N/A'}"),
            Text("Lift ID: ${i["lift_identifier"] ?? 'N/A'}"),
            Text("Incident Type: ${i["incident_type"] ?? 'N/A'}"),
            Text("Detected: ${i["timestamp"] ?? '-'}"),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: null,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'This field is required' : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
