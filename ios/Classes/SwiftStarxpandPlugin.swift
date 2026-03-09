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
            case "open": _open(args: call.arguments as! [String:Any?], result: result)
            case "close": _close(args: call.arguments as! [String:Any?], result: result)
            default:
            result(false)
        }
    }
    
    func sendCallback(guid: String, type: String, payload: Dictionary<String, Any?>) {
        DispatchQueue.main.async {
            // Call the desired channel message here.

            self.channel.invokeMethod("callback", arguments:[
                "guid": guid,
                "type": type,
                "data": payload
            ])
        }
    }

    func _findPrinters(args: [String:Any?], result: @escaping FlutterResult) {
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
                    "model": printer.information?.model.stringValue(),
                    "identifier": printer.connectionSettings.identifier,
                    "interface": printer.connectionSettings.interfaceType.stringValue()
                ])
                }
            }, didFinishDiscovery: { _, printers in
                result([
                    "printers": printers.map({ p in
                        [
                            "model": p.information?.model.stringValue(),
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
    

    func _open(args: [String:Any?], result: @escaping FlutterResult) {
        let printer = getPrinter(args["printer"] as! [String:Any])

        Task {
            do {
                try await printer.open()
                result(true)
            } catch let e3rror {
                result(false)
            }
        }
    }

    func _close(args: [String:Any?], result: @escaping FlutterResult) {
        let printer = getPrinter(args["printer"] as! [String:Any])

        Task {
            do {
                await printer.close()

                result(true)
             } catch let e3rror {
           

                result(false)
            }
        }
    }

    func _printDocument(args: [String:Any?], result: @escaping FlutterResult) {
        let printer = getPrinter(args["printer"] as! [String:Any])

        let document = args["document"] as! [String:Any?]
        let contents = document["contents"] as! Array<[String:Any?]>

        Task {
            do {
                try await printer.open()

                let builder = StarXpandCommand.StarXpandCommandBuilder()
                let docBuilder = StarXpandCommand.DocumentBuilder.init()
                
                for content in contents {
                    let type = content["type"] as! String
                    let data = content["data"] as! [String:Any?]

                    switch (type) {
                        case "drawer":
                            _ = docBuilder.addDrawer(getDrawerBuilder(data))
                          
                        case "print":
                            _ = docBuilder.addPrinter(getPrinterBuilder(data))
                    default:
                        print("nope")
                    }
                }

                _ = builder.addDocument(docBuilder)

                // Get printing data from StarXpandCommandBuilder object.
                let commands = builder.getCommands()
                            
                try await printer.print(command: commands)
                await printer.close()
                
                result(true)
            } catch let e3rror {
                await printer.close()

                result(false)
            }
        }
    }

    func _stopInputListener(args: [String:Any?], result: @escaping FlutterResult) {
        let callbackGuid = args["callback"] as! String
        let printer = getPrinter(args["printer"] as! [String:Any])

        Task {
            await printer.close()

            inputManagers.removeValue(forKey: callbackGuid)
            result(true)
        }
    }

    func _startInputListener(args: [String:Any?], result: @escaping FlutterResult) {
        let callbackGuid = args["callback"] as! String

        let printer = getPrinter(args["printer"] as! [String:Any])

        inputManagers[callbackGuid] = SwiftStarxpandPluginInputManager(
            didReceiveData: {
                data in self.sendCallback(guid: callbackGuid, type: "dataReceived", payload: [
                    "data": FlutterStandardTypedData(bytes: data),
                    "string": String(decoding: data, as: UTF8.self)
                ])
            }, didReceiveError: {
                error in self.sendCallback(guid: callbackGuid + "_error", type: "errorReceived", payload: [
                    "error": error.localizedDescription
                ])
            }, didConnect: {
                self.sendCallback(guid: callbackGuid + "_connected", type: "connected", payload: [:])
            }, didDisconnect: {
                self.sendCallback(guid: callbackGuid + "_disconnected", type: "disconnected", payload: [:])
            }
        )
        
        printer.inputDeviceDelegate = inputManagers[callbackGuid]!
        
        Task {
            do {
                try await printer.open()
            } catch let e3rror {
                 await printer.close()
              result(false)
            }
            
            result(true)
        }
    }
    
    func getPrinter(_ printer : [String:Any]) -> StarPrinter {
        let connection = StarConnectionSettings(interfaceType: InterfaceType.fromString(printer["interface"] as! String),
                                                            identifier: printer["identifier"] as! String, autoSwitchInterface: true)
        
        if (!printers.keys.contains(connection.description)) {
            let printer = StarPrinter(connection)
            printers[connection.description] = printer
        }
        
        return printers[connection.description]!
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
                    _ = printerBuilder.add(getPrinterBuilder(action["data"] as! [String:Any?]))
                case "style":
                    if (action["alignment"] != nil) {
                        switch (action["alignment"] as! String) {
                            case "left": _ = printerBuilder.styleAlignment(.left)
                            case "center": _ = printerBuilder.styleAlignment(.center)
                            case "right": _ = printerBuilder.styleAlignment(.right)
                            default: _ = printerBuilder.styleAlignment(.left)
                        }
                    }

                    if (action["fontType"] != nil) {
                        switch (action["fontType"] as! String) {
                            case "a": _ = printerBuilder.styleFont(.a)
                            case "b": _ = printerBuilder.styleFont(.b)
                            default: _ = printerBuilder.styleFont(.a)
                        }
                    }
                
                    if (action["bold"] != nil) {
                        _ = printerBuilder.styleBold(action["bold"] as! Bool)
                    }

                    if (action["invert"] != nil) {
                        _ = printerBuilder.styleInvert(action["invert"] as! Bool)
                    }

                    if (action["underLine"] != nil) {
                        _ = printerBuilder.styleUnderLine(action["underLine"] as! Bool)
                    }

                    if (action["magnification"] != nil) {
                        let magnification = action["magnification"] as! Dictionary<String, Int>

                        _ = printerBuilder.styleMagnification(StarXpandCommand.MagnificationParameter(width: magnification["width"]!, height: magnification["height"]!))
                    }

                    if (action["characterSpace"] != nil) {
                        _ = printerBuilder.styleCharacterSpace(action["characterSpace"] as! Double)
                    }

                    if (action["lineSpace"] != nil) {
                        _ = printerBuilder.styleLineSpace(action["lineSpace"] as! Double)
                    }

                    if (action["horizontalPositionTo"] != nil) {
                        _ = printerBuilder.styleHorizontalPositionTo(action["horizontalPositionTo"] as! Double)
                    }

                    if (action["horizontalPositionBy"] != nil) {
                        _ = printerBuilder.styleHorizontalPositionBy(action["horizontalPositionBy"] as! Double)
                    }

                    if (action["horizontalTabPosition"] != nil) {
                        _ = printerBuilder.styleHorizontalTabPositions(action["horizontalTabPosition"] as! Array<Int>)
                    }

                    if (action["internationalCharacter"] != nil) {
                        switch (action["internationalCharacter"] as! String) {
                            case "usa": _ = printerBuilder.styleInternationalCharacter(.usa)
                            case "france": _ = printerBuilder.styleInternationalCharacter(.france)
                            case "germany": _ = printerBuilder.styleInternationalCharacter(.germany)
                            case "uk": _ = printerBuilder.styleInternationalCharacter(.uk)
                            case "denmark": _ = printerBuilder.styleInternationalCharacter(.denmark)
                            case "sweden": _ = printerBuilder.styleInternationalCharacter(.sweden)
                            case "italy": _ = printerBuilder.styleInternationalCharacter(.italy)
                            case "spain": _ = printerBuilder.styleInternationalCharacter(.spain)
                            case "japan": _ = printerBuilder.styleInternationalCharacter(.japan)
                            case "norway": _ = printerBuilder.styleInternationalCharacter(.norway)
                            case "denmark2": _ = printerBuilder.styleInternationalCharacter(.denmark2)
                            case "spain2": _ = printerBuilder.styleInternationalCharacter(.spain2)
                            case "latinAmerica": _ = printerBuilder.styleInternationalCharacter(.latinAmerica)
                            case "korea": _ = printerBuilder.styleInternationalCharacter(.korea)
                            case "ireland": _ = printerBuilder.styleInternationalCharacter(.ireland)
                            case "slovenia":_ =  printerBuilder.styleInternationalCharacter(.slovenia)
                            case "croatia": _ = printerBuilder.styleInternationalCharacter(.croatia)
                            case "china": _ = printerBuilder.styleInternationalCharacter(.china)
                            case "vietnam": _ = printerBuilder.styleInternationalCharacter(.vietnam)
                            case "arabic": _ = printerBuilder.styleInternationalCharacter(.arabic)
                            case "legal": _ = printerBuilder.styleInternationalCharacter(.legal)
                            default: _ = printerBuilder.styleInternationalCharacter(.usa)
                        }
                    }

                    
                    if (action["secondPriorityCharacterEncoding"] != nil) {
                        switch (action["secondPriorityCharacterEncoding"] as! String) {
                            case "japanese": _ = printerBuilder.styleSecondPriorityCharacterEncoding(.japanese)
                            case "simplifiedChinese": _ = printerBuilder.styleSecondPriorityCharacterEncoding(.simplifiedChinese)
                            case "traditionalChinese": _ = printerBuilder.styleSecondPriorityCharacterEncoding(.traditionalChinese)
                            case "korean": _ = printerBuilder.styleSecondPriorityCharacterEncoding(.korean)
                            case "codePage": _ = printerBuilder.styleSecondPriorityCharacterEncoding(.codePage)
                            default: _ = printerBuilder.styleSecondPriorityCharacterEncoding(.japanese)
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
                        
                        _ = printerBuilder.styleCJKCharacterPriority(types)
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

                    _ = printerBuilder.actionCut(cutType)

                case "feed":
                    let height = (action["height"] as? Double) ?? 10.0
                    _ = printerBuilder.actionFeed(height)
                case "feedLine":
                    let lines = (action["lines"] as? Int) ?? 1
                    _ = printerBuilder.actionFeedLine(lines)
                case "printText":
                    let text = action["text"] as! String
                    _ = printerBuilder.actionPrintText(text)
                case "printLogo":
                    let keyCode = action["keyCode"] as! String
                    _ = printerBuilder.actionPrintLogo(StarXpandCommand.Printer.LogoParameter(keyCode: keyCode))
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
                        _ = param.setPrintHRI(action["printHri"] as! Bool)
                    }
                    if (action["barDots"] != nil) {
                        _ = param.setBarDots(action["barDots"] as! Int)
                    }
                    if (action["barRatioLevel"] != nil) {
                        switch (action["barRatioLevel"] as! String) {
                            case "levelPlus1": _ = param.setBarRatioLevel(.levelPlus1)
                            case "level0": _ = param.setBarRatioLevel(.level0)
                            case "levelMinus1": _ = param.setBarRatioLevel(.levelMinus1)
                            default: _ = param.setBarRatioLevel(.level0)
                        }
                    }
                    if (action["height"] != nil) {
                        _ = param.setHeight(action["height"] as! Double)
                    }

                    _ = printerBuilder.actionPrintBarcode(param)
                
                case "printPdf417":
                    let pdf417Content = action["content"] as! String
                    let param = StarXpandCommand.Printer.PDF417Parameter(content: pdf417Content)
                
                    if (action["column"] != nil) {
                        _ = param.setColumn(action["column"] as! Int)
                    }
                    if (action["line"] != nil) {
                        _ = param.setLine(action["line"] as! Int)
                    }
                    if (action["module"] != nil) {
                        _ = param.setModule(action["module"] as! Int)
                    }
                    if (action["aspect"] != nil) {
                        _ = param.setAspect(action["aspect"] as! Int)
                    }

                    if (action["level"] != nil) {
                        switch (action["model"] as! String) {
                            case "ecc0": _ = param.setLevel(.ecc0)
                            case "ecc1": _ = param.setLevel(.ecc1)
                            case "ecc2": _ = param.setLevel(.ecc2)
                            case "ecc3": _ = param.setLevel(.ecc3)
                            case "ecc4": _ = param.setLevel(.ecc4)
                            case "ecc5": _ = param.setLevel(.ecc5)
                            case "ecc6": _ = param.setLevel(.ecc6)
                            case "ecc7": _ = param.setLevel(.ecc7)
                            case "ecc8": _ = param.setLevel(.ecc8)
                            default: _ = param.setLevel(.ecc0)
                        }
                    }

                    _ = printerBuilder.actionPrintPDF417(param)

                case "printQRCode":
                    let qrContent = action["content"] as! String
                    let param = StarXpandCommand.Printer.QRCodeParameter(content: qrContent)

                    if (action["model"] != nil) {
                        switch (action["model"] as! String) {
                            case "model1": _ = param.setModel(.model1)
                            case "model2": _ = param.setModel(.model2)
                            default: _ = param.setModel(.model1)
                        }
                    }

                    if (action["level"] != nil) {
                        switch (action["level"] as! String) {
                            case "l": _ = param.setLevel(.l)
                            case "m": _ = param.setLevel(.m)
                            case "q": _ = param.setLevel(.q)
                            case "h": _ = param.setLevel(.h)
                            default: _ = param.setLevel(.l)
                        }
                    }
                
                    if (action["cellSize"] != nil) {
                        _ = param.setCellSize(action["cellSize"] as! Int)
                    }

                    _ = printerBuilder.actionPrintQRCode(param)

                case "printImage":
                    let image = action["image"] as! FlutterStandardTypedData
                    let width = action["width"] as! Int
                    let bmp = UIImage(data: image.data)

                    if (bmp != nil) {
                        _ = printerBuilder.actionPrintImage(StarXpandCommand.Printer.ImageParameter(image: bmp!, width: width))
                    }
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
        printers.append(printer)
        didFindPrinter(manager, printer)
    }
    
    public func managerDidFinishDiscovery(_ manager: StarDeviceDiscoveryManager) {
        didFinishDiscovery(manager, printers)
    }
}

class SwiftStarxpandPluginInputManager: InputDeviceDelegate {
    var didReceiveData: (Data) -> Void
    var didReceiveError: (Error) -> Void
    var didConnect: () -> Void
    var didDisconnect: () -> Void

    init(
        didReceiveData: @escaping (Data) -> Void,
        didReceiveError: @escaping (Error) -> Void,
        didConnect: @escaping () -> Void,
        didDisconnect: @escaping () -> Void
    ) {
        // perform some initialization here
        self.didReceiveData = didReceiveData
        self.didReceiveError = didReceiveError
        self.didConnect = didConnect
        self.didDisconnect = didDisconnect
    }

    func inputDevice(printer: StarIO10.StarPrinter, communicationErrorDidOccur error: Error) {
        didReceiveError(error)
    }

    func inputDeviceDidConnect(printer: StarIO10.StarPrinter) {
        didConnect()
    }

    func inputDeviceDidDisconnect(printer: StarIO10.StarPrinter) {
        didDisconnect()
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
            default: return "unknown"
        }
    }
    
    static func fromString(_ value : String) -> StarIO10.InterfaceType {
        switch (value) {
            case "unknown": return .unknown
            case "usb": return .usb
            case "bluetooth": return .bluetooth
            case "bluetoothLE": return .bluetoothLE
            case "lan": return .lan
            default: return .unknown
        }
    }
}

extension StarIO10.StarPrinterModel {
    public func stringValue() -> String {
        switch (self) {
            case .tsp650II: return "tsp650II"
            case .tsp700II: return "tsp700II"
            case .tsp800II: return "tsp800II"
            case .tsp100IIIW: return "tsp100IIIW"
            case .tsp100IIILAN: return "tsp100IIILAN"
            case .tsp100IIIBI: return "tsp100IIIBI"
            case .tsp100IIIU: return "tsp100IIIU"
            case .tsp100IV: return "tsp100IV"
            case .mPOP: return "mPOP"
            case .mC_Print2: return "mCPrint2"
            case .mC_Print3: return "mCPrint3"
            case .sm_S210i: return "smS210i"
            case .sm_S230i: return "smS230i"
            case .sm_T300i: return "smT300i"
            case .sm_T400i: return "smT400i"
            case .sm_L200: return "smL200"
            case .sm_L300: return "smL300"
            case .sp700: return "sp700"
            default: return "unknown"
        }
    }
}
