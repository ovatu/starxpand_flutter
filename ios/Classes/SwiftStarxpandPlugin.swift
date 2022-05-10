import Flutter
import UIKit
import StarIO10

public class SwiftStarXpandPlugin: NSObject, FlutterPlugin, StarDeviceDiscoveryManagerDelegate {
    var manager: StarDeviceDiscoveryManager? = nil
    var result: FlutterResult? = nil
    
    var foundPrinters: Array<StarPrinter> = [];

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "starxpand", binaryMessenger: registrar.messenger())
        let instance = SwiftStarXpandPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.result = result;
        
        switch(call.method) {
        case "find": _find()
        case "openDrawer": _openDrawer(call.arguments as! [String:Any])
            default:
            _find()
        }
    }
    
    func _find() {
        do {
            foundPrinters.removeAll()
            
            // Specify your printer interface types.
            manager = try StarDeviceDiscoveryManagerFactory.create(interfaceTypes: [
                InterfaceType.lan,
                InterfaceType.bluetooth,
                InterfaceType.bluetoothLE,
                InterfaceType.usb
            ])
            guard let manager = manager else {
                return
            }

            manager.delegate = self

            // Set discovery time. (option)
            manager.discoveryTime = 10000
            
            // Start discovery.
            try manager.startDiscovery()
        } catch let error {
            // Error.
            print(error)
        }
    }
    
    func buildPrinter(_ printer : [String:Any]) -> StarPrinter {
        let starConnectionSettings = StarConnectionSettings(interfaceType: InterfaceType.fromString(printer["interface"] as! String),
                                                            identifier: printer["identifier"] as! String)
        
        return StarPrinter(starConnectionSettings)
    }
    
    func _test(_ args: [String:Any]) {
        let printer = buildPrinter(args["printer"] as! [String:Any])

        let builder = StarXpandCommand.StarXpandCommandBuilder()
        _ = builder.addDocument(StarXpandCommand.DocumentBuilder.init()
            .addPrinter(StarXpandCommand.PrinterBuilder()
                .styleInternationalCharacter(.usa)
                .styleCharacterSpace(0)
                .styleAlignment(.center)
                .actionPrintText("Star Clothing Boutique\n" +
                                 "123 Star Road\n" +
                                 "City, State 12345\n" +
                                 "\n")
                .styleAlignment(.left)
                .actionPrintText("Date:MM/DD/YYYY    Time:HH:MM PM\n" +
                                 "--------------------------------\n" +
                                 "\n")
                .add(
                    StarXpandCommand.PrinterBuilder()
                        .styleBold(true)
                        .actionPrintText("SALE \n")
                )
                .actionPrintText("SKU         Description    Total\n" +
                                 "300678566   PLAIN T-SHIRT  10.99\n" +
                                 "300692003   BLACK DENIM    29.99\n" +
                                 "300651148   BLUE DENIM     29.99\n" +
                                 "300642980   STRIPED DRESS  49.99\n" +
                                 "300638471   BLACK BOOTS    35.99\n" +
                                 "\n" +
                                 "Subtotal                  156.95\n" +
                                 "Tax                         0.00\n" +
                                 "--------------------------------\n")
                .actionPrintText("Total     ")
                .add(
                    StarXpandCommand.PrinterBuilder()
                        .styleMagnification(StarXpandCommand.MagnificationParameter(width: 2, height: 2))
                        .actionPrintText("   $156.95\n")
                )
                .actionPrintText("--------------------------------\n" +
                                 "\n" +
                                 "Charge\n" +
                                 "156.95\n" +
                                 "Visa XXXX-XXXX-XXXX-0123\n" +
                                 "\n")
                .add(
                    StarXpandCommand.PrinterBuilder()
                        .styleInvert(true)
                        .actionPrintText("Refunds and Exchanges\n")
                )
                .actionPrintText("Within ")
                .add(
                    StarXpandCommand.PrinterBuilder()
                        .styleUnderLine(true)
                        .actionPrintText("30 days")
                )
                .actionPrintText(" with receipt\n" +
                                 "And tags attached\n" +
                                 "\n")
                .styleAlignment(.center)
                .actionFeedLine(1)
                .actionCut(StarXpandCommand.Printer.CutType.partial)))
        
        let command = builder.getCommands()

        sendCommands(command, to: printer)

    }
    
    func _openDrawer(_ args: [String:Any]) {
        
        
        let printer = buildPrinter(args["printer"] as! [String:Any])
            
        
                    let builder = StarXpandCommand.StarXpandCommandBuilder()
                    _ = builder.addDocument(StarXpandCommand.DocumentBuilder.init()
                        .addDrawer(StarXpandCommand.DrawerBuilder().actionOpen(StarXpandCommand.Drawer.OpenParameter())))
                    

                    // Get printing data from StarXpandCommandBuilder object.
                    let command = builder.getCommands()

        sendCommands(command, to: printer)
    }

    public func sendCommands(_ commands: String, to printer: StarPrinter) {
        Task {
            do {
                // Connect to the printer.
                try await printer.open()
                defer {
                    // Disconnect from the printer.
                    Task {
                        await printer.close()
                    }
                }

                try await printer.print(command: commands)
                print("Success")
            } catch let error {
                // Error.
                print(error)
            }
        }
    }
    
    public func manager(_ manager: StarDeviceDiscoveryManager, didFind printer: StarPrinter) {
        print("managerDidFinishDiscovery")
        print(printer)
        
        foundPrinters.append(printer)
    }
    
    public func managerDidFinishDiscovery(_ manager: StarDeviceDiscoveryManager) {
        print("managerDidFinishDiscovery")
        result!([
            "printers": foundPrinters.map({ p in
                [
                    "model": p.information?.model.description,
                    "identifier": p.connectionSettings.identifier,
                    "interface": p.connectionSettings.interfaceType.stringValue()
                ]
            })
        ])
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
