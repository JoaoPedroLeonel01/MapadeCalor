//
//  WatchConnectivityManager.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 14/08/25.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
            return
        }
        print("Watch WCSession activated with state: \(activationState.rawValue)")
    }

    // Função principal para enviar os dados do treino
    func sendWorkoutData(_ data: [String: Any]) {
        // Trava de sefunrança ( nao deixa enviar os dados antes de ter começado a sessão)
        guard WCSession.default.activationState == .activated else{
            print("tranferencia cancelada, tentativa de envio antes da sessao estar ativa")
            return
        }
        // transferUserInfo é a melhor opção para dados importantes, pois enfileira e garante a entrega.

        WCSession.default.transferUserInfo(data)
    }
}
