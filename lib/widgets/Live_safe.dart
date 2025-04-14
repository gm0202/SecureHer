import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:toastification/toastification.dart';
import 'package:secureher/widgets/live_safe/BusStation.dart';
import 'package:secureher/widgets/live_safe/Hospital.dart';
import 'package:secureher/widgets/live_safe/Pharmacy.dart';
import 'package:secureher/widgets/live_safe/PoliceStation.dart';

class LiveSafe extends StatelessWidget {
  const LiveSafe({Key? key}) : super(key: key);

  static Future<void> openMap(BuildContext context, String location) async {
    String googleUrl = 'https://www.google.com/maps/search/$location';
    try {
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl));
      } else {
        toastification.show(
          context: context,
          title: const Text('Could not open the map'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        title: const Text('Something went wrong while opening the map'),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: MediaQuery.of(context).size.width,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 8),
          PoliceStationCard(onMapFunction: (location) => openMap(context, location)),
          const SizedBox(width: 8),
          HospitalCard(onMapFunction: (location) => openMap(context, location)),
          const SizedBox(width: 8),
          PharmacyCard(onMapFunction: (location) => openMap(context, location)),
          const SizedBox(width: 8),
          BusStationCard(onMapFunction: (location) => openMap(context, location)),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}