import 'package:flutter/material.dart';

class BusStationCard extends StatelessWidget {
  final Function? onMapFunction;

  const BusStationCard({super.key, this.onMapFunction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              onMapFunction!('bus stops near me');
            },
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                height: 50,
                width: 50,
                child: Center(
                  child: Image.asset('assets/bus-stop.png', height: 32),
                ),
              ),
            ),
          ),
          Text('Bus Stations'),
        ],
      ),
    );
  }
}
