//
//  BeaconManager.swift
//  KBeaconSettings
//
//  Created by Chris Gelles
//

import Foundation
import kbeaconlib2
import Combine

class BeaconManager: NSObject, ObservableObject {
    @Published var beacons: [KBeacon] = []
    @Published var isScanning = false
    @Published var connectionState: String = "Not connected"
    
    private var beaconsMgr: KBeaconsMgr?
    private var beaconsDictionary: [String: KBeacon] = [:]
    
    override init() {
        super.init()
        beaconsMgr = KBeaconsMgr.sharedBeaconManager
        beaconsMgr?.delegate = self
    }
    
    func startScanning() {
        // Clear existing beacons
        beacons.removeAll()
        beaconsDictionary.removeAll()
        
        // Start scanning
        let result = beaconsMgr?.startScanning()
        if result == true {
            isScanning = true
            print("Started scanning for beacons")
        } else {
            print("Failed to start scanning")
        }
    }
    
    func stopScanning() {
        beaconsMgr?.stopScanning()
        isScanning = false
        print("Stopped scanning")
    }
    
    func connect(to beacon: KBeacon, password: String, completion: @escaping (Bool, String) -> Void) {
        self.currentCompletion = completion
        beacon.connect(password, timeout: 15.0, delegate: self)
    }
    
    private var currentCompletion: ((Bool, String) -> Void)?
    
    func disconnect(from beacon: KBeacon) {
        beacon.disconnect()
        connectionState = "Disconnected"
    }
}

// MARK: - KBeaconMgrDelegate
extension BeaconManager: KBeaconMgrDelegate {
    func onBeaconDiscovered(beacons: [KBeacon]) {
        for beacon in beacons {
            if let uuidString = beacon.uuidString {
                // Add or update beacon in dictionary
                beaconsDictionary[uuidString] = beacon
            }
        }
        
        // Update published array
        self.beacons = Array(beaconsDictionary.values)
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    func onCentralBleStateChange(newState: BLECentralMgrState) {
        switch newState {
        case .PowerOn:
            print("Bluetooth is powered on")
        case .PowerOff:
            print("Bluetooth is powered off")
        default:
            print("Bluetooth state changed")
        }
    }
}

// MARK: - ConnStateDelegate
extension BeaconManager: ConnStateDelegate {
    func onConnStateChange(_ beacon: KBeacon, state: KBConnState, evt: KBConnEvtReason) {
        DispatchQueue.main.async {
            switch state {
            case .Connected:
                self.connectionState = "Connected"
                self.currentCompletion?(true, "Connected successfully")
                self.currentCompletion = nil
            case .Disconnected:
                self.connectionState = "Disconnected"
                if evt == .ConnAuthFail {
                    self.currentCompletion?(false, "Authentication failed - check password")
                } else {
                    self.currentCompletion?(false, "Connection failed")
                }
                self.currentCompletion = nil
            case .Connecting:
                self.connectionState = "Connecting"
            @unknown default:
                break
            }
        }
    }
}

