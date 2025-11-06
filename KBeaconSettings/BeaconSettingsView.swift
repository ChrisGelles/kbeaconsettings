//
//  BeaconSettingsView.swift
//  KBeaconSettings
//
//  Settings view for configuring beacon parameters
//

import SwiftUI
import kbeaconlib2

struct BeaconSettingsView: View {
    let beacon: KBeacon
    @ObservedObject var beaconManager: BeaconManager
    
    @State private var password: String = ""
    @State private var isConnected = false
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    // Settings
    @State private var selectedTxPower: Int = 0
    @State private var broadcastInterval: String = ""
    @State private var currentSettings: String = "Not loaded"
    
    @Environment(\.presentationMode) var presentationMode
    
    let txPowerLevels = [-40, -20, -16, -12, -8, -4, 0, 3, 4]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Beacon Info")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(beacon.name ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("MAC Address")
                        Spacer()
                        Text(beacon.mac ?? "N/A")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("RSSI")
                        Spacer()
                        Text("\(beacon.rssi) dBm")
                            .foregroundColor(.secondary)
                    }
                }
                
                if !isConnected {
                    Section(header: Text("Authentication")) {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .autocapitalization(.none)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: connectToBeacon) {
                            if isConnecting {
                                HStack {
                                    ProgressView()
                                    Text("Connecting...")
                                }
                            } else {
                                Text("Connect")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isConnecting || password.isEmpty)
                    }
                } else {
                    Section(header: Text("Current Settings")) {
                        Text(currentSettings)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("TX Power")) {
                        Picker("TX Power Level", selection: $selectedTxPower) {
                            ForEach(txPowerLevels.indices, id: \.self) { index in
                                Text("\(txPowerLevels[index]) dBm").tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Text("Higher values increase range but use more battery")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("Broadcast Interval")) {
                        TextField("Milliseconds", text: $broadcastInterval)
                            .keyboardType(.numberPad)
                        
                        Text("Recommended: 100-10000 ms. Lower values drain battery faster.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section {
                        Button(action: applySettings) {
                            Text("Apply Settings")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color.blue)
                        .disabled(broadcastInterval.isEmpty)
                        
                        Button(action: disconnectBeacon) {
                            Text("Disconnect")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Beacon Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        if isConnected {
                            disconnectBeacon()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    func connectToBeacon() {
        isConnecting = true
        errorMessage = nil
        
        beaconManager.connect(to: beacon, password: password) { success, message in
            isConnecting = false
            
            if success {
                isConnected = true
                loadCurrentSettings()
            } else {
                errorMessage = message
            }
        }
    }
    
    func disconnectBeacon() {
        beaconManager.disconnect(from: beacon)
        isConnected = false
    }
    
    func loadCurrentSettings() {
        guard let commonCfg = beacon.getCommonCfg() else {
            currentSettings = "Failed to load settings"
            return
        }
        
        // Get current TX Power and broadcast interval from first slot
        var currentTxPower: Int = 0
        if let slotCfg = beacon.getSlotCfg(0) as? KBCfgAdvBase {
            currentTxPower = Int(slotCfg.getTxPower())
            if let index = txPowerLevels.firstIndex(of: currentTxPower) {
                selectedTxPower = index
            }
            
            let interval = slotCfg.getAdvPeriod()
            broadcastInterval = String(format: "%.0f", interval)
        }
        
        currentSettings = """
        Model: \(commonCfg.getModel() ?? "Unknown")
        Version: \(commonCfg.getVersion() ?? "Unknown")
        TX Power: \(currentTxPower) dBm
        Battery: \(commonCfg.getBatteryPercent())%
        """
    }
    
    func applySettings() {
        guard let interval = Float(broadcastInterval), interval >= 100, interval <= 10000 else {
            errorMessage = "Invalid interval. Must be between 100-10000 ms"
            return
        }
        
        // Update TX Power and broadcast interval for slot 0
        guard let slotCfg = beacon.getSlotCfg(0) as? KBCfgAdvBase else {
            errorMessage = "Failed to get slot configuration"
            return
        }
        
        // Set new values
        slotCfg.setTxPower(txPowerLevels[selectedTxPower])
        slotCfg.setAdvPeriod(interval)
        
        // Apply changes
        beacon.modifyConfig(obj: slotCfg) { (success, exception) in
            DispatchQueue.main.async {
                if success {
                    self.errorMessage = nil
                    self.loadCurrentSettings()
                    
                    // Show success feedback
                    let alert = UIAlertController(
                        title: "Success",
                        message: "Settings updated successfully",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(alert, animated: true)
                    }
                } else {
                    if let error = exception {
                        self.errorMessage = "Config failed: \(error.errorCode)"
                    } else {
                        self.errorMessage = "Failed to update settings"
                    }
                }
            }
        }
    }
}

