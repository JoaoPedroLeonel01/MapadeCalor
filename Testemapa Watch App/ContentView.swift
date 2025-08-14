//
//  ContentView.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 11/08/25.
//

import SwiftUI
import CoreMotion
import HealthKit
import CoreLocation

struct ContentView: View {
    // Gerenciador de calibração inicial via GPS/Bússola
    @StateObject private var calibrationManager = MotionManager()
    // Gerenciador do treino e do PDR via CoreMotion/HealthKit
    @StateObject private var workoutManager = WorkoutManager()
    
    // Garante que o WCSession (contato com o iphone basicamente) comece a ativar assim que o app for lançado
    private let connectivityManager = WatchConnectivityManager.shared
    
    @State private var mostrarAvisoCalibracao = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                
                // O estado do treino determina quais botões são mostrados.
                if workoutManager.workoutState == .running {
                    
                    Button("Parar Treino") {
                        workoutManager.stopWorkout()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                } else {
                    // Antes do treino começar, mostra Calibrar ou Iniciar.
                    if calibrationManager.referenceHeading == nil {
                        //Se não calibrado, mostra o botão de calibrar.
                        Button("Calibrar") {
                            self.mostrarAvisoCalibracao = true
                        }
                        .alert(isPresented: $mostrarAvisoCalibracao) {
                            Alert(
                                title: Text("Instrução"),
                                message: Text("Fique no centro da quadra, de frente para a rede, e toque em CALIBRAR."),
                                dismissButton: .default(Text("Calibrar")) {
                                    calibrationManager.setOriginAndReference()
                                }
                            )
                        }
                    } else {
                        // Se JÁ calibrado, mostra o botão de iniciar treino.
                        Button("Iniciar Treino") {
                            // O guard let aqui é uma segurança extra so deixa iniciar o treino caso realmnete ja tenha os dados do calibrador
                            guard let refHeading = calibrationManager.referenceHeading?.trueHeading else { return }
                            workoutManager.startWorkout(referenceHeading: refHeading)
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                // --- SEÇÃO DE STATUS EM TEMPO REAL ---
                // Mostra o status de calibragem se o valor existir
                if let reference = calibrationManager.referenceHeading {
                    Text("Calibrado: \(String(format: "%.1f", reference.trueHeading))°")
                        .font(.footnote)
                        .foregroundColor(.green)
                }
                
                // Mostra os dados do treino se ele estiver rodando
                if workoutManager.workoutState == .running {
                    Text("Posição (X,Y): \(String(format: "%.2f", workoutManager.currentPosition.x))m, \(String(format: "%.2f", workoutManager.currentPosition.y))m")
                    Text("Passos Detectados: \(workoutManager.path.count - 1)")
                }
            }
            .onAppear {
                // Inicia as atualizações de AMBOS os managers.
                // O calibrationManager precisa ser iniciado para receber dados da bússola.
                //self.calibrationManager.startUpdates()
                self.workoutManager.requestAuthorization()
            }
        }
    }
}

#Preview {
    ContentView()
}
