
// -----------------------------------------------------------------------------
// STATE MODEL
// -----------------------------------------------------------------------------
class StepState {
  final String status;
  final int steps;
  final int todaySteps;
  final bool isWalking;
  final bool isInitialized;
  final bool permissionGranted;
  final bool loading;

  final double calories;
  final double distance;
  final int dailyGoal;

  final List<Map<String, dynamic>> weeklyData;

  StepState({
    required this.status,
    required this.steps,
    required this.todaySteps,
    required this.isWalking,
    required this.isInitialized,
    required this.permissionGranted,
    required this.loading,
    required this.calories,
    required this.distance,
    required this.dailyGoal,
    required this.weeklyData,
  });

  StepState copyWith({
    String? status,
    int? steps,
    int? todaySteps,
    bool? isWalking,
    bool? isInitialized,
    bool? permissionGranted,
    bool? loading,
    double? calories,
    double? distance,
    int? dailyGoal,
    List<Map<String, dynamic>>? weeklyData,
  }) =>
      StepState(
        status: status ?? this.status,
        steps: steps ?? this.steps,
        todaySteps: todaySteps ?? this.todaySteps,
        isWalking: isWalking ?? this.isWalking,
        isInitialized: isInitialized ?? this.isInitialized,
        permissionGranted: permissionGranted ?? this.permissionGranted,
        loading: loading ?? this.loading,
        calories: calories ?? this.calories,
        distance: distance ?? this.distance,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        weeklyData: weeklyData ?? this.weeklyData,
      );

  factory StepState.initial() => StepState(
    status: "Stopped",
    steps: 0,
    todaySteps: 0,
    isWalking: false,
    isInitialized: false,
    permissionGranted: false,
    loading: false,
    calories: 0,
    distance: 0,
    dailyGoal: 1000,
    weeklyData: [],
  );
}