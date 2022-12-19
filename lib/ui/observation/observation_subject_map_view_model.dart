import 'dart:ffi';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:podd_app/locator.dart';
import 'package:podd_app/models/entities/observation_subject.dart';
import 'package:podd_app/services/observation_service.dart';
import 'package:stacked/stacked.dart';

class ObservationSubjectMapViewModel extends BaseViewModel {
  IObservationService observationService = locator<IObservationService>();

  int definitionId;
  Position? currentPosition;

  GoogleMapController? controller;

  final ReactiveList<ObservationSubject> _subjects =
      ReactiveList<ObservationSubject>();

  ObservationSubjectMapViewModel(this.definitionId) {
    setBusy(true);
    _getCurrentLocation();
  }

  List<ObservationSubject> get subjects => _subjects;

  fetch(double topLeftX, double topLeftY, double bottomRightX,
      double bottomRightY) async {
    _subjects.clear();
    _subjects.addAll(
        await observationService.fetchAllObservationSubjectsInBounded(
            definitionId, topLeftX, topLeftY, bottomRightX, bottomRightY));
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setBusy(false);
  }
}
