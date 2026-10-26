import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as plugin;

export 'package:geocoding/geocoding.dart' hide placemarkFromCoordinates, locationFromAddress;

/// Drop-in replacements for the geocoding package's two lookups.
///
/// Below Android 13 the plugin runs Android's blocking Geocoder on the main
/// thread, and a slow network turned every address lookup into a frozen
/// screen (Play ANR "Input dispatching timed out"). On those versions the same
/// Geocoder call goes through MainActivity's channel on a background thread,
/// with the same results and the same errors (a coordinates miss is a
/// PlatformException 'NOT_FOUND', an address miss a NoResultFoundException,
/// as the plugin does). Everywhere else - Android 13+,
/// where MainActivity answers null, and iOS - the plugin runs exactly as before.
const MethodChannel _channel = MethodChannel('com.jeo.customer/geocoder');

Future<List<plugin.Placemark>> placemarkFromCoordinates(double latitude, double longitude) async {
  if (Platform.isAndroid) {
    try {
      final dynamic maps = await _channel.invokeMethod('placemarkFromCoordinates', <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      });
      if (maps != null) return plugin.Placemark.fromMaps(maps);
    } on MissingPluginException {
      // No channel (tests, or an engine without MainActivity): use the plugin.
    }
  }
  return plugin.placemarkFromCoordinates(latitude, longitude);
}

Future<List<plugin.Location>> locationFromAddress(String address) async {
  if (Platform.isAndroid) {
    try {
      final dynamic maps = await _channel.invokeMethod('locationFromAddress', <String, dynamic>{'address': address});
      if (maps != null) return plugin.Location.fromMaps(maps);
    } on MissingPluginException {
      // No channel (tests, or an engine without MainActivity): use the plugin.
    } on PlatformException catch (e) {
      if (e.code == 'NOT_FOUND') throw const plugin.NoResultFoundException();
      rethrow;
    }
  }
  return plugin.locationFromAddress(address);
}
