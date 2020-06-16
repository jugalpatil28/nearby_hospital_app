import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'data/place_response.dart';
import 'data/hospital.dart';
import 'models/global.dart';

//import 'models/Hospital.dart';
import 'data/error.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _API_KEY = "AIzaSyCXy7xhU-N1cvz4tmnpfISikb5Bcfgm33w";
  static const String baseUrl =
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json";

  LocationData currentLocation;
  Location location;
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;
  CameraPosition _center =
      CameraPosition(target: LatLng(45.521563, -122.677433), zoom: 11);
  bool isLoading = false;

  Error error;
  List<Hospital> hospitals;
  bool isSearching = true;

  Completer<GoogleMapController> _controller = Completer();

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  @override
  void initState() {
    super.initState();
    location = Location();

    _getLocation();
  }

  _getLocation() async {
    setState(() {
      isLoading = true;
    });
    initialize();
    currentLocation = await location.getLocation();
    if (currentLocation == null) {
      return;
    }
    _center = CameraPosition(
        target: LatLng(currentLocation.latitude, currentLocation.longitude),
        zoom: 11);
    setState(() {
      isLoading = false;
    });

    searchNearby(currentLocation.latitude, currentLocation.longitude);
  }

  Future<void> initialize() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          body: isLoading
              ? Center(child: CircularProgressIndicator())
              : Stack(
                  children: <Widget>[
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: _center,
                      myLocationButtonEnabled: false,
                    ),
                    Container(
                      padding: EdgeInsets.only(top: 400, bottom: 50),
                      child: isSearching
                          ? ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                return Container(
                                  padding: EdgeInsets.all(10),
                                  margin: EdgeInsets.only(right: 20),
                                  width: 180,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(20)),
                                    color: Colors.white,
                                    boxShadow: [
                                      new BoxShadow(
                                        color: Colors.transparent,
                                        blurRadius: 20.0,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            )
                          : ListView(
                              padding: EdgeInsets.only(left: 20),
                              children: getHospitalsInArea(),
                              scrollDirection: Axis.horizontal,
                            ),
                    ),
                  ],
                )),
    );
  }

  void searchNearby(double latitude, double longitude) async {
    String url =
        '$baseUrl?key=$_API_KEY&location=$latitude,$longitude&radius=10000&keyword=hospital';
    print(url);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _handleResponse(data);
    } else {
      throw Exception('An error occurred getting places nearby');
    }

    setState(() {
      isSearching = false;
    });
  }

  void _handleResponse(data) {
    if (data['status'] == "REQUEST_DENIED") {
      setState(() {
        error = Error.fromJson(data);
      });
      // success
    } else if (data['status'] == "OK") {
      setState(() {
        hospitals = PlaceResponse.parseResults(data['results']);
      });
    } else {
      print(data);
    }
  }

  List<Widget> getHospitalsInArea() {
    List<Widget> cards = [];
    for (Hospital hospital in hospitals) {
      if(hospital.rating != 0.0)
        cards.add(hospitalCard(hospital));
    }
    return cards;
  }
}

Map statusStyles = {
  'Available': statusAvailableStyle,
  'Unavailable': statusUnavailableStyle
};

Widget hospitalCard(Hospital hospital) {
  return Container(
    padding: EdgeInsets.all(10),
    margin: EdgeInsets.only(right: 20),
    width: 250,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      color: Colors.white,
      boxShadow: [
        new BoxShadow(
          color: Colors.transparent,
          blurRadius: 20.0,
        ),
      ],
    ),
    child: Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Container(
              child: CircleAvatar(
                child: FadeInImage.assetNetwork(
                  placeholder: "assets/profile.png",
                  image: hospital.icon,
                ),
              ),
            ),
            SizedBox(
              width: 10,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  child: Container(
                    width: 150,
                    child: Text(
                      hospital.name,
                      style: techCardTitleStyle,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      maxLines: 2,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
//        Container(
//          margin: EdgeInsets.only(top: 30),
//          child: Row(
//            children: <Widget>[
//              Text(
//                "Status:  ",
//                style: techCardSubTitleStyle,
//              ),
//              Text(hospital.status, style: statusStyles[hospital.status])
//            ],
//          ),
//        ),
        Container(
          margin: EdgeInsets.only(top: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    "Rating: " + hospital.rating.toString(),
                    style: techCardSubTitleStyle,
                  )
                ],
              ),
              Row(children: getRatings(hospital))
            ],
          ),
        ),
      ],
    ),

  );
}

List<Widget> getRatings(Hospital hospital) {
  List<Widget> ratings = [];
  for (int i = 0; i < 5; i++) {
    if (i < hospital.rating.floor()) {
      ratings.add(new Icon(Icons.star, color: Colors.yellow));
    } else {
      ratings.add(new Icon(Icons.star_border, color: Colors.black));
    }
  }
  return ratings;
}
