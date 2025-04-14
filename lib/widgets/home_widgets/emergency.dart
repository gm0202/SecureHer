import 'package:flutter/material.dart';
import 'package:secureher/widgets/home_widgets/emergencies/policeemergency.dart';
import 'package:secureher/widgets/home_widgets/emergencies/AmbulanceEmergency.dart';
import 'package:secureher/widgets/home_widgets/emergencies/FirebrigadeEmergency.dart';
import 'package:secureher/widgets/home_widgets/emergencies/Emergencies.dart';

class EmergencyWidget extends StatelessWidget {
  const EmergencyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 180,
      child: ListView(
        physics: BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        children: [
          PoliceEmergency(),
          AmbulanceEmergency(),
          FirebrigadeEmergency(),
          Emergencies(),
        ],
      ),
    );
  }
}