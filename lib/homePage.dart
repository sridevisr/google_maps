import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps/secrets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  GoogleMapController? mapController;
  Position? _currentPosition;
  String _currentAddress = '';
  LatLng? _center;

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final destinationAddressFocusNode = FocusNode();

  String _startAddress = '';
  String destinationAddress = '';
  String _placeDistance = '';

  Set<Marker> markers = {};

  PolylinePoints? polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  bool? serviceEnabled;
  LocationPermission? permission;


  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required double width,
    required Icon prefixIcon,
    Widget? suffixIcon,
    required Function(String) locationCallback,
  }) {
    return Container(
      width: width * 0.8,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        controller: controller,
        focusNode: focusNode,
        decoration: new InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(
                  Radius.circular(10)
              ),
              borderSide: BorderSide(
                  color: Colors.grey.shade400,
                  width: 2
              )
          ),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(
                  Radius.circular(10)
              ),
              borderSide: BorderSide(
                  color: Colors.blue.shade300,
                  width: 2
              )
          ),
          contentPadding: EdgeInsets.all(15),
          hintText: hint,
        ),
      ),
    );
  }

 /* Future<Position> locateUser() async {
    return Geolocator
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  getUserLocation() async {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled!) {
      return Future.error('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    _currentPosition = await locateUser();
    setState(() {
      _center = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    });
    print('center $_center');
  }*/

  //current location
  _getCurrentLocation() async{
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled!) {
      return Future.error('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
    ).then((Position position) async {
      setState(() {
        print("****");
        _currentPosition = position;
        print('CURRENT POS: $_currentPosition');
        mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
                CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: 18.0
                )
            ));
      });
      await _getAddress();
    }).catchError((e) {
      print(e);
    });
  }

  //get address
  _getAddress() async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude
      );

      Placemark place = p[0];

      setState(() {
        _currentAddress =
        "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  //calculate distance
  Future<bool> _calculateDistance() async {
    try {
      List<Location> startPlacemark = await locationFromAddress(_startAddress);
      List<Location> destinationPlacemark =
      await locationFromAddress(destinationAddress);

      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition!.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition!.longitude
          : startPlacemark[0].longitude;
      double destinationLatitude = destinationPlacemark[0].latitude;
      double destinationLongitude = destinationPlacemark[0].longitude;

      String startCoordinatesString = '($startLatitude, $startLongitude)';
      String destinationCoordinatesString =
          '($destinationLatitude, $destinationLongitude)';

      Marker startMarker = Marker(
        markerId: MarkerId(startCoordinatesString),
        position: LatLng(startLatitude,startLongitude),
        infoWindow: InfoWindow(
            title: 'Start $startCoordinatesString',
            snippet: _startAddress
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      Marker destinationMarker = Marker(
        markerId: MarkerId(destinationCoordinatesString),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow: InfoWindow(
          title: 'Destination $destinationCoordinatesString',
          snippet: destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      markers.add(startMarker);
      markers.add(destinationMarker);
      double miny = (startLatitude <= destinationLatitude)
          ? startLatitude
          : destinationLatitude;
      double minx = (startLongitude <= destinationLongitude)
          ? startLongitude
          : destinationLongitude;
      double maxy = (startLatitude <= destinationLatitude)
          ? destinationLatitude
          : startLatitude;
      double maxx = (startLongitude <= destinationLongitude)
          ? destinationLongitude
          : startLongitude;

      double southWestLatitude = miny;
      double southWestLongitude = minx;

      double northEastLatitude = maxy;
      double northEastLongitude = maxx;

      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(southWestLatitude,southWestLongitude),
            northeast: LatLng(northEastLatitude, northEastLongitude),
          ),
          100.0,
        ),
      );
      await _createPolylines(startLatitude, startLongitude, destinationLatitude,
          destinationLongitude);

      double totalDistance = 0.0;

      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += _coordinateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }

      setState(() {
        _placeDistance = totalDistance.toStringAsFixed(2);
        print('DISTANCE: $_placeDistance km');
      });
      return true;

    } catch (e) {
      print(e);
    }
    return false;
  }

  //calculation as km
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

//polylines
  _createPolylines(
      double startLatitude,
      double startLongitude,
      double destinationLatitude,
      double destinationLongitude,
      ) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints!.getRouteBetweenCoordinates(
      Secrets.API_KEY,
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
      travelMode: TravelMode.transit,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // getUserLocation();
    _getCurrentLocation();
  }



  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return Container(
      height: height,
      width: width,
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialLocation,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              zoomGesturesEnabled: true,
              markers: Set<Marker>.of(markers),
              polylines: Set<Polyline>.of(polylines.values),
              zoomControlsEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
            ),
            SafeArea(
                child:Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipOval(
                        child: Material(
                          color: Colors.blue.shade100,
                          child: InkWell(
                              splashColor: Colors.blue,
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: Icon(Icons.add),
                              ),
                              onTap: () {
                                mapController!.animateCamera(
                                  CameraUpdate.zoomIn(),
                                );
                              }
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      ClipOval(
                        child: Material(
                          color: Colors.blue.shade100,
                          child: InkWell(
                            splashColor: Colors.blue,
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: Icon(Icons.remove),
                            ),
                            onTap: (){
                              mapController!.animateCamera(
                                  CameraUpdate.zoomOut()
                              );
                            },
                          ),
                        ),
                      ),
                      SafeArea(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.white70,
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(20)
                                    )
                                ),
                                width: width * 0.9,
                                child: Padding(
                                    padding: EdgeInsets.only(top: 10,bottom:10),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children:[
                                          Text(
                                            'Places',
                                            style: TextStyle(
                                                fontSize:20
                                            ),
                                          ),
                                          SizedBox(height:10),
                                          _textField(
                                              label: 'Start',
                                              hint:'Choose starting point',
                                              prefixIcon: Icon(Icons.arrow_circle_up),
                                              suffixIcon: IconButton(
                                                icon: Icon(Icons.my_location),
                                                onPressed: (){
                                                  startAddressController.text = _currentAddress;
                                                  _startAddress = _currentAddress;
                                                },
                                              ),
                                              controller: startAddressController,
                                              focusNode: startAddressFocusNode,
                                              width: width,
                                              locationCallback: (String value) {
                                                setState(() {
                                                  _startAddress = value;
                                                });
                                              }
                                          ),
                                          SizedBox(height: 10),
                                          _textField(
                                              controller: destinationAddressController,
                                              focusNode: destinationAddressFocusNode,
                                              label: 'Destination',
                                              hint: 'Choose destination',
                                              width: width,
                                              prefixIcon: Icon(Icons.arrow_circle_down),
                                              locationCallback: (String value) {
                                                setState(() {
                                                  destinationAddress = value;
                                                  print(value);
                                                });
                                              }),
                                          SizedBox(height: 10),
                                          Visibility(
                                              visible: _placeDistance == null? false: true,
                                              child:Text(
                                                'Distance: $_placeDistance km',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold
                                                ),
                                              )
                                          ),
                                          SizedBox(height: 5),
                                          ElevatedButton(
                                            onPressed: (_startAddress!= '' && destinationAddress!= '')?
                                                () async {
                                              startAddressFocusNode.unfocus();
                                              destinationAddressFocusNode.unfocus();
                                              setState(() {
                                                if(markers.isNotEmpty) markers.clear();
                                                if(polylines.isNotEmpty)
                                                  polylines.clear();
                                                if(polylineCoordinates.isNotEmpty)
                                                  polylineCoordinates.clear();
                                                _placeDistance = '';
                                              });
                                              _calculateDistance().then((isCalculated) {
                                                if(isCalculated){

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Distance Calculation Successfully'
                                                        ),
                                                      )
                                                  );
                                                }

                                                else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Error Calculating Distance'),
                                                    ),
                                                  );
                                                }
                                              });
                                            }: null,
                                            child: Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Text(
                                                'Show Route'.toUpperCase(),
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20
                                                ),
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              primary: Colors.red,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20.0),
                                              ),
                                            ),
                                          ),


                                        ]
                                    )
                                ),
                              ),
                            ),
                          )
                      ),
                      SafeArea(
                          child:Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: ClipOval(
                                child: Material(
                                  color: Colors.orange.shade100,
                                  child: InkWell(
                                    splashColor: Colors.orange,
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Icon(Icons.my_location),
                                    ),
                                    onTap: (){

                                       mapController!.animateCamera(
                                                          CameraUpdate.newCameraPosition(
                                                            CameraPosition(
                                                                target: LatLng(
                                                                  _currentPosition!.latitude,
                                                                  _currentPosition!.longitude
                                                                ),
                                                            zoom: 18)
                                                          )
                                       );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          )
                      )

                    ],
                  ),
                )
            )
          ],
        ),
      ),
    );
  }
}
