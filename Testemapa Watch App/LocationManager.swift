//
//  LocationManager.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 12/08/25.
//

import Foundation
import CoreLocation // Framework principal para localização
import Combine     // Para ObservableObject

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    // @Published notifica a View quando a localização for atualizada.
    @Published var location: CLLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus

    override init() {
        // Inicializa o status de autorização
        self.authorizationStatus = locationManager.authorizationStatus
        super.init() // Chama o init da classe pai (NSObject)

        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest // Máxima precisão. Cuidado com a bateria.
        self.locationManager.requestWhenInUseAuthorization() // Solicita a permissão.
    }

    // Esta função é chamada automaticamente quando o status da permissão muda.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus

        // Se a permissão for concedida, comece a buscar a localização.
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // Esta função é chamada automaticamente sempre que uma nova localização é recebida.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // locations é um array, a localização mais recente é geralmente a última.
        guard let latestLocation = locations.last else { return }

        // Atualiza a nossa propriedade publicada na thread principal.
        DispatchQueue.main.async {
            self.location = latestLocation
        }
    }

    // Função para tratar erros.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Erro ao obter localização: \(error.localizedDescription)")
    }

    // Função para parar as atualizações e economizar bateria.
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
    
    
}
