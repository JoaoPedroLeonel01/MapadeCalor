//
//  WatchConnectivityManager.swift
//  Testemapa
//
//  Created by Joao pedro Leonel on 14/08/25.
//

import Foundation
import WatchConnectivity
import Combine
import CoreGraphics

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    // Publisher para notificar a UI quando novos dados chegarem
    let workoutDataPublisher = PassthroughSubject<[CGPoint], Never>()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Reativar a sessão se ela for desativada
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
         if let error = error {
            print("iPhone WCSession activation failed with error: \(error.localizedDescription)")
            return
        }
        print("iPhone WCSession activated with state: \(activationState.rawValue)")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("--- IPHONE: FASE DE RECEBIMENTO ---")
        print("Recebido UserInfo do Watch com as chaves: \(userInfo.keys)")

        // Tenta pegar o array de pontos. Espera um dicionário com qualquer tipo de valor [String: Any].
        guard let pathData = userInfo["workoutPath"] as? [[String: Any]] else {
            print("IPHONE ERRO: Chave 'workoutPath' não encontrada ou formato de array inválido.")
            return
        }

        // Converte os dados de forma robusta, aceitando tanto String quanto Número.
        // `compactMap` ignora qualquer ponto que não consiga ser convertido.
        let points: [CGPoint] = pathData.compactMap { dict in
            var xVal: Double?
            var yVal: Double?

            // Tenta converter de String (como visto no seu log)
            if let xStr = dict["x"] as? String, let yStr = dict["y"] as? String {
                xVal = Double(xStr)
                yVal = Double(yStr)
            }
            // Se não for String, tenta converter diretamente de Número (mais genérico)
            else if let xNum = dict["x"] as? NSNumber, let yNum = dict["y"] as? NSNumber {
                xVal = xNum.doubleValue
                yVal = yNum.doubleValue
            }

            // Se a conversão foi bem-sucedida, cria o CGPoint
            if let x = xVal, let y = yVal {
                return CGPoint(x: CGFloat(x), y: CGFloat(y))
            }
            
            // Se a conversão falhar para este ponto específico, ele será descartado.
            return nil
        }

        guard !points.isEmpty else {
            print("IPHONE ERRO: A lista de pontos ficou vazia após a tentativa de conversão.")
            return
        }
        
        print("IPHONE: Dados deserializados com sucesso. \(points.count) pontos.")
        for (index, point) in points.enumerated() {
            print("Ponto \(index + 1): X = \(point.x), Y = \(point.y)")
        }

        // Envia os pontos para quem estiver escutando (ViewModel/View)
        DispatchQueue.main.async {
            self.workoutDataPublisher.send(points)
        }
    }
}
