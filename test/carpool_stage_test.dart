// Carpool lifecycle: the passenger stage model and its fallback derivation,
// plus the ride payload's `carpool_status` field.

import 'package:flutter_test/flutter_test.dart';

import 'package:finalyr_app/models/carpool_stage.dart';
import 'package:finalyr_app/models/ride_request_record.dart';
import 'package:finalyr_app/models/shared_route.dart';

SharedRoute _route({bool driverAccepted = false}) => SharedRoute(
      routeId: 'route-1-abcd',
      vehicleId: 1,
      provider: 'stadia',
      problem: 'pdp',
      geometry: const [],
      legs: const [],
      stops: const [],
      myLegIndices: const [],
      driverAccepted: driverAccepted,
    );

void main() {
  group('CarpoolStage.fromWire', () {
    test('maps every backend stage string', () {
      expect(CarpoolStage.fromWire('pending'), CarpoolStage.pending);
      expect(CarpoolStage.fromWire('searching'), CarpoolStage.searching);
      expect(CarpoolStage.fromWire('clustered'), CarpoolStage.clustered);
      expect(CarpoolStage.fromWire('assigned'), CarpoolStage.assigned);
      expect(
        CarpoolStage.fromWire('driver_accepted'),
        CarpoolStage.driverAccepted,
      );
      expect(
        CarpoolStage.fromWire('driver_arriving'),
        CarpoolStage.driverArriving,
      );
      expect(CarpoolStage.fromWire('pickup_ready'), CarpoolStage.pickupReady);
      expect(
        CarpoolStage.fromWire('passenger_confirmed_pickup_stop'),
        CarpoolStage.passengerConfirmed,
      );
      expect(CarpoolStage.fromWire('boarded'), CarpoolStage.boarded);
      expect(CarpoolStage.fromWire('in_transit'), CarpoolStage.inTransit);
      expect(CarpoolStage.fromWire('dropped_off'), CarpoolStage.droppedOff);
      expect(CarpoolStage.fromWire('completed'), CarpoolStage.completed);
      expect(CarpoolStage.fromWire('cancelled'), CarpoolStage.cancelled);
    });

    test('is case/space tolerant, null-safe and rejects unknown values', () {
      expect(
        CarpoolStage.fromWire(' Driver_Accepted '),
        CarpoolStage.driverAccepted,
      );
      expect(CarpoolStage.fromWire(null), isNull);
      expect(CarpoolStage.fromWire('  '), isNull);
      expect(CarpoolStage.fromWire('nonsense'), isNull);
    });
  });

  group('CarpoolStage.fromRide fallback', () {
    test('prefers the authoritative fine stage', () {
      expect(
        CarpoolStage.fromRide(status: 'assigned', carpoolStatus: 'boarded'),
        CarpoolStage.boarded,
      );
    });

    test('reconstructs from the coarse status when carpool_status is absent',
        () {
      expect(CarpoolStage.fromRide(status: 'pending'), CarpoolStage.pending);
      expect(
        CarpoolStage.fromRide(status: 'clustered'),
        CarpoolStage.clustered,
      );
      expect(CarpoolStage.fromRide(status: 'assigned'), CarpoolStage.assigned);
      expect(
        CarpoolStage.fromRide(status: 'arriving'),
        CarpoolStage.driverArriving,
      );
      expect(
        CarpoolStage.fromRide(status: 'ready_for_pickup'),
        CarpoolStage.passengerConfirmed,
      );
      expect(
        CarpoolStage.fromRide(status: 'in_progress'),
        CarpoolStage.inTransit,
      );
      expect(
        CarpoolStage.fromRide(status: 'completed'),
        CarpoolStage.droppedOff,
      );
      expect(
        CarpoolStage.fromRide(status: 'cancelled'),
        CarpoolStage.cancelled,
      );
    });

    test('reads driver acceptance off the pooled route for a legacy ride', () {
      expect(
        CarpoolStage.fromRide(
          status: 'assigned',
          route: _route(driverAccepted: true),
        ),
        CarpoolStage.driverAccepted,
      );
      expect(
        CarpoolStage.fromRide(
          status: 'assigned',
          route: _route(driverAccepted: false),
        ),
        CarpoolStage.assigned,
      );
    });
  });

  group('CarpoolStage capabilities', () {
    test('canConfirmPickupStop is only the arriving / ready window', () {
      expect(CarpoolStage.driverArriving.canConfirmPickupStop, isTrue);
      expect(CarpoolStage.pickupReady.canConfirmPickupStop, isTrue);
      expect(CarpoolStage.assigned.canConfirmPickupStop, isFalse);
      expect(CarpoolStage.boarded.canConfirmPickupStop, isFalse);
      expect(CarpoolStage.inTransit.canConfirmPickupStop, isFalse);
    });

    test('cancellable before boarding, terminal only at the end', () {
      expect(CarpoolStage.pending.isCancellable, isTrue);
      expect(CarpoolStage.driverAccepted.isCancellable, isTrue);
      expect(CarpoolStage.passengerConfirmed.isCancellable, isTrue);
      expect(CarpoolStage.boarded.isCancellable, isFalse);
      expect(CarpoolStage.inTransit.isCancellable, isFalse);
      expect(CarpoolStage.droppedOff.isCancellable, isFalse);
      expect(CarpoolStage.completed.isTerminal, isTrue);
      expect(CarpoolStage.cancelled.isTerminal, isTrue);
      expect(CarpoolStage.boarded.isTerminal, isFalse);
    });
  });

  test('RideRequestRecord parses carpool_status', () {
    final record = RideRequestRecord.fromJson({
      'id': 42,
      'pickup_lat': 12.9719,
      'pickup_lng': 77.6412,
      'dest_lat': 12.9756,
      'dest_lng': 77.6066,
      'status': 'in_progress',
      'is_shared': true,
      'carpool_status': 'boarded',
    });
    expect(record.carpoolStatus, 'boarded');

    final private = RideRequestRecord.fromJson({
      'id': 43,
      'pickup_lat': 12.9719,
      'pickup_lng': 77.6412,
      'dest_lat': 12.9756,
      'dest_lng': 77.6066,
      'status': 'assigned',
      'is_shared': false,
    });
    expect(private.carpoolStatus, isNull);
  });
}
