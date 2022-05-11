package com.ovatu.starxpand

import android.app.Activity
import android.graphics.BitmapFactory
import android.graphics.fonts.Font
import android.util.Log
import androidx.annotation.NonNull
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
import java.lang.StringBuilder

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
      "print" -> print(call.arguments as Map<*, *>)
      "openDrawer" -> openDrawer(call.arguments as Map<*, *>)
      "startInputListener" -> startInputListener(call.arguments as Map<*, *>)
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
      _manager?.discoveryTime = 3000

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

  fun startInputListener(@NonNull args: Map<*, *>) {
    Log.d("Discovery", "startInputListener. ${args["printer"]}")
    val printer = buildPrinter(args["printer"] as Map<*, *>)

    printer.inputDeviceDelegate = object : InputDeviceDelegate() {
      override fun onCommunicationError(e: StarIO10Exception) {
        super.onCommunicationError(e)
        Log.d("Monitor", "Input Device: Communication Error")
        Log.d("Monitor", "${e}")
      }

      override fun onConnected() {
        super.onConnected()
        Log.d("Monitor", "Input Device: Connected")
      }

      override fun onDisconnected() {
        super.onDisconnected()
        Log.d("Monitor", "Input Device: Disconnected")
      }

      override fun onDataReceived(data: List<Byte>) {
        super.onDataReceived(data)

        val string = String(data.toByteArray())

        Log.d("Monitor", "Input Device: DataReceived $string")
      }
    }

    val job = SupervisorJob()
    val scope = CoroutineScope(Dispatchers.Default + job)
    scope.launch {
      printer.openAsync().await()
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

  fun print(@NonNull args: Map<*, *>) {
    Log.d("Discovery", "print. ${args["printer"]}")

    val printer = buildPrinter(args["printer"] as Map<*, *>)
    val document = args["document"] as Map<*, *>
    val contents = document["contents"] as Collection<Map<*, *>>

    Log.d("print", "document: $document")

    val job = SupervisorJob()
    val scope = CoroutineScope(Dispatchers.Default + job)
    scope.launch {
      try {
        // Connect to the printer.
        printer.openAsync().await()

        val builder = StarXpandCommandBuilder()
        var docBuilder = DocumentBuilder();

        for (content in contents) {
          val type = content["type"] as String
          val data = content["data"] as Map<*, *>

          when (type) {
            "drawer" -> {
              docBuilder.addDrawer(drawerBuilder(data))
            }
            "print" -> {
              docBuilder.addPrinter(printerBuilder(data))
            }
          }
        }

        builder.addDocument(docBuilder)

        // Get printing data from StarXpandCommandBuilder object.
        val commands = builder.getCommands()

        Log.d("print", "commands $commands")

        // Print.
        printer.printAsync(commands).await()

        Log.d("print", "done")

      } catch (e: Exception) {
        // Exception.
        Log.d("Printing", "${e.message}")
      } finally {
        // Disconnect from the printer.
        printer.closeAsync().await()
      }
    }
  }

  fun drawerBuilder(data: Map<*, *>): DrawerBuilder {
    val channel = when (data["channel"]) {
      "no1" -> Channel.No1
      "no2" -> Channel.No2
      else -> Channel.No1
    }
    return DrawerBuilder().actionOpen(OpenParameter().setChannel(channel))
  }

  fun printerBuilder(data: Map<*, *>): PrinterBuilder {
    val printerBuilder = PrinterBuilder()

    val actions = data["actions"] as Collection<Map<*, *>>

    Log.d("print", "print actions: $actions")

    for (action in actions) {
      when (action["action"] as String) {
        "add" -> {
          printerBuilder.add(printerBuilder(action["data"] as Map<*, *>))
        }
        "style" -> {
          if (action["alignment"] != null) {
            printerBuilder.styleAlignment(when (data["alignment"]) {
              "left" -> Alignment.Left
              "center" -> Alignment.Center
              "right" -> Alignment.Right
              else -> Alignment.Left
            })
          }

          if (action["fontType"] != null) {
            printerBuilder.styleFont(when (data["fontType"]) {
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
            printerBuilder.styleHorizontalTabPositions(action["horizontalTabPosition"] as List<Int>)
          }

          if (action["internationalCharacter"] != null) {
            printerBuilder.styleInternationalCharacter(when (data["internationalCharacter"]) {
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
            printerBuilder.styleCjkCharacterPriority((action["cjkCharacterPriority"] as List<String>).map {
              when (it) {
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
          val cutType = when (data["type"]) {
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
          val bmp = BitmapFactory.decodeByteArray(image, 0, image.size);
          printerBuilder.actionPrintImage(ImageParameter(bmp, width))
        }
      }
    }
    return printerBuilder
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
