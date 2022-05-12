import Flutter
import UIKit
import StarIO10

public class SwiftStarxpandPlugin: NSObject, FlutterPlugin {
    var manager: StarDeviceDiscoveryManager? = nil
    var channel: FlutterMethodChannel! = nil

    var discoveryManager: SwiftStarxpandPluginDiscoveryManager? = nil
    var inputManagers: Dictionary<String, SwiftStarxpandPluginInputManager> = [:]

    var printers: Dictionary<String, StarPrinter> = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "starxpand", binaryMessenger: registrar.messenger())
        let instance = SwiftStarxpandPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "findPrinters": _findPrinters(args: call.arguments as! [String:Any?], result: result)
        case "printDocument": _printDocument(args: call.arguments as! [String:Any?], result: result)
        case "startInputListener": _startInputListener(args: call.arguments as! [String:Any?], result: result)
        case "stopInputListener": _stopInputListener(args: call.arguments as! [String:Any?], result: result)
            default:
            result(false)
        }
    }
    
    func sendCallback(guid: String, type: String, payload: Dictionary<String, Any?>) {
        channel.invokeMethod("callback", arguments:[
            "guid": guid,
            "type": type,
            "data": payload
          ]
        )
    }

    func _findPrinters(args: [String:Any?], result: @escaping FlutterResult) {
        print(args)
        do {
            let callbackGuid = args["callback"] as? String
            let timeout = args["timeout"] as! Int
            let interfaces = args["interfaces"] as! Array<String>
            
            // Specify your printer interface types.
            manager = try StarDeviceDiscoveryManagerFactory.create(interfaceTypes: interfaces.map { i in
                switch (i) {
                case "lan": return InterfaceType.lan
                case "bluetooth": return InterfaceType.bluetooth
                case "bluetoothLE": return InterfaceType.bluetoothLE
                case "usb": return InterfaceType.usb
                default: return InterfaceType.unknown
                }
            })

            manager?.discoveryTime = timeout
            
            guard let manager = manager else {
                return
            }

            discoveryManager = SwiftStarxpandPluginDiscoveryManager(didFindPrinter: { _, printer in
                if (callbackGuid != nil) {
                    self.sendCallback(guid: callbackGuid!, type: "printerFound", payload: [
                    "model": printer.information?.model.description,
                    "identifier": printer.connectionSettings.identifier,
                    "interface": printer.connectionSettings.interfaceType.stringValue()
                ])
                }
            }, didFinishDiscovery: { _, printers in
                print("here ", printers);
                result([
                    "printers": printers.map({ p in
                        [
                            "model": p.information?.model.description,
                            "identifier": p.connectionSettings.identifier,
                            "interface": p.connectionSettings.interfaceType.stringValue()
                        ]
                    })
                ])
            })
            
            manager.delegate = discoveryManager!

            
            // Start discovery.
            try manager.startDiscovery()
        } catch let error {
            // Error.
            print(error)
        }
    }
    
    func _printDocument(args: [String:Any?], result: @escaping FlutterResult) {
        let printer = getPrinter(args["printer"] as! [String:Any?])

        let document = args["document"] as! [String:Any?]
        let contents = document["contents"] as! Array<[String:Any?]>

        Task {
            do {
                await try printer.open()

                let builder = StarXpandCommand.StarXpandCommandBuilder()
                let docBuilder = StarXpandCommand.DocumentBuilder.init()
                
                for content in contents {
                    let type = content["type"] as! String
                    let data = content["data"] as! [String:Any?]

                    switch (type) {
                        case "drawer":
                            docBuilder.addDrawer(getDrawerBuilder(data))
                          
                        case "print":
                            docBuilder.addPrinter(getPrinterBuilder(data))
                    default:
                        print("nope")
                    }
                }

                builder.addDocument(docBuilder)

                // Get printing data from StarXpandCommandBuilder object.
                let commands = builder.getCommands()
                
                print(commands)
            
                await try printer.print(command: commands)
                await printer.close()
            } catch let e3rror {
              // Error.
                print(e3rror)
            }
        }
    }

    func _stopInputListener(args: [String:Any?], result: @escaping FlutterResult) {
        let callbackGuid = args["callback"] as! String
        let printer = getPrinter(args["printer"] as! [String:Any?])

        Task {
            await printer.close()
            inputManagers.removeValue(forKey: callbackGuid)
        }
    }

    func _startInputListener(args: [String:Any?], result: @escaping FlutterResult) {
        let callbackGuid = args["callback"] as! String

        let printer = getPrinter(args["printer"] as! [String:Any?])

        inputManagers[callbackGuid] = SwiftStarxpandPluginInputManager { data in
            print(data)
            print(String(decoding: data, as: UTF8.self))

            self.sendCallback(guid: callbackGuid, type: "dataReceived", payload: [
                "data": String(decoding: data, as: UTF8.self)
            ])
        }
        
        printer.inputDeviceDelegate = inputManagers[callbackGuid]!
        
        Task {
            await printer.close()
            await try printer.open()
        }
    }
    
    func getPrinter(_ printer : [String:Any]) -> StarPrinter {
        let connection = StarConnectionSettings(interfaceType: InterfaceType.fromString(printer["interface"] as! String),
                                                            identifier: printer["identifier"] as! String)
        
        if (!printers.keys.contains(connection.description)) {
            let printer = StarPrinter(connection)
            printers[connection.description] = printer
        }
        
        return StarPrinter(connection)
    }
    
    func getDrawerBuilder(_ data: [String:Any?]) -> StarXpandCommand.DrawerBuilder {
        
        var channel: StarXpandCommand.Drawer.Channel! = nil
        switch (data["channel"] as? String) {
            case "no1": channel = .no1
            case "no2": channel = .no2
            default: channel = .no1
        }

        return StarXpandCommand.DrawerBuilder.init().actionOpen(StarXpandCommand.Drawer.OpenParameter().setChannel(channel))
    }

    func getPrinterBuilder(_ data: [String:Any?]) -> StarXpandCommand.PrinterBuilder {
        let printerBuilder = StarXpandCommand.PrinterBuilder.init()
        
        let actions = data["actions"] as! Array<[String:Any?]>
        
        for action in actions {
            switch (action["action"] as! String) {
                case "add":
                    printerBuilder.add(getPrinterBuilder(action["data"] as! [String:Any?]))
                case "style":
                    if (action["alignment"] != nil) {
                        switch (action["alignment"] as! String) {
                            case "left": printerBuilder.styleAlignment(.left)
                            case "center": printerBuilder.styleAlignment(.center)
                            case "right": printerBuilder.styleAlignment(.right)
                            default: printerBuilder.styleAlignment(.left)
                        }
                    }

                    if (action["fontType"] != nil) {
                        switch (action["fontType"] as! String) {
                            case "a": printerBuilder.styleFont(.a)
                            case "b": printerBuilder.styleFont(.b)
                            default: printerBuilder.styleFont(.a)
                        }
                    }
                
                    if (action["bold"] != nil) {
                      printerBuilder.styleBold(action["bold"] as! Bool)
                    }

                    if (action["invert"] != nil) {
                      printerBuilder.styleInvert(action["invert"] as! Bool)
                    }

                    if (action["underLine"] != nil) {
                      printerBuilder.styleUnderLine(action["underLine"] as! Bool)
                    }

                    if (action["magnification"] != nil) {
                        let magnification = action["magnification"] as! Dictionary<String, Int>

                        printerBuilder.styleMagnification(StarXpandCommand.MagnificationParameter(width: magnification["width"]!, height: magnification["height"]!))
                    }

                    if (action["characterSpace"] != nil) {
                      printerBuilder.styleCharacterSpace(action["characterSpace"] as! Double)
                    }

                    if (action["lineSpace"] != nil) {
                      printerBuilder.styleLineSpace(action["lineSpace"] as! Double)
                    }

                    if (action["horizontalPositionTo"] != nil) {
                      printerBuilder.styleHorizontalPositionTo(action["horizontalPositionTo"] as! Double)
                    }

                    if (action["horizontalPositionBy"] != nil) {
                      printerBuilder.styleHorizontalPositionBy(action["horizontalPositionBy"] as! Double)
                    }

                    if (action["horizontalTabPosition"] != nil) {
                      printerBuilder.styleHorizontalTabPositions(action["horizontalTabPosition"] as! Array<Int>)
                    }

                    if (action["internationalCharacter"] != nil) {
                        switch (action["internationalCharacter"] as! String) {
                            case "usa": printerBuilder.styleInternationalCharacter(.usa)
                            case "france": printerBuilder.styleInternationalCharacter(.france)
                            case "germany": printerBuilder.styleInternationalCharacter(.germany)
                            case "uk": printerBuilder.styleInternationalCharacter(.uk)
                            case "denmark": printerBuilder.styleInternationalCharacter(.denmark)
                            case "sweden": printerBuilder.styleInternationalCharacter(.sweden)
                            case "italy": printerBuilder.styleInternationalCharacter(.italy)
                            case "spain": printerBuilder.styleInternationalCharacter(.spain)
                            case "japan": printerBuilder.styleInternationalCharacter(.japan)
                            case "norway": printerBuilder.styleInternationalCharacter(.norway)
                            case "denmark2": printerBuilder.styleInternationalCharacter(.denmark2)
                            case "spain2": printerBuilder.styleInternationalCharacter(.spain2)
                            case "latinAmerica": printerBuilder.styleInternationalCharacter(.latinAmerica)
                            case "korea": printerBuilder.styleInternationalCharacter(.korea)
                            case "ireland": printerBuilder.styleInternationalCharacter(.ireland)
                            case "slovenia": printerBuilder.styleInternationalCharacter(.slovenia)
                            case "croatia": printerBuilder.styleInternationalCharacter(.croatia)
                            case "china": printerBuilder.styleInternationalCharacter(.china)
                            case "vietnam": printerBuilder.styleInternationalCharacter(.vietnam)
                            case "arabic": printerBuilder.styleInternationalCharacter(.arabic)
                            case "legal": printerBuilder.styleInternationalCharacter(.legal)
                            default: printerBuilder.styleInternationalCharacter(.usa)
                        }
                    }

                    
                    if (action["secondPriorityCharacterEncoding"] != nil) {
                        switch (action["secondPriorityCharacterEncoding"] as! String) {
                            case "japanese": printerBuilder.styleSecondPriorityCharacterEncoding(.japanese)
                            case "simplifiedChinese": printerBuilder.styleSecondPriorityCharacterEncoding(.simplifiedChinese)
                            case "traditionalChinese": printerBuilder.styleSecondPriorityCharacterEncoding(.traditionalChinese)
                            case "korean": printerBuilder.styleSecondPriorityCharacterEncoding(.korean)
                            case "codePage": printerBuilder.styleSecondPriorityCharacterEncoding(.codePage)
                            default: printerBuilder.styleSecondPriorityCharacterEncoding(.japanese)
                        }
                    }

                
                    if (action["cjkCharacterPriority"] != nil) {
                        let types: Array<StarXpandCommand.Printer.CJKCharacterType> = (action["cjkCharacterPriority"] as! Array<String>).map { priority in
                            switch (priority) {
                            case "japanese": return .japanese
                                case "simplifiedChinese": return .simplifiedChinese
                                case "traditionalChinese": return .traditionalChinese
                                case "korean": return .korean
                                default: return .japanese
                            }
                        }
                        
                        printerBuilder.styleCJKCharacterPriority(types)
                    }
                
                case "cut":
                    var cutType: StarXpandCommand.Printer.CutType! = nil
                    switch (data["channel"] as? String) {
                        case "full": cutType = .full
                        case "partial": cutType = .partial
                        case "fullDirect": cutType = .fullDirect
                        case "partialDirect": cutType = .partialDirect
                        default: cutType = .partial
                    }

                    printerBuilder.actionCut(cutType)

                case "feed":
                    let height = (action["height"] as? Double) ?? 10.0
                    printerBuilder.actionFeed(height)
                case "feedLine":
                    let lines = (action["lines"] as? Int) ?? 1
                    printerBuilder.actionFeedLine(lines)
                case "printText":
                    let text = action["text"] as! String
                    printerBuilder.actionPrintText(text)
                case "printLogo":
                    let keyCode = action["keyCode"] as! String
                    printerBuilder.actionPrintLogo(StarXpandCommand.Printer.LogoParameter(keyCode: keyCode))
                case "printBarcode":
                    let barcodeContent = action["content"] as! String
                
                    var symbology: StarXpandCommand.Printer.BarcodeSymbology! = nil
                    switch (action["symbology"] as? String) {
                        case "upcE": symbology = .upcE
                        case "upcA": symbology = .upcA
                        case "jan8": symbology = .jan8
                        case "ean8": symbology = .ean8
                        case "jan13": symbology = .jan13
                        case "ean13": symbology = .ean13
                        case "code39": symbology = .code39
                        case "itf": symbology = .itf
                        case "code128": symbology = .code128
                        case "code93": symbology = .code93
                        case "nw7": symbology = .nw7
                        default: symbology = .upcE
                    }
                
                    let param = StarXpandCommand.Printer.BarcodeParameter(content: barcodeContent, symbology: symbology)

                    if (action["printHri"] != nil) {
                        param.setPrintHRI(action["printHri"] as! Bool)
                    }
                    if (action["barDots"] != nil) {
                        param.setBarDots(action["barDots"] as! Int)
                    }
                    if (action["barRatioLevel"] != nil) {
                        switch (action["barRatioLevel"] as! String) {
                            case "levelPlus1": param.setBarRatioLevel(.levelPlus1)
                            case "level0": param.setBarRatioLevel(.level0)
                            case "levelMinus1": param.setBarRatioLevel(.levelMinus1)
                            default: param.setBarRatioLevel(.level0)
                        }
                    }
                    if (action["height"] != nil) {
                        param.setHeight(action["height"] as! Double)
                    }

                    printerBuilder.actionPrintBarcode(param)
                
                case "printPdf417":
                    let pdf417Content = action["content"] as! String
                    let param = StarXpandCommand.Printer.PDF417Parameter(content: pdf417Content)
                
                    if (action["column"] != nil) {
                        param.setColumn(action["column"] as! Int)
                    }
                    if (action["line"] != nil) {
                        param.setLine(action["line"] as! Int)
                    }
                    if (action["module"] != nil) {
                        param.setModule(action["module"] as! Int)
                    }
                    if (action["aspect"] != nil) {
                        param.setAspect(action["aspect"] as! Int)
                    }

                    if (action["level"] != nil) {
                        switch (action["model"] as! String) {
                            case "ecc0": param.setLevel(.ecc0)
                            case "ecc1": param.setLevel(.ecc1)
                            case "ecc2": param.setLevel(.ecc2)
                            case "ecc3": param.setLevel(.ecc3)
                            case "ecc4": param.setLevel(.ecc4)
                            case "ecc5": param.setLevel(.ecc5)
                            case "ecc6": param.setLevel(.ecc6)
                            case "ecc7": param.setLevel(.ecc7)
                            case "ecc8": param.setLevel(.ecc8)
                            default: param.setLevel(.ecc0)
                        }
                    }

                    printerBuilder.actionPrintPDF417(param)

                case "printQRCode":
                    let qrContent = action["content"] as! String
                    let param = StarXpandCommand.Printer.QRCodeParameter(content: qrContent)

                    if (action["model"] != nil) {
                        switch (action["model"] as! String) {
                            case "model1": param.setModel(.model1)
                            case "model2": param.setModel(.model2)
                            default: param.setModel(.model1)
                        }
                    }

                    if (action["level"] != nil) {
                        switch (action["level"] as! String) {
                            case "l": param.setLevel(.l)
                            case "m": param.setLevel(.m)
                            case "q": param.setLevel(.q)
                            case "h": param.setLevel(.h)
                            default: param.setLevel(.l)
                        }
                    }
                
                    if (action["cellSize"] != nil) {
                        param.setCellSize(action["cellSize"] as! Int)
                    }

                    printerBuilder.actionPrintQRCode(param)

                case "printImage":
                    let image = action["image"] as! FlutterStandardTypedData
                    let width = action["width"] as! Int
                    let bmp = UIImage(data: image.data)!

                    printerBuilder.actionPrintImage(StarXpandCommand.Printer.ImageParameter(image: bmp, width: width))
                default:
                print("TODO")
            }
        }

        return printerBuilder
    }

}

class SwiftStarxpandPluginDiscoveryManager: StarDeviceDiscoveryManagerDelegate {
    var printers: Array<StarPrinter> = []
    var didFindPrinter: (StarDeviceDiscoveryManager, StarPrinter) -> Void
    var didFinishDiscovery: (StarDeviceDiscoveryManager, Array<StarPrinter>) -> Void

    init(didFindPrinter: @escaping (StarDeviceDiscoveryManager, StarPrinter) -> Void, didFinishDiscovery: @escaping (StarDeviceDiscoveryManager, Array<StarPrinter>) -> Void) {
        // perform some initialization here
        self.didFindPrinter = didFindPrinter
        self.didFinishDiscovery = didFinishDiscovery
    }

    public func manager(_ manager: StarDeviceDiscoveryManager, didFind printer: StarPrinter) {
        print("manager didFind printer")
        printers.append(printer)
        didFindPrinter(manager, printer)
    }
    
    public func managerDidFinishDiscovery(_ manager: StarDeviceDiscoveryManager) {
        print("managerDidFinishDiscovery")
        didFinishDiscovery(manager, printers)
    }
}

class SwiftStarxpandPluginInputManager: InputDeviceDelegate {
    var didReceiveData: (Data) -> Void

    init(didReceiveData: @escaping (Data) -> Void) {
        // perform some initialization here
        self.didReceiveData = didReceiveData
    }

    func inputDevice(printer: StarIO10.StarPrinter, communicationErrorDidOccur error: Error) {
        
    }

    func inputDeviceDidConnect(printer: StarIO10.StarPrinter) {
        
    }

    func inputDeviceDidDisconnect(printer: StarIO10.StarPrinter) {
        
    }

    public func inputDevice(printer: StarIO10.StarPrinter, didReceive data: Data) {
        didReceiveData(data)
    }
}

extension StarIO10.InterfaceType {
    public func stringValue() -> String {
        switch (self) {
        case .unknown: return "unknown"
        case .usb: return "usb"
        case .bluetooth: return "bluetooth"
        case .bluetoothLE: return "bluetoothLE"
        case .lan: return "lan"
        @unknown default:
            return "unknown"
        }
    }
    
    static func fromString(_ value : String) -> StarIO10.InterfaceType {
        switch (value) {
        case "unknown": return .unknown
        case "usb": return .usb
        case "bluetooth": return .bluetooth
        case "bluetoothLE": return .bluetoothLE
        case "lan": return .lan
        default:
            return .unknown
        }
    }
}
