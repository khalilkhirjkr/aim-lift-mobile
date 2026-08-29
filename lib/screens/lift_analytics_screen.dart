import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../config.dart';

class LiftAnalyticsScreen extends StatefulWidget {
  const LiftAnalyticsScreen({super.key});

  @override
  State<LiftAnalyticsScreen> createState() => _LiftAnalyticsScreenState();
}

class _LiftAnalyticsScreenState extends State<LiftAnalyticsScreen> {
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic> _contractorStats = {};
  List<dynamic> _liftReliability = [];

  String? _selectedContractor = "TITI MAJU SDN. BHD."; // ✅ Default filter
  String? _selectedLift = "WP PMA 80271"; // ✅ Default filter

  final String _userName = "Ir. Ts. Muhammad Khalil";
  final String _userGroup = "JKR";

  final String apiUrl = '${AppConfig.apiBaseUrl}/analytics/full/';

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        setState(() {
          _contractorStats = data['contractor_stats'] ?? {};
          _liftReliability = data['lift_reliability'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = "Error ${response.statusCode}: Failed to load analytics.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Failed to connect to server.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _fetchAnalyticsData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContractorCard(),
                    const SizedBox(height: 12),
                    _buildReliabilityCard(),
                  ],
                ),
              ),
            ),
    );
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

  Widget _buildError() => Center(
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchAnalyticsData,
            child: const Text("Retry"),
          ),
        ],
      ),
    ),
  );

  // --- Contractor Performance Card ---
  Widget _buildContractorCard() {
    final contractors = _contractorStats.keys.toList();

    final filteredContractor =
        _selectedContractor != null &&
            _contractorStats.containsKey(_selectedContractor)
        ? {_selectedContractor!: _contractorStats[_selectedContractor]!}
        : _contractorStats;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header and Dropdown ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    "Contractor Performance (Average)",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedContractor,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.filter_alt_rounded, size: 20),
                    items: [
                      ...contractors.map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedContractor = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildContractorCharts(filteredContractor),
          ],
        ),
      ),
    );
  }

  Widget _buildContractorCharts(Map<String, dynamic> filteredStats) {
    final labels = filteredStats.keys.toList();
    final mtta = labels
        .map((k) => (filteredStats[k]['mtta'] ?? 0.0).toDouble())
        .toList()
        .cast<double>();
    final mttr = labels
        .map((k) => (filteredStats[k]['mttr'] ?? 0.0).toDouble())
        .toList()
        .cast<double>();

    if (labels.isEmpty) {
      return const Text("No contractor data available.");
    }

    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildBarChart("MTTA (Hours)", Colors.blue, labels, mtta),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildBarChart("MTTR (Hours)", Colors.orange, labels, mttr),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(
    String title,
    Color color,
    List<String> labels,
    List<double> data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: List.generate(labels.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i],
                      color: color,
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, _) {
                      final index = value.toInt();
                      return index < labels.length
                          ? Text(
                              labels[index],
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            )
                          : const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) => Text(
                      value.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  // --- Lift Reliability Card ---
  Widget _buildReliabilityCard() {
    final lifts = _liftReliability
        .map((e) => e['lift_identifier'] as String)
        .toList();

    final filteredLifts = _selectedLift != null
        ? _liftReliability
              .where((e) => e['lift_identifier'] == _selectedLift)
              .toList()
        : _liftReliability;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header and Dropdown ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    "Lift Reliability (Estimated MTBF)",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedLift,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.filter_alt_rounded, size: 20),
                    items: [
                      ...lifts.map(
                        (id) => DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            id,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedLift = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filteredLifts.isEmpty)
              const Text(
                "No lift data available.",
                style: TextStyle(color: Colors.grey),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredLifts.length,
                itemBuilder: (context, index) {
                  final lift = filteredLifts[index];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lift['lift_identifier'] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        "(${lift['total_incidents']} incidents)",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lift['mtbf'] ?? '',
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
                separatorBuilder: (_, __) => const Divider(),
              ),
            const SizedBox(height: 8),
            const Text(
              "*MTBF = Mean Time Between Failures (Higher is better).",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
