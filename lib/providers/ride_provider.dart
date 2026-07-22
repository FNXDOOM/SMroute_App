import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ride_option.dart';

enum BookingStage { matching, found, arriving }

class RideProvider extends ChangeNotifier {
  String? _destination;
  RideOption? _selectedOption;
  BookingStage _stage = BookingStage.matching;
  Timer? _t1, _t2;

  String? get destination => _destination;
  RideOption? get selectedOption => _selectedOption;
  BookingStage get stage => _stage;

  void setDestination(String d) {
    _destination = d;
    notifyListeners();
  }

  void selectOption(RideOption r) {
    _selectedOption = r;
    notifyListeners();
  }

  void confirmBooking() {
    _stage = BookingStage.matching;
    notifyListeners();
    _t1 = Timer(const Duration(milliseconds: 1800), () {
      _stage = BookingStage.found;
      notifyListeners();
    });
    _t2 = Timer(const Duration(milliseconds: 3500), () {
      _stage = BookingStage.arriving;
      notifyListeners();
    });
  }

  void reset() {
    _t1?.cancel();
    _t2?.cancel();
    _destination = null;
    _selectedOption = null;
    _stage = BookingStage.matching;
    notifyListeners();
  }

  @override
  void dispose() {
    _t1?.cancel();
    _t2?.cancel();
    super.dispose();
  }
}
