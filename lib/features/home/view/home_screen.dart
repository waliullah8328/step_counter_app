import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';

import '../view_model/step_view_model.dart';

class StepScreen extends ConsumerStatefulWidget {
  const StepScreen({super.key});

  @override
  ConsumerState<StepScreen> createState() => _StepScreenState();
}

class _StepScreenState extends ConsumerState<StepScreen> {
  String _timePeriod = 'Today'; // default view

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stepControllerProvider);
    final controller = ref.read(stepControllerProvider.notifier);

    int dailyGoal = 10000;
    List<DaySteps> allData = state.allHistory;

    // Filter data by selected period
    DateTime now = DateTime.now();
    List<DaySteps> filteredData = allData.where((d) {
      if (_timePeriod == 'Today') return isSameDay(d.date, now);
      if (_timePeriod == 'Week') return d.date.isAfter(now.subtract(const Duration(days: 6)));
      if (_timePeriod == 'Month') return d.date.isAfter(now.subtract(const Duration(days: 29)));
      return true;
    }).toList();

    int totalSteps = filteredData.fold(0, (sum, e) => sum + e.steps);
    final progress = filteredData.isEmpty ? 0.0 : totalSteps / (dailyGoal * filteredData.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Step Counter"),
        centerTitle: true,
        actions: [
          if (state.permissionGranted)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showGoalDialog(context, controller, dailyGoal),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : (!state.permissionGranted)
          ? _permissionRequiredView(context, controller)
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Time period selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _timePeriod,
                  items: const [
                    DropdownMenuItem(value: 'Today', child: Text('Today')),
                    DropdownMenuItem(value: 'Week', child: Text('Week')),
                    DropdownMenuItem(value: 'Month', child: Text('Month')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _timePeriod = v);
                  },
                )
              ],
            ),
            const SizedBox(height: 20),

            // Circular progress
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.blue.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 280,
                        width: 280,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            state.isWalking
                                ? Icons.directions_walk
                                : Icons.accessibility_new,
                            color: Colors.white,
                            size: 50,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            totalSteps.toString(),
                            style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          Text(
                            "of ${dailyGoal * filteredData.length} Steps",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: state.status == "walking"
                          ? Colors.green
                          : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      state.status == "walking" ? "Walking" : "Stopped",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _metricCard(
                    icon: Icons.local_fire_department,
                    value: state.calories.toStringAsFixed(1),
                    unit: "cal",
                    color: Colors.orange),
                _metricCard(
                    icon: Icons.straighten,
                    value: state.distanceKm.toStringAsFixed(2),
                    unit: "km",
                    color: Colors.purple),
                _metricCard(
                    icon: Icons.timer,
                    value: (totalSteps * 0.008).toStringAsFixed(0),
                    unit: "min",
                    color: Colors.teal),
              ],
            ),

            const SizedBox(height: 24),

            // Bar Chart for steps
            Container(
              padding: const EdgeInsets.all(16),
              height: 250,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ]),
              child: filteredData.isEmpty
                  ? const Center(child: Text("No data"))
                  : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (dailyGoal * 1.2).toDouble(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (dailyGoal / 2).toDouble(),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt(); // cast to int
                          final date = filteredData[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(DateFormat('d').format(date)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    filteredData.length,
                        (i) => BarChartGroupData(
                      x: i, // must be int
                      barRods: [
                        BarChartRodData(
                          toY: filteredData[i].steps.toDouble(), // must be double
                          color: Colors.blueAccent,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        )
                      ],
                    ),
                  ),
                ),
              )

            ),

            const SizedBox(height: 24),

            // Start/Stop button
            GestureDetector(
              onTap: () {
                if (state.isWalking) {
                  controller.forceStop();
                } else {
                  controller.forceStart();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: state.isWalking ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(
                      state.isWalking ? "STOP" : "START",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    )),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
      {required IconData icon,
        required String value,
        required String unit,
        required Color color}) =>
      Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ]),
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(value,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
      );

  Widget _permissionRequiredView(
      BuildContext context, StepController controller) =>
      Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.directions_walk, size: 100, color: Colors.blue[300]),
          const SizedBox(height: 24),
          const Text("Permission Required",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                  "Please grant Activity Recognition permission to use step tracking.",
                  textAlign: TextAlign.center)),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: () => controller.requestPermissionAgain(),
              child: const Text("Grant Permission")),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => openAppSettings(),
              child: const Text("Open Settings")),
        ]),
      );

  void _showGoalDialog(
      BuildContext context, StepController controller, int currentGoal) {
    final controllerText = TextEditingController(text: currentGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Set daily goal"),
          content: TextFormField(
            controller: controllerText,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Daily step goal"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                final newGoal = int.tryParse(controllerText.text) ?? currentGoal;
                // TODO: save goal in controller
                Navigator.pop(ctx);
              },
              child: const Text("Set"),
            ),
          ],
        );
      },
    );
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
