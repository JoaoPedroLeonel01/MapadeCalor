//
//  ContentView.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 11/08/25.
//

import SwiftUI
import CoreMotion
import HealthKit
import MapKit

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    
    @StateObject var heatmapManager = HeatmapManager()
    @State private var region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    
    var body: some View {
        VStack {
            Text("Dados do acelerometro!")
            
            Text("X: \(motionManager.x, specifier: "%.2f")")
            Text("Y: \(motionManager.y, specifier: "%.2f")")
            Text("Z: \(motionManager.z, specifier: "%.2f")")
            }
        
        //Spacer()
        
        if let lastLocation = heatmapManager.locations.last {
                       // Atualiza a região para o último local capturado
                       Map(coordinateRegion: Binding(
                           get: {
                               MKCoordinateRegion(
                                   center: lastLocation,
                                   span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                               )
                           },
                           set: { newRegion in
                               region = newRegion
                           }
                       ))
                       .edgesIgnoringSafeArea(.all)
                   } else {
                       // Mapa padrão inicial
                       Map(coordinateRegion: $region)
                           .edgesIgnoringSafeArea(.all)
                   }
               }
                
            }
        

#Preview {
    ContentView()
}
