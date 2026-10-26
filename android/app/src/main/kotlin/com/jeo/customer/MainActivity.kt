package com.jeo.customer

import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {

    // Below Android 13 the geocoding plugin calls the blocking
    // Geocoder.getFromLocation / getFromLocationName on the main thread. Those
    // are network calls, so a slow connection held the UI thread for seconds
    // and Play reported it as "Input dispatching timed out" (ANR). This channel
    // runs the very same Geocoder calls on a background thread and returns the
    // same maps and error codes the plugin does. From Android 13 it answers
    // null and lib/utils/safe_geocoding.dart uses the plugin, which is already
    // asynchronous there.
    private val geocoderThread = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jeo.customer/geocoder")
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "placemarkFromCoordinates" -> {
                        val latitude = call.argument<Double>("latitude") ?: 0.0
                        val longitude = call.argument<Double>("longitude") ?: 0.0
                        geocoderThread.execute {
                            try {
                                @Suppress("DEPRECATION")
                                val addresses = Geocoder(applicationContext).getFromLocation(latitude, longitude, 5)
                                if (addresses != null && addresses.isNotEmpty()) {
                                    val maps = addresses.map { toPlacemarkMap(it) }
                                    mainHandler.post { result.success(maps) }
                                } else {
                                    val message = String.format(
                                        Locale.ENGLISH,
                                        "No address information found for supplied coordinates (latitude: %f, longitude: %f).",
                                        latitude,
                                        longitude,
                                    )
                                    mainHandler.post { result.error("NOT_FOUND", message, null) }
                                }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("IO_ERROR", e.message ?: "Unknown error occurred", null) }
                            }
                        }
                    }
                    "locationFromAddress" -> {
                        val address = call.argument<String>("address") ?: ""
                        geocoderThread.execute {
                            try {
                                @Suppress("DEPRECATION")
                                val addresses = Geocoder(applicationContext).getFromLocationName(address, 5)
                                if (addresses != null && addresses.isNotEmpty()) {
                                    val maps = addresses.map { toLocationMap(it) }
                                    mainHandler.post { result.success(maps) }
                                } else {
                                    mainHandler.post { result.error("NOT_FOUND", "No coordinates found for '$address'", null) }
                                }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("IO_ERROR", e.message ?: "Unknown error occurred", null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Same fields as the plugin's AddressMapper.
    private fun toPlacemarkMap(address: Address): Map<String, Any?> {
        val line = address.getAddressLine(0)
        val street = if (line.isNullOrEmpty()) null else line.split(",").firstOrNull { it.isNotEmpty() }
        return mapOf(
            "name" to address.featureName,
            "street" to street,
            "isoCountryCode" to address.countryCode,
            "country" to address.countryName,
            "thoroughfare" to address.thoroughfare,
            "subThoroughfare" to address.subThoroughfare,
            "postalCode" to address.postalCode,
            "administrativeArea" to address.adminArea,
            "subAdministrativeArea" to address.subAdminArea,
            "locality" to address.locality,
            "subLocality" to address.subLocality,
        )
    }

    private fun toLocationMap(address: Address): Map<String, Any?> = mapOf(
        "latitude" to address.latitude,
        "longitude" to address.longitude,
        "timestamp" to Calendar.getInstance(TimeZone.getTimeZone("UTC")).timeInMillis,
    )
}
