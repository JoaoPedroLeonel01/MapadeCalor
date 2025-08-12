//
//  LocationManager.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 12/08/25.
//

import SwiftUI
import CoreLocation
import CoreMotion
import MapKit

class HeatmapManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locations: [CLLocationCoordinate2D] = [] // Guarda as coordenadas
    private var locationManager = CLLocationManager()
    private var motionManager = CMMotionManager()
    
    override init() {
        super.init()
        
        // Configura GPS
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization() // Pede permissão
        locationManager.startUpdatingLocation() // Começa a capturar localizações
        
        // Configura acelerômetro e giroscópio
        if motionManager.isAccelerometerAvailable && motionManager.isGyroAvailable {
            motionManager.accelerometerUpdateInterval = 0.5 // Coleta a cada 0.5s
            motionManager.startAccelerometerUpdates()
            
            motionManager.startGyroUpdates()
        }
    }
    
    // Quando a localização muda
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        
        // Aqui poderíamos usar dados do acelerômetro para calcular intensidade
        if let accelData = motionManager.accelerometerData {
            let intensidade = abs(accelData.acceleration.x) +
                              abs(accelData.acceleration.y) +
                              abs(accelData.acceleration.z)
            
            // Só salva se o movimento for significativo
            if intensidade > 0.1 {
                self.locations.append(coord)
            }
        }
    }
}



