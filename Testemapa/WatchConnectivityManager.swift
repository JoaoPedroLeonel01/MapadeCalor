//
//  WatchConnectivityManager.swift
//  Testemapa
//
//  Created by Joao pedro Leonel on 14/08/25.
//

import Foundation
import WatchConnectivity
import CoreGraphics
import Combine

// Singleton responsável por comunicação com o Apple Watch via WCSession.
// Recebe pontos enviados pelo Watch e publica via Combine.
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    
    static let shared = WatchConnectivityManager() // Acesso global
    
    // Publisher que envia a lista de pontos (para Views assinarem)
    private let subject = PassthroughSubject<[CGPoint], Never>()
    var workoutDataPublisher: AnyPublisher<[CGPoint], Never> {
        subject.eraseToAnyPublisher()
    }

    // Inicialização: ativa a sessão com o Watch
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // ===== Métodos obrigatórios do protocolo WCSessionDelegate =====
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate() // Reativa ao trocar de Watch
    }
    #endif

    // Recebe dados enviados pelo Watch.
    // Espera um dicionário com chave "workoutPath" contendo lista de {x, y}.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let raw = userInfo["workoutPath"] as? [Any] else { return }

        var points: [CGPoint] = []
        points.reserveCapacity(raw.count)

        // Converte cada item do array em CGPoint
        for item in raw {
            if let dict = item as? [String: Any] {
                let xVal = dict["x"]
                let yVal = dict["y"]

                /// Helper: converte qualquer coisa em CGFloat
                func toCGFloat(_ v: Any?) -> CGFloat? {
                    switch v {
                    case let n as NSNumber: return CGFloat(truncating: n)
                    case let s as String:   return CGFloat(Double(s) ?? .nan)
                    default:                return nil
                    }
                }

                if let x = toCGFloat(xVal), let y = toCGFloat(yVal), x.isFinite, y.isFinite {
                    points.append(CGPoint(x: x, y: y))
                }
            }
        }

        // Publica pontos na main thread (UI segura)
        DispatchQueue.main.async { [subject] in
            subject.send(points)
        }
    }
}
