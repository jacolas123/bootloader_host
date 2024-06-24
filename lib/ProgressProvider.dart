import 'package:flutter/material.dart';

class ProgressProvider with ChangeNotifier {
  int _totalToProgress = 0;
  int get totalToProgress => _totalToProgress;

  int _currentProgress = 0;

  double get currentProgress => _currentProgress / _totalToProgress;

  bool _showProgress = false;
  bool get showProgress => _showProgress;

  void setTotalProgress(int total) {
    _totalToProgress = total;
    _currentProgress = 0;
    _showProgress = true;
    notifyListeners();
  }

  void setCurrentProgress(int progress) {
    _currentProgress = progress;
    notifyListeners();
  }

  void hideProgress() {
    _showProgress = false;
    notifyListeners();
  }
}
