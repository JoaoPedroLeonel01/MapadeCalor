//
//  MotionManager.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 11/08/25.
//

import Foundation
import CoreLocation
import Combine
import CoreGraphics

class MotionManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()

    @Published var originLocation: CLLocation?
    @Published var referenceHeading: CLHeading?
    @Published var currentLocation: CLLocation?
    @Published var currentHeading: CLHeading?

    @Published var relativePosition: CGPoint? // (x,y) em metros
    @Published var relativeAngle: Double?    // Ângulo em relação ao Norte da quadra

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.requestWhenInUseAuthorization()
    }

    func startUpdates() { // Inicia as atualizações de localização e bússola.
        self.locationManager.startUpdatingLocation()
        self.locationManager.startUpdatingHeading()
    }
    
    func stopUpdates() { // Para as atualizações para economizar bateria.
        self.locationManager.stopUpdatingLocation()
        self.locationManager.stopUpdatingHeading()
    }

    func setOriginAndReference() {
        guard let location = self.currentLocation, let heading = self.currentHeading else {
            print("Aviso: Localização ou Bússola ainda não disponiveis. Tente novamente em alguns segundos.")
            return
        }
        self.originLocation = location
        self.referenceHeading = heading
        print("Origem definida em: \(location.coordinate). Orientação de referência: \(heading.trueHeading)°")
    }
    
    // Chamado quando uma nova localização é recebida.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        self.currentLocation = latestLocation
        updateRelativeValues()
    }

    // Chamado quando uma nova orientação da bússola é recebida.
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.currentHeading = newHeading
        updateRelativeValues()
    }
    
    // Trata erros
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Erro no LocationManager: \(error.localizedDescription)")
    }
    
    // Chamado quando o status de autorização muda.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permissão concedida. Agora podemos iniciar as atualizações.
            print("Permissão concedida. Iniciando atualizações.")
            startUpdates()
        case .notDetermined:
            // O usuário ainda não escolheu.
            print("Permissão ainda não determinada.")
        case .denied, .restricted:
            // O usuário negou a permissão.
            print("Acesso à localização negado.")
        @unknown default:
            fatalError()
        }
    }
    
    // calculos
    private func updateRelativeValues() {
        guard let origin = originLocation,
              let reference = referenceHeading,
              let currentLoc = currentLocation,
              let currentHead = currentHeading else {
            return
        }
        
        // calcular a posição relativa (x, y)
        let distance = currentLoc.distance(from: origin) // Distância em metros
        let bearing = calculateBearing(from: origin.coordinate, to: currentLoc.coordinate) // Ângulo de A para B
        
        // Ajusta o bearing com base na orientação de referência inicial
        let relativeBearing = bearing - reference.trueHeading
        
        // Converte coordenadas polares (distância, ângulo) para cartesianas (x, y)
        let x = distance * sin(relativeBearing.toRadians())
        let y = distance * cos(relativeBearing.toRadians())
        self.relativePosition = CGPoint(x: x, y: y)

        // Calcular o ângulo relativo
        var angleDifference = currentHead.trueHeading - reference.trueHeading
        // Normaliza o ângulo para ficar entre 0 e 360
        if angleDifference < 0 {
            angleDifference += 360
        }
        self.relativeAngle = angleDifference
    }
    
    // Calcula o ângulo (bearing) em graus do ponto A para o ponto B.
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.toRadians()
        let lon1 = from.longitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let lon2 = to.longitude.toRadians()
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansBearing.toDegrees()
    }
}

//  conversão de graus/radianos
extension Double {
    func toRadians() -> Double { self * .pi / 180 }
    func toDegrees() -> Double { self * 180 / .pi }
}
