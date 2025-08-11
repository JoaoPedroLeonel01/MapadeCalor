//
//  ContentView.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 11/08/25.
//

import SwiftUI
import CoreMotion
import HealthKit

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        VStack {
            Text("Dados do acelerometro!")
            
            Text("X: \(motionManager.x, specifier: "%.2f")")
            Text("Y: \(motionManager.y, specifier: "%.2f")")
            Text("Z: \(motionManager.z, specifier: "%.2f")")
            }
                
            }
        }

#Preview {
    ContentView()
}
