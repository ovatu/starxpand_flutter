package com.ovatu.starxpand

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat.requestPermissions
import androidx.core.content.ContextCompat.checkSelfPermission
import com.starmicronics.stario10.*
import com.starmicronics.stario10.starxpandcommand.*
import com.starmicronics.stario10.starxpandcommand.drawer.Channel
import com.starmicronics.stario10.starxpandcommand.drawer.OpenParameter
import com.starmicronics.stario10.starxpandcommand.printer.*

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** StarxpandPlugin */
class StarxpandPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private val tag = "StarxpandPlugin"

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var activity: Activity

  private var _manager: StarDeviceDiscoveryManager? = null
  private var _printers: MutableMap<String, StarPrinter> = mutableMapOf()
  private var _permissionCallback: ((requestCode: Int, permissions: Array<String>, grantResults: IntArray)->Unit)? = null

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
    binding.addRequestPermissionsResultListener { requestCode, permissions, grantResults -> callPermissionCallbacks(requestCode, permissions, grantResults) }
  }

  private fun callPermissionCallbacks(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
    Log.d(tag, "callPermissionCallbacks")
    _permissionCallback?.invoke(requestCode, permissions, grantResults)

    return true
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
    Log.d(tag, "onMethodCall: ${call.method} - ${call.arguments}")

    when (call.method) {
      "findPrinters" -> findPrinters(call.arguments as Map<*, *>, result)
      "printDocument" -> printDocument(call.arguments as Map<*, *>, result)
      "startInputListener" -> startInputListener(call.arguments as Map<*, *>, result)
      "stopInputListener" -> stopInputListener(call.arguments as Map<*, *>, result)
      else -> result.notImplemented()
    }
  }

  private fun getPrinter(map: Map<*, *>): StarPrinter {
    val connection = StarConnectionSettings(interfaceTypeFromValue(map["interface"] as String)!!, map["identifier"] as String)

    if (!_printers.containsKey(connection.toString())) {
      val printer = StarPrinter(connection, activity)
      _printers[connection.toString()] = printer
    }

    return _printers[connection.toString()]!!
  }

  private fun sendCallback(guid: String, type: String, payload: Map<*, *>) {
    Log.d(tag, "sendCallback: $guid - $payload")

    activity.runOnUiThread {
      channel.invokeMethod(
        "callback", mutableMapOf(
          "guid" to guid,
          "type" to type,
          "data" to payload
        )
      )
    }
  }

  private var _findPrintersResult: Result? = null
  private var _findPrintersArgs: Map<*, *>? = null

  private fun hasBluetoothPermission(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
      return true
    }

    return checkSelfPermission(activity, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
  }

  private fun findPrinters(@NonNull args: Map<*, *>, result: Result, requestBluetooth: Boolean = true) {
    Log.d("Discovery", "findPrinters")
    _findPrintersResult = result
    _findPrintersArgs = args

    val callbackGuid = args["callback"] as String?
    val timeout = args["timeout"] as Int
    val interfaces = args["interfaces"] as List<*>

    try {
      val foundPrinters: MutableList<StarPrinter> = mutableListOf()

      // Specify your printer interface types.
      val interfaceTypes: List<InterfaceType> = (interfaces.map {
        when (it as String?) {
          "lan" -> InterfaceType.Lan
          "bluetooth" -> InterfaceType.Bluetooth
          "bluetoothLE" -> InterfaceType.Bluetooth
          "usb" -> InterfaceType.Usb
          else -> InterfaceType.Unknown
        }
      }).toList()

      if (interfaceTypes.contains(InterfaceType.Bluetooth)) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !hasBluetoothPermission() && requestBluetooth) {
          _permissionCallback = { requestCode, _, grantResults ->
            if (requestCode == 1000 && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
              findPrinters(args, result, false)
            } else {
              result.error("error", "Bluetooth permission denied", null)
            }
          }

          requestPermissions(activity,
            arrayOf(
              Manifest.permission.BLUETOOTH_CONNECT,
            ), 1000
          )

          Log.d("Discovery", "requesting bluetooth permission")

          return
        }
      }

      _manager = StarDeviceDiscoveryManagerFactory.create(
              interfaceTypes,
              activity
      )

      _manager?.discoveryTime = timeout
      _manager?.callback = object : StarDeviceDiscoveryManager.Callback {
        // Callback for printer found.
        override fun onPrinterFound(printer: StarPrinter) {
          foundPrinters.add(printer)
          if (callbackGuid != null) {
            sendCallback(callbackGuid, "printerFound", mutableMapOf(
              "model" to printer.information?.model?.value(),
              "identifier" to printer.connectionSettings.identifier,
              "interface" to printer.connectionSettings.interfaceType.value()
            ))
          }
        }

        // Callback for discovery finished. (option)
        override fun onDiscoveryFinished() {

          // TODO Remove this
          // foundPrinters.get(0).connectionSettings
          val settings = foundPrinters.get(0).connectionSettings
          val printer = StarPrinter(settings, activity)

          val job = SupervisorJob()
          val scope = CoroutineScope(Dispatchers.Default + job)

          scope.launch {
            try {
              val builder = StarXpandCommandBuilder()
              builder.addDocument(
                      DocumentBuilder()
                              .addDrawer(
                                      DrawerBuilder()
                                              .actionOpen(OpenParameter()
                                                      .setChannel(Channel.No1)
                                              )
                              )
              )

              val commands = builder.getCommands()

              printer.openAsync().await()
              printer.printAsync(commands).await()

              Log.d("Printing", "Success")
            } catch (e: StarIO10NotFoundException) {
              // Printer not found.
              // This may be due to the printer not being turned on or incorrect connection information.
            } catch (e: Exception) {
              Log.d("Printing", "Error: ${e}")
            } finally {
              printer.closeAsync().await()
            }
          }

          result.success(mutableMapOf(
                  "printers" to foundPrinters.map {
                    mutableMapOf(
                            "model" to it.information?.model?.value(),
                            "identifier" to it.connectionSettings.identifier,
                            "interface" to it.connectionSettings.interfaceType.value()
                    )
                  }
          ))
        }
      }

      _manager?.startDiscovery()
    } catch (e: Exception) {
      // Exception.
      Log.d("Discovery", "${e.message}")
      result.error("error", e.localizedMessage, e)
    }
  }

  private fun stopInputListener(@NonNull args: Map<*, *>, result: Result) {
    Log.d("Discovery", "startInputListener. ${args["printer"]}")
    val printer = getPrinter(args["printer"] as Map<*, *>)

    val job = SupervisorJob()
    val scope = CoroutineScope(Dispatchers.Default + job)
    scope.launch {
      closePrinter(printer)

      result.success(true)
    }
  }

  private fun startInputListener(@NonNull args: Map<*, *>, result: Result) {
    Log.d("Discovery", "startInputListener. ${args["printer"]}")
    val callbackGuid = args["callback"] as String

    val printer = getPrinter(args["printer"] as Map<*, *>)

    printer.inputDeviceDelegate = object : InputDeviceDelegate() {
      override fun onDataReceived(data: List<Byte>) {
        super.onDataReceived(data)

        val string = String(data.toByteArray())

        sendCallback(callbackGuid, "dataReceived", mutableMapOf(
          "data" to data.toByteArray(),
          "string" to string
        ))
      }
    }

    val job = SupervisorJob()
    val scope = CoroutineScope(Dispatchers.Default + job)
    scope.launch {
      try {
        closePrinter(printer)
        openPrinter(printer)

        result.success(true)
      } catch (e: Exception) {
        result.error("error", e.localizedMessage, e)
      }
    }
  }

  private suspend fun openPrinter(printer: StarPrinter): Boolean {
    return try {
      printer.openAsync().await()
      true
    } catch (e: Exception) {
      e is StarIO10InvalidOperationException
    }
  }


  private suspend fun closePrinter(printer: StarPrinter): Boolean {
    return try {
      printer.closeAsync().await()
      true
    } catch (e: Exception) {
      false
    }
  }

  private fun printDocument(@NonNull args: Map<*, *>, result: Result) {
    Log.d("print", "print. ${args["printer"]}")

    val printer = getPrinter(args["printer"] as Map<*, *>)
    val document = args["document"] as Map<*, *>
    val contents = document["contents"] as Collection<*>

    Log.d("print", "document: $document")

    val job = SupervisorJob()
    val scope = CoroutineScope(Dispatchers.Default + job)
    scope.launch {
      if (openPrinter(printer)) {
        try {
          val builder = StarXpandCommandBuilder()
          val docBuilder = DocumentBuilder()

          for (content in contents) {
            if (content !is Map<*, *>) continue

            val type = content["type"] as String
            val data = content["data"] as Map<*, *>

            when (type) {
              "drawer" -> {
                docBuilder.addDrawer(getDrawerBuilder(data))
              }
              "print" -> {
                docBuilder.addPrinter(getPrinterBuilder(data))
              }
            }
          }

          builder.addDocument(docBuilder)

          // Get printing data from StarXpandCommandBuilder object.
          val commands = builder.getCommands()

          Log.d("print", "commands $commands")

          // Print.
          printer.printAsync(commands).await()
          result.success(true)
        } catch (e: java.lang.Exception) {
          Log.d("print", "commands $e")
          result.error("error", e.localizedMessage, e)
        } finally {
          closePrinter(printer)
        }
      }
    }
  }

  private fun getDrawerBuilder(data: Map<*, *>): DrawerBuilder {
    val channel = when (data["channel"]) {
      "no1" -> Channel.No1
      "no2" -> Channel.No2
      else -> Channel.No1
    }
    return DrawerBuilder().actionOpen(OpenParameter().setChannel(channel))
  }

  private fun getPrinterBuilder(data: Map<*, *>): PrinterBuilder {
    val printerBuilder = PrinterBuilder()

    val actions = data["actions"] as Collection<*>

    Log.d("print", "print actions: $actions")

    for (action in actions) {
      if (action !is Map<*, *>) continue

      when (action["action"] as String) {
        "add" -> {
          printerBuilder.add(getPrinterBuilder(action["data"] as Map<*, *>))
        }
        "style" -> {
          if (action["alignment"] != null) {
            printerBuilder.styleAlignment(when (action["alignment"]) {
              "left" -> Alignment.Left
              "center" -> Alignment.Center
              "right" -> Alignment.Right
              else -> Alignment.Left
            })
          }

          if (action["fontType"] != null) {
            printerBuilder.styleFont(when (action["fontType"]) {
              "a" -> FontType.A
              "b" -> FontType.B
              else -> FontType.A
            })
          }

          if (action["bold"] != null) {
            printerBuilder.styleBold(action["bold"] as Boolean)
          }

          if (action["invert"] != null) {
            printerBuilder.styleInvert(action["invert"] as Boolean)
          }

          if (action["underLine"] != null) {
            printerBuilder.styleUnderLine(action["underLine"] as Boolean)
          }

          if (action["magnification"] != null) {
            val magnification = action["magnification"] as Map<*, *>

            printerBuilder.styleMagnification(MagnificationParameter(magnification["width"] as Int, magnification["height"] as Int))
          }

          if (action["characterSpace"] != null) {
            printerBuilder.styleCharacterSpace(action["characterSpace"] as Double)
          }

          if (action["lineSpace"] != null) {
            printerBuilder.styleLineSpace(action["lineSpace"] as Double)
          }

          if (action["horizontalPositionTo"] != null) {
            printerBuilder.styleHorizontalPositionTo(action["horizontalPositionTo"] as Double)
          }

          if (action["horizontalPositionBy"] != null) {
            printerBuilder.styleHorizontalPositionBy(action["horizontalPositionBy"] as Double)
          }

          if (action["horizontalTabPosition"] != null) {
            printerBuilder.styleHorizontalTabPositions((action["horizontalTabPosition"] as List<*>).map { it as Int })
          }

          if (action["internationalCharacter"] != null) {
            printerBuilder.styleInternationalCharacter(when (action["internationalCharacter"]) {
              "usa" -> InternationalCharacterType.Usa
              "france" -> InternationalCharacterType.France
              "germany" -> InternationalCharacterType.Germany
              "uk" -> InternationalCharacterType.UK
              "denmark" -> InternationalCharacterType.Denmark
              "sweden" -> InternationalCharacterType.Sweden
              "italy" -> InternationalCharacterType.Italy
              "spain" -> InternationalCharacterType.Spain
              "japan" -> InternationalCharacterType.Japan
              "norway" -> InternationalCharacterType.Norway
              "denmark2" -> InternationalCharacterType.Denmark2
              "spain2" -> InternationalCharacterType.Spain2
              "latinAmerica" -> InternationalCharacterType.LatinAmerica
              "korea" -> InternationalCharacterType.Korea
              "ireland" -> InternationalCharacterType.Ireland
              "slovenia" -> InternationalCharacterType.Slovenia
              "croatia" -> InternationalCharacterType.Croatia
              "china" -> InternationalCharacterType.China
              "vietnam" -> InternationalCharacterType.Vietnam
              "arabic" -> InternationalCharacterType.Arabic
              "legal" -> InternationalCharacterType.Legal
              else -> InternationalCharacterType.Usa
            })
          }

          if (action["secondPriorityCharacterEncoding"] != null) {
            printerBuilder.styleSecondPriorityCharacterEncoding(when (data["secondPriorityCharacterEncoding"]) {
              "japanese" -> CharacterEncodingType.Japanese
              "simplifiedChinese" -> CharacterEncodingType.SimplifiedChinese
              "traditionalChinese" -> CharacterEncodingType.TraditionalChinese
              "korean" -> CharacterEncodingType.Korean
              "codePage" -> CharacterEncodingType.CodePage
              else -> CharacterEncodingType.CodePage
            })
          }

          if (action["cjkCharacterPriority"] != null) {
            printerBuilder.styleCjkCharacterPriority((action["cjkCharacterPriority"] as List<*>).map {
              when (it as String?) {
                "japanese" -> CjkCharacterType.Japanese
                "simplifiedChinese" -> CjkCharacterType.SimplifiedChinese
                "traditionalChinese" -> CjkCharacterType.TraditionalChinese
                "korean" -> CjkCharacterType.Korean
                else -> CjkCharacterType.Japanese
              }
            })
          }
        }
        "cut" -> {
          val cutType = when (action["type"]) {
            "full" -> CutType.Full
            "partial" -> CutType.Partial
            "fullDirect" -> CutType.FullDirect
            "partialDirect" -> CutType.PartialDirect
            else -> CutType.Partial
          }
          printerBuilder.actionCut(cutType)
        }
        "feed" -> {
          val height = (action["height"] as Double?) ?: 10.0
          printerBuilder.actionFeed(height)
        }
        "feedLine" -> {
          val lines = (action["lines"] as Int?) ?: 1
          printerBuilder.actionFeedLine(lines)
        }
        "printText" -> {
          val text = action["text"] as String
          printerBuilder.actionPrintText(text)
        }
        "printLogo" -> {
          val keyCode = action["keyCode"] as String
          printerBuilder.actionPrintLogo(LogoParameter(keyCode))
        }
        "printBarcode" -> {
          val barcodeContent = action["content"] as String
          val symbology = when (action["symbology"] as String) {
            "upcE" -> BarcodeSymbology.UpcE
            "upcA" -> BarcodeSymbology.UpcA
            "jan8" -> BarcodeSymbology.Jan8
            "ean8" -> BarcodeSymbology.Ean8
            "jan13" -> BarcodeSymbology.Jan13
            "ean13" -> BarcodeSymbology.Ean13
            "code39" -> BarcodeSymbology.Code39
            "itf" -> BarcodeSymbology.Itf
            "code128" -> BarcodeSymbology.Code128
            "code93" -> BarcodeSymbology.Code93
            "nw7" -> BarcodeSymbology.NW7
            else -> BarcodeSymbology.UpcE
          }

          val param = BarcodeParameter(barcodeContent, symbology)
          if (action["printHri"] != null) {
            param.setPrintHri(action["printHri"] as Boolean)
          }
          if (action["barDots"] != null) {
            param.setBarDots(action["barDots"] as Int)
          }
          if (action["barRatioLevel"] != null) {
            param.setBarRatioLevel(when (action["barRatioLevel"] as String) {
              "levelPlus1" -> BarcodeBarRatioLevel.LevelPlus1
              "level0" -> BarcodeBarRatioLevel.Level0
              "levelMinus1" -> BarcodeBarRatioLevel.LevelMinus1
              else -> BarcodeBarRatioLevel.Level0
            })
          }
          if (action["height"] != null) {
            param.setHeight(action["height"] as Double)
          }

          printerBuilder.actionPrintBarcode(param)
        }
        "printPdf417" -> {
          val pdf417Content = action["content"] as String
          val param = Pdf417Parameter(pdf417Content)

          if (action["column"] != null) {
            param.setColumn(action["column"] as Int)
          }
          if (action["line"] != null) {
            param.setLine(action["line"] as Int)
          }
          if (action["module"] != null) {
            param.setModule(action["module"] as Int)
          }
          if (action["aspect"] != null) {
            param.setAspect(action["aspect"] as Int)
          }
          if (action["level"] != null) {
            param.setLevel(when (action["level"] as String) {
              "ecc0" -> Pdf417Level.Ecc0
              "ecc1" -> Pdf417Level.Ecc1
              "ecc2" -> Pdf417Level.Ecc2
              "ecc3" -> Pdf417Level.Ecc3
              "ecc4" -> Pdf417Level.Ecc4
              "ecc5" -> Pdf417Level.Ecc5
              "ecc6" -> Pdf417Level.Ecc6
              "ecc7" -> Pdf417Level.Ecc7
              "ecc8" -> Pdf417Level.Ecc8
              else -> Pdf417Level.Ecc0
            })
          }

          printerBuilder.actionPrintPdf417(param)
        }
        "printQRCode" -> {
          val qrContent = action["content"] as String
          val param = QRCodeParameter(qrContent)

          if (action["model"] != null) {
            param.setModel(when (action["model"] as String) {
              "model1" -> QRCodeModel.Model1
              "model2" -> QRCodeModel.Model2
              else -> QRCodeModel.Model1
            })
          }
          if (action["level"] != null) {
            param.setLevel(when (action["level"] as String) {
              "l" -> QRCodeLevel.L
              "m" -> QRCodeLevel.M
              "q" -> QRCodeLevel.Q
              "h" -> QRCodeLevel.H
              else -> QRCodeLevel.L
            })
          }
          if (action["cellSize"] != null) {
            param.setCellSize(action["cellSize"] as Int)
          }

          printerBuilder.actionPrintQRCode(param)
        }
        "printImage" -> {
          val image = action["image"] as ByteArray
          val width = action["width"] as Int
          val bmp = BitmapFactory.decodeByteArray(image, 0, image.size)
          printerBuilder.actionPrintImage(ImageParameter(bmp, width))
        }
      }
    }
    return printerBuilder
  }
}

fun InterfaceType.value() : String {
  return when (this) {
    InterfaceType.Lan -> "lan"
    InterfaceType.Bluetooth -> "bluetooth"
    InterfaceType.Usb -> "usb"
    else -> "unknown"
  }
}

fun interfaceTypeFromValue(value: String) : InterfaceType? {
  return when (value) {
    "lan" -> InterfaceType.Lan
    "bluetooth" -> InterfaceType.Bluetooth
    "usb" -> InterfaceType.Usb
    else -> null
  }
}

fun StarPrinterModel.value() : String {
  return when (this) {
    StarPrinterModel.TSP650II -> "tsp650II"
    StarPrinterModel.TSP700II -> "tsp700II"
    StarPrinterModel.TSP800II -> "tsp800II"
    StarPrinterModel.TSP100IIU_Plus -> "tsp100IIUPlus"
    StarPrinterModel.TSP100IIIW -> "tsp100IIIW"
    StarPrinterModel.TSP100IIILAN -> "tsp100IIILAN"
    StarPrinterModel.TSP100IIIBI -> "tsp100IIIBI"
    StarPrinterModel.TSP100IIIU -> "tsp100IIIU"
    StarPrinterModel.TSP100IV -> "tsp100IV"
    StarPrinterModel.mPOP -> "mPOP"
    StarPrinterModel.mC_Print2 -> "mCPrint2"
    StarPrinterModel.mC_Print3 -> "mCPrint3"
    StarPrinterModel.SM_S210i -> "smS210i"
    StarPrinterModel.SM_S230i -> "smS230i"
    StarPrinterModel.SM_T300 -> "smT300"
    StarPrinterModel.SM_T300i -> "smT300i"
    StarPrinterModel.SM_T400i -> "smT400i"
    StarPrinterModel.SM_L200 -> "smL200"
    StarPrinterModel.SM_L300 -> "smL300"
    StarPrinterModel.SP700 -> "sp700"
    else -> "unknown"
  }
}