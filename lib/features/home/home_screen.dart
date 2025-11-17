import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription <PedestrianStatus>? _pedestrianSubscriptionStream;
  Timer? _stepTimer;
  Timer? _sessionTimer;
  String _status = "Stopped";
  int _steps = 0;
  int _todaySteps = 0;
  bool _isWalking = false;
  bool _isIntialized = false;
  bool _isPermissionGranted = false;
  bool _isLoading = false;

  Random _random = Random();
  DateTime? _isWalkingStartTime;
  int _currentWalkingSession = 0;
  double _walkingPace = 1.0;
  int _conswcutiveSteps = 0;

  double _calories = 0;
  double _distance = 0;
  int _dailyGoal = 1000;

  List<Map<String,dynamic>> _weeklyData = [];

  @override
  void initState() {
    // TODO: implement initState

    _checkPermission();
    super.initState();
  }
  @override
  void dispose() {
    // TODO: implement dispose
    _pedestrianSubscriptionStream?.cancel();
    _stepTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermission()async {
    setState(() {
      _isLoading = true;

    });
    final status = await Permission.activityRecognition.request();
    setState(() {
      _isPermissionGranted = status == PermissionStatus.granted;
    });

    if(_isPermissionGranted){
      await _initializedApp();
    }
    setState(() {
      _isLoading = false;
    });

  }

  Future<void> _initializedApp() async {

    await _loadDailyData();
    await _loadTodaySteps();
    await _setupMovementDetection();
    setState(() {
      _isIntialized = true;
    });

  }

  Future<void> _setupMovementDetection()async{
    try{
      _pedestrianSubscriptionStream = Pedometer.pedestrianStatusStream.listen(
          (PedestrianStatus event){
            _handleMovementChange(event.status);
          },
          onError: (error){
            if (kDebugMode) {
              print("Error in Pedestrial status stream: $error");
            }


      }
      );

    }catch(e){
    if (kDebugMode) {
    print("Error in movement setting up: $e");
    }

    }
  }

  void _handleMovementChange(String status){
    setState(() {
      _status = status;
    });

    if(status == "walking" && !_isWalking){
      _startWalkingSession();

    }else if( status == "stopped" && _isWalking){
      _stopWalkingSession();
    }

  }
  void _startWalkingSession(){
    _isWalking = true;
    _isWalkingStartTime = DateTime.now();
    _currentWalkingSession++;
    _walkingPace = 0.85 + (_random.nextDouble()*0.3);
    _conswcutiveSteps = 0;
    _startStepCounting();
  }

  void _stopWalkingSession(){
    _isWalking = false;
    _isWalkingStartTime = null;
    _stepTimer?.cancel();
    _sessionTimer?.cancel();
    _stepTimer = null;
    _sessionTimer = null;

    // _stopStepCounting();
    // _saveWalkingSession();

  }
  void _startStepCounting(){
    _stepTimer?.cancel();
    int baseInterval = (600/_walkingPace).round();
    _stepTimer = Timer.periodic(Duration(milliseconds: baseInterval), (timer){
      if(!_isWalking){
        timer.cancel();
        return;
      }

      double stepChance = _calculateStepProbability();
      if(_random.nextDouble() < stepChance){
        setState(() {
          _steps++;
          _conswcutiveSteps++;
          _calculateMetrics();
        });
        _saveSteps;

      }

      if(_conswcutiveSteps > 0 && _conswcutiveSteps % 20 == 0){
        double adjustment = 0.95 + (_random.nextDouble() * 0.1);
        _walkingPace = (_walkingPace * adjustment).clamp(0.7, 1.3);
        _startStepCounting();
      }

    });

    _startSessionPatterns();
  }

  double _calculateStepProbability(){
    double baseProbability = 0.92;
    if(_conswcutiveSteps <5){
      baseProbability *= 0.8;
    }
    double randomVariation = 0.95 + (_random.nextDouble()*0.1);

    return (baseProbability * randomVariation).clamp(0.0, 1.0);
  }

  void _startSessionPatterns(){
    _stepTimer = Timer.periodic( Duration(seconds: 15 + _random.nextInt(30))  ,
        (timer){

      if(!_isWalking){
        timer.cancel();
        return;
      }

      if(_random.nextDouble() < 0.2){
        _stepTimer?.cancel();
        Timer(Duration(seconds: 1+ _random.nextInt(3)), (){
          if(_isWalking){
            _startStepCounting();
          }

        });
      }

        }
    );

  }


  // Calculate matrics like calories and distance

  void _calculateMetrics(){
    _calories = _steps * 0.04;
    _distance = (_steps * 0.762)/100;
  }

  String _getDateKey(){
    return  DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void>_loadTodaySteps()async{
    final prefs = await SharedPreferences.getInstance();
    final today = _getDateKey();
    final lastDate = prefs.getString("last-date")??"";

    if(lastDate == today){
      setState(() {
        _todaySteps = prefs.getInt("steps_$today")??0;
        _steps = _todaySteps;
      });
    }else{
      setState(() {
        _todaySteps = 0;
        _steps = 0;
      });
      await prefs.setString("last-date", today);
      await prefs.setInt("steps_$today", 0);
    }

    _calculateMetrics();
  }

  Future<void> _saveSteps()async{
    final prefs = await SharedPreferences.getInstance();
    final today = _getDateKey();
    await prefs.setString("last-date", today);
    await prefs.setInt("steps_$today", _steps);

  }

  Future<void>_loadDailyData()async{
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyGoal = prefs.getInt("dailyGoal")??1000;
    });
    _loadWeeklyData();

  }

  Future<void>_loadWeeklyData()async{
    final prefs = await SharedPreferences.getInstance();

    List<Map<String,dynamic>> weekData = [];

    for(int i = 6; i>= 0; i--){
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final steps = prefs.getInt("steps_$dateStr")??0;

      weekData.add(
        {
          "date":date,
          "steps":steps,
          "day": DateFormat("E").format(date),
        }
      );


    }
    setState(() {
      _weeklyData = weekData;
    });


  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(

    );
  }
}
