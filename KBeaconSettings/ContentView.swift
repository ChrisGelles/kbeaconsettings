//
//  ContentView.swift
//  KBeaconSettings
//
//  Scanner view for discovering KBeacons
//

import SwiftUI
import kbeaconlib2

struct ContentView: View {
    @StateObject private var beaconManager = BeaconManager()
    @State private var selectedBeacon: KBeacon?
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                if beaconManager.beacons.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No beacons found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if beaconManager.isScanning {
                            ProgressView()
                                .padding(.top, 10)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else {
                    List(beaconManager.beacons, id: \.uuidString) { beacon in
                        BeaconRow(beacon: beacon)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedBeacon = beacon
                                showingSettings = true
                            }
                    }
                }
            }
            .navigationTitle("KBeacon Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if beaconManager.isScanning {
                            beaconManager.stopScanning()
                        } else {
                            beaconManager.startScanning()
                        }
                    }) {
                        Image(systemName: beaconManager.isScanning ? "stop.circle" : "play.circle")
                        Text(beaconManager.isScanning ? "Stop" : "Scan")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                if let beacon = selectedBeacon {
                    BeaconSettingsView(beacon: beacon, beaconManager: beaconManager)
                }
            }
        }
    }
}

struct BeaconRow: View {
    let beacon: KBeacon
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(beacon.name ?? "Unknown Beacon")
                    .font(.headline)
                Text(beacon.mac ?? beacon.uuidString ?? "No ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(beacon.rssi) dBm")
                    .font(.caption)
                    .foregroundColor(rssiColor(beacon.rssi))
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundColor(rssiColor(beacon.rssi))
            }
        }
        .padding(.vertical, 4)
    }
    
    func rssiColor(_ rssi: Int8) -> Color {
        if rssi > -60 {
            return .green
        } else if rssi > -75 {
            return .orange
        } else {
            return .red
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

