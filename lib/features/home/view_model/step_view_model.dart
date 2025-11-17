import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final stepControllerProvider =
StateNotifierProvider<StepController, StepState>(
      (ref) => StepController(ref),
);

class StepState {
  final String status;
  final bool isWalking;
  final bool permissionGranted;
  final bool isInitialized;
  final bool loading;

  final int todaySteps;
  final double calories;
  final double distanceKm;
  final int dailyGoal;

  final List<DaySteps> weekly;
  final List<DaySteps> monthly;
  final List<DaySteps> allHistory;

  StepState({
    required this.status,
    required this.isWalking,
    required this.permissionGranted,
    required this.isInitialized,
    required this.loading,
    required this.todaySteps,
    required this.calories,
    required this.distanceKm,
    required this.dailyGoal,
    required this.weekly,
    required this.monthly,
    required this.allHistory,
  });

  factory StepState.initial() => StepState(
    status: "Stopped",
    isWalking: false,
    permissionGranted: false,
    isInitialized: false,
    loading: false,
    todaySteps: 0,
    calories: 0.0,
    distanceKm: 0.0,
    dailyGoal: 10000,
    weekly: [],
    monthly: [],
    allHistory: [],
  );

  StepState copyWith({
    String? status,
    bool? isWalking,
    bool? permissionGranted,
    bool? isInitialized,
    bool? loading,
    int? todaySteps,
    double? calories,
    double? distanceKm,
    int? dailyGoal,
    List<DaySteps>? weekly,
    List<DaySteps>? monthly,
    List<DaySteps>? allHistory,
  }) {
    return StepState(
      status: status ?? this.status,
      isWalking: isWalking ?? this.isWalking,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      isInitialized: isInitialized ?? this.isInitialized,
      loading: loading ?? this.loading,
      todaySteps: todaySteps ?? this.todaySteps,
      calories: calories ?? this.calories,
      distanceKm: distanceKm ?? this.distanceKm,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      weekly: weekly ?? this.weekly,
      monthly: monthly ?? this.monthly,
      allHistory: allHistory ?? this.allHistory,
    );
  }
}

class DaySteps {
  final DateTime date;
  final int steps;

  DaySteps({required this.date, required this.steps});
}

class StepController extends StateNotifier<StepState> {
  StepController(this.ref) : super(StepState.initial()) {
    _init();
  }

  final Ref ref;

  StreamSubscription<PedestrianStatus>? _pedestrianSub;
  Timer? _stepTimer;
  Timer? _patternTimer;

  final Random _rnd = Random();
  bool _walking = false;
  int _consecutive = 0;
  double _pace = 1.0;

  // ---------------- INIT ----------------
  Future<void> _init() async {
    await _checkPermission();
  }

  // ---------------- PERMISSION ----------------
  Future<void> _checkPermission() async {
    _setLoading(true);
    final p = await Permission.activityRecognition.request();

    final granted = p == PermissionStatus.granted;
    state = state.copyWith(permissionGranted: granted);

    if (granted) {
      await _initializeApp();
    }
    _setLoading(false);
  }

  Future<void> requestPermissionAgain() => _checkPermission();

  Future<void> _initializeApp() async {
    await _loadToday();
    await _loadHistory();
    await _startPedometer();
    state = state.copyWith(isInitialized: true);
  }

  // ---------------- PEDOMETER ----------------
  Future<void> _startPedometer() async {
    try {
      _pedestrianSub =
          Pedometer.pedestrianStatusStream.listen((PedestrianStatus s) {
            _movementChanged(s.status);
          });
    } catch (_) {}
  }

  void _movementChanged(String status) {
    state = state.copyWith(status: status);

    if (status == "walking" && !_walking) {
      _startWalking();
    } else if (status == "stopped" && _walking) {
      _stopWalking();
    }
  }

  void forceStart() => _movementChanged("walking");
  void forceStop() => _movementChanged("stopped");

  // ---------------- WALK SESSION ----------------
  void _startWalking() {
    _walking = true;
    _consecutive = 0;
    _pace = 0.8 + (_rnd.nextDouble() * 0.3);
    state = state.copyWith(isWalking: true);
    _startStepSimulation();
  }

  void _stopWalking() {
    _walking = false;
    _stepTimer?.cancel();
    _patternTimer?.cancel();
    state = state.copyWith(isWalking: false);
  }

  void _startStepSimulation() {
    _stepTimer?.cancel();
    int ms = (600 / _pace).round();

    _stepTimer = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!_walking) {
        t.cancel();
        return;
      }
      if (_rnd.nextDouble() < _stepProbability()) {
        _addStep();
      }
      if (_consecutive > 0 && _consecutive % 20 == 0) {
        _pace = (_pace * (0.95 + _rnd.nextDouble() * 0.1)).clamp(0.7, 1.3);
        _startStepSimulation();
      }
    });

    _startPatternTimer();
  }

  double _stepProbability() {
    double base = 0.92;
    if (_consecutive < 5) base *= 0.8;
    return (base * (0.95 + _rnd.nextDouble() * 0.1));
  }

  void _startPatternTimer() {
    _patternTimer?.cancel();
    _patternTimer = Timer.periodic(Duration(seconds: 20), (timer) {
      if (!_walking) {
        timer.cancel();
        return;
      }
      if (_rnd.nextDouble() < 0.15) {
        _stepTimer?.cancel();
        Timer(Duration(seconds: 1 + _rnd.nextInt(3)), () {
          if (_walking) _startStepSimulation();
        });
      }
    });
  }

  // ---------------- DATA STORAGE ----------------
  String _todayKey() => DateFormat("yyyy-MM-dd").format(DateTime.now());

  Future<void> _addStep() async {
    _consecutive++;
    int today = state.todaySteps + 1;

    double cal = today * 0.04;
    double dist = (today * 0.762) / 1000;

    state = state.copyWith(
      todaySteps: today,
      calories: cal,
      distanceKm: dist,
    );

    await _saveToday(today);
    await _refreshHistory();
  }

  Future<void> _saveToday(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("steps_${_todayKey()}", steps);
  }

  Future<void> _loadToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = prefs.getInt("steps_${_todayKey()}") ?? 0;

    state = state.copyWith(
      todaySteps: today,
      calories: today * 0.04,
      distanceKm: (today * 0.762) / 1000,
    );
  }

  // ---------------- LOAD HISTORY ----------------
  Future<void> _loadHistory() async {
    await _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final prefs = await SharedPreferences.getInstance();

    List<DaySteps> all = [];
    final keys = prefs.getKeys();

    for (var k in keys) {
      if (k.startsWith("steps_")) {
        final dateStr = k.replaceFirst("steps_", "");
        final steps = prefs.getInt(k) ?? 0;
        all.add(DaySteps(
          date: DateTime.parse(dateStr),
          steps: steps,
        ));
      }
    }

    all.sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();

    List<DaySteps> weekly = all.where((d) {
      return d.date.isAfter(now.subtract(const Duration(days: 7)));
    }).toList();

    List<DaySteps> monthly = all.where((d) {
      return d.date.isAfter(now.subtract(const Duration(days: 30)));
    }).toList();

    state = state.copyWith(
      allHistory: all,
      weekly: weekly,
      monthly: monthly,
    );
  }

  // ---------------- FILTERED DATA ----------------
  List<DaySteps> getStepsForPeriod(String period) {
    DateTime now = DateTime.now();

    if (period == 'Today') {
      return state.allHistory
          .where((d) => isSameDay(d.date, now))
          .toList();
    } else if (period == 'Week') {
      return state.allHistory
          .where((d) => d.date.isAfter(now.subtract(const Duration(days: 6))))
          .toList();
    } else if (period == 'Month') {
      return state.allHistory
          .where((d) => d.date.isAfter(now.subtract(const Duration(days: 29))))
          .toList();
    }
    return [];
  }

  // ---------------- DAILY GOAL ----------------
  void setDailyGoal(int goal) {
    state = state.copyWith(dailyGoal: goal);
  }

  // ---------------- HELPERS ----------------
  void _setLoading(bool v) => state = state.copyWith(loading: v);

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _pedestrianSub?.cancel();
    _stepTimer?.cancel();
    _patternTimer?.cancel();
    super.dispose();
  }
}
