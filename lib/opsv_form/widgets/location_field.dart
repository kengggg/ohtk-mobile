part of 'widgets.dart';

class FormLocationField extends StatefulWidget {
  final opsv.LocationField field;

  const FormLocationField(this.field, {Key? key}) : super(key: key);

  @override
  State<FormLocationField> createState() => _FormLocationFieldState();
}

class _FormLocationFieldState extends State<FormLocationField> {
  final Completer<GoogleMapController> _controller = Completer();
  final _logger = locator<Logger>();
  final AppTheme appTheme = locator<AppTheme>();

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (BuildContext context) {
      var latitude = widget.field.latitude;
      var longitude = widget.field.longitude;
      var markers = <Marker>{};

      return ValidationWrapper(
        widget.field,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.field.label != null && widget.field.label != "")
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  widget.field.label!,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            if (latitude == null || longitude == null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(appTheme.borderRadius),
                  color: appTheme.sub4,
                ),
                child: SizedBox(
                  height: 300.w,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_sharp,
                          size: 60,
                          color: Color(0xFFD9D9D9),
                        ),
                        Text(AppLocalizations.of(context)!
                            .fieldUndefinedLocation),
                        FlatButton.primary(
                          onPressed: () async {
                            bool serviceEnabled =
                                await Geolocator.isLocationServiceEnabled();
                            if (serviceEnabled) {
                              LocationPermission permission =
                                  await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied) {
                                _logger.e("permission denied");
                              } else {
                                var position =
                                    await Geolocator.getCurrentPosition(
                                        desiredAccuracy:
                                            LocationAccuracy.medium);
                                widget.field.value =
                                    "${position.longitude},${position.latitude}";
                              }
                            } else {
                              _logger.e("location is disable");
                            }
                          },
                          child: Text(
                            AppLocalizations.of(context)!
                                .fieldUseCurrentLocation,
                            style: TextStyle(
                              fontSize: 15.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (latitude != null && longitude != null)
              SizedBox(
                height: 300,
                width: MediaQuery.of(context).size.width,
                child: Stack(
                  children: [
                    GoogleMap(
                      mapType: MapType.hybrid,
                      initialCameraPosition: CameraPosition(
                          zoom: 12, target: LatLng(latitude, longitude)),
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: true,
                      gestureRecognizers: <
                          Factory<OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                      onCameraMove: (CameraPosition position) {
                        widget.field.value =
                            "${position.target.longitude},${position.target.latitude}";
                      },
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                        Future.delayed(const Duration(seconds: 1), () {
                          controller.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(latitude, longitude),
                                zoom: 17.0,
                              ),
                            ),
                          );
                        });
                      },
                      markers: markers,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Align(
                        alignment: Alignment.center,
                        child: Image.asset(
                          "assets/images/map_pin_icon.png",
                          height: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}
