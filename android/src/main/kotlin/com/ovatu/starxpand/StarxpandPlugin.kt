package com.ovatu.starxpand

import android.app.Activity
import android.util.Log
import androidx.annotation.NonNull
import com.starmicronics.stario10.*
import com.starmicronics.stario10.starxpandcommand.DocumentBuilder
import com.starmicronics.stario10.starxpandcommand.DrawerBuilder
import com.starmicronics.stario10.starxpandcommand.StarXpandCommandBuilder
import com.starmicronics.stario10.starxpandcommand.drawer.OpenParameter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** StarxpandPlugin */
class StarxpandPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private val tag = "StarXpandPlugin"

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var activity: Activity

  var _manager: StarDeviceDiscoveryManager? = null
  var _result: Result? = null

  var _foundPrinters: MutableList<StarPrinter> = mutableListOf()

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "starxpand")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    Log.d(tag, "onAttachedToActivity")
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    Log.d(tag, "onDetachedFromActivityForConfigChanges")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    Log.d(tag, "onReattachedToActivityForConfigChanges")
  }

  override fun onDetachedFromActivity() {
    Log.d(tag, "onDetachedFromActivity")
  }


  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    _result = result

    when (call.method) {
      "find" -> find()
      "openDrawer" -> openDrawer(call.arguments as Map<*, *>)
      else -> result.notImplemented()
    }
  }

  fun find() {
    try {
      _foundPrinters.clear()

      // Specify your printer interface types.
      val interfaceTypes: List<InterfaceType> = listOf(
              InterfaceType.Lan,
              InterfaceType.Bluetooth,
              InterfaceType.Usb
      )

      _manager = StarDeviceDiscoveryManagerFactory.create(
              interfaceTypes,
              activity
      )

      // Set discovery time. (option)
      _manager?.discoveryTime = 10000

      _manager?.callback = object : StarDeviceDiscoveryManager.Callback {
        // Callback for printer found.
        override fun onPrinterFound(printer: StarPrinter) {
          Log.d("Discovery", "Found printer: ${printer.connectionSettings.identifier}.")
          _foundPrinters.add(printer);
        }

        // Callback for discovery finished. (option)
        override fun onDiscoveryFinished() {
          Log.d("Discovery", "Discovery finished.")

          _result!!.success(mutableMapOf(
                  "printers" to _foundPrinters.map {
                    mutableMapOf(
                            "model" to it.information?.model.toString(),
                            "identifier" to it.connectionSettings.identifier,
                            "interface" to it.connectionSettings.interfaceType.value()
                    )
                  }
          ))
        }
      }

      // Start discovery.
      _manager?.startDiscovery()

      // Stop discovery.
      //_manager?.stopDiscovery()
    } catch (exception: Exception) {
      // Exception.
      Log.d("Discovery", "${exception.message}")
    }
  }

  fun openDrawer(@NonNull args: Map<*, *>) {
    Log.d("Discovery", "openDrawer. ${args["printer"]}")

    val printer = buildPrinter(args["printer"] as Map<*, *>)
    Log.d("Discovery", "openDrawer. ${printer.connectionSettings.identifier}")
    Log.d("Discovery", "openDrawer. ${printer.connectionSettings.interfaceType}")


    val job = SupervisorJob()
    val scope = CoroutineScope(Dispatchers.Default + job)
    scope.launch {
      try {
        // Connect to the printer.
        printer.openAsync().await()

        val builder = StarXpandCommandBuilder()
        builder.addDocument(
                DocumentBuilder().addDrawer(DrawerBuilder().actionOpen(OpenParameter()))
        )

        // Get printing data from StarXpandCommandBuilder object.
        val commands = builder.getCommands()

        // Print.
        printer.printAsync(commands).await()
      } catch (e: Exception) {
        // Exception.
        Log.d("Printing", "${e.message}")
      } finally {
        // Disconnect from the printer.
        printer.closeAsync().await()
      }
    }

  }

  fun buildPrinter(printer: Map<*, *>): StarPrinter {
    val connection = StarConnectionSettings(InterfaceTypeFromValue(printer["interface"] as String)!!, printer["identifier"] as String);

    return StarPrinter(connection, activity)
  }
}

fun InterfaceType.value() : String {
  return when (this) {
    InterfaceType.Lan -> "lan"
    InterfaceType.Bluetooth -> "bluetooth"
    InterfaceType.Usb -> "urb"
    else -> "unknown"
  }
}

fun InterfaceTypeFromValue(value: String) : InterfaceType? {
  return when (value) {
    "lan" -> InterfaceType.Lan
    "bluetooth" -> InterfaceType.Bluetooth
    "urb" -> InterfaceType.Usb
    else -> null
  }
}
