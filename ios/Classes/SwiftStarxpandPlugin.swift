import Flutter
import UIKit
import StarIO10

public class SwiftStarxpandPlugin: NSObject, FlutterPlugin, StarDeviceDiscoveryManagerDelegate {
    var manager: StarDeviceDiscoveryManager? = nil
    var result: FlutterResult? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "starxpand", binaryMessenger: registrar.messenger())
        let instance = SwiftStarxpandPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
            case "find": _find()
            default:
                _find()
        }
    }
    
    func _find() {
        do {
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
    
    public func manager(_ manager: StarDeviceDiscoveryManager, didFind printer: StarPrinter) {
        print("managerDidFinishDiscovery")
        print(printer)
    }
    
    public func managerDidFinishDiscovery(_ manager: StarDeviceDiscoveryManager) {
        print("managerDidFinishDiscovery")
    }
}
