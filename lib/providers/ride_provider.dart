import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ride_option.dart';
import '../models/ride_request_record.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';

enum BookingStage { matching, found, arriving }

class RideProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  String? _destination;
  RideOption? _selectedOption;
  BookingStage _stage = BookingStage.matching;
  bool _isBooking = false;
  bool _isLoadingRides = false;
  String? _error;
  final List<RideRequestRecord> _myRides = [];

  String? get destination => _destination;
  RideOption? get selectedOption => _selectedOption;
  BookingStage get stage => _stage;
  bool get isBooking => _isBooking;
  bool get isLoadingRides => _isLoadingRides;
  String? get error => _error;
  List<RideRequestRecord> get myRides => List.unmodifiable(_myRides);

  void setDestination(String d) {
    _destination = d;
    _error = null;
    notifyListeners();
  }

  void selectOption(RideOption r) {
    _selectedOption = r;
    _error = null;
    notifyListeners();
  }

  String _messageForException(Object error) {
    if (error is ApiException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  void handleRideStatusUpdate(String newStatus) {
    switch (newStatus) {
      case 'assigned':
        _stage = BookingStage.found;
        break;
      case 'arriving':
        _stage = BookingStage.arriving;
        break;
      case 'in_progress':
      case 'completed':
      case 'cancelled':
        // For simplicity, we just stay on the arriving screen 
        // until the user presses "Done", or we could trigger a reset.
        break;
    }
    notifyListeners();
  }

  Future<bool> confirmBooking() async {
    if (_destination == null || _destination!.trim().isEmpty) {
      _error = 'Please choose a destination first.';
      notifyListeners();
      return false;
    }
    if (_selectedOption == null) {
      _error = 'Please select a ride option first.';
      notifyListeners();
      return false;
    }

    _isBooking = true;
    _error = null;
    _stage = BookingStage.matching;
    notifyListeners();

    try {
      final pickup = LocationService.defaultPickup;
      final destinationPoint = LocationService.geocode(_destination!);
      await _api.postJson(
        '/rides/request',
        body: {
          'pickup_lat': pickup.lat,
          'pickup_lng': pickup.lng,
          'dest_lat': destinationPoint.lat,
          'dest_lng': destinationPoint.lng,
          'ride_option_id': _selectedOption!.id,
          'ride_option_name': _selectedOption!.name,
          'ride_option_price': _selectedOption!.priceRange,
          'pickup_label': 'Current location',
          'destination_label': _destination,
        },
      );
      await loadMyRides(silent: true);
      return true;
    } catch (error) {
      _error = _messageForException(error);
      notifyListeners();
      return false;
    } finally {
      _isBooking = false;
      notifyListeners();
    }
  }

  Future<void> loadMyRides({bool silent = false}) async {
    if (!silent) {
      _isLoadingRides = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await _api.getJson('/rides/my-rides');
      final items = (response as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RideRequestRecord.fromJson)
          .toList(growable: false);
      _myRides
        ..clear()
        ..addAll(items);
    } catch (error) {
      if (!silent) {
        _error = _messageForException(error);
      }
    } finally {
      if (!silent) {
        _isLoadingRides = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    _destination = null;
    _selectedOption = null;
    _stage = BookingStage.matching;
    _error = null;
    notifyListeners();
  }
}
