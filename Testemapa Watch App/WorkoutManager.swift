//
//  WorkoutManager.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 13/08/25.
//  Versão corrigida e otimizada
//

import Combine
import CoreGraphics
import CoreMotion
import Foundation
import HealthKit

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate {

    // MARK: - Módulos Principais
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()

    // MARK: - Estado do Treino
    private var session: HKWorkoutSession?
    private var builder: HKWorkoutBuilder?
    @Published var workoutState: HKWorkoutSessionState = .notStarted

    // MARK: - Dados de Posição (PDR)
    @Published var currentPosition: CGPoint = .zero
    @Published var path: [CGPoint] = []

    // MARK: - Referências de Cálculo
    private var courtHeadingRad: Double?
    private var lastDistance: Double = 0.0 // Guarda a última distância medida para calcular o delta

    // MARK: - Ciclo de Vida do Treino

    func requestAuthorization() {
        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("Erro ao autorizar HealthKit: \(String(describing: error))")
            }
        }
    }

    func startWorkout(referenceHeading: Double) {
        // 1. Reseta o estado para um novo treino
        self.courtHeadingRad = referenceHeading.toRadians()
        self.currentPosition = .zero
        self.path = [.zero]
        self.lastDistance = 0.0

        // 2. Configura a sessão do HealthKit
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .volleyball
        configuration.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            print("Erro ao criar a sessão de treino: \(error)")
            return
        }

        session?.delegate = self
        session?.startActivity(with: Date())

        // 3. Inicia a coleta de dados de movimento
        startPedometerUpdates()
        startDirectionUpdates()
    }

    func stopWorkout() {
        pedometer.stopUpdates() // Use a chamada correta para parar
        motionManager.stopDeviceMotionUpdates()
        session?.end()
    }

    // MARK: - Coleta de Dados de Movimento

    private func startDirectionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        // 10Hz é uma boa frequência para capturar a direção sem gastar muita bateria
        motionManager.deviceMotionUpdateInterval = 1.0 / 10.0
        motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical)
    }

    private func startPedometerUpdates() {
        guard CMPedometer.isDistanceAvailable() else {
            print("Pedômetro não disponível.")
            return
        }

        pedometer.startUpdates(from: Date()) { [weak self] pedometerData, error in
            guard let self = self, let data = pedometerData, error == nil else { return }

            // Garante que temos a direção mais recente do motionManager
            guard let deviceMotion = self.motionManager.deviceMotion,
                  let courtHeading = self.courtHeadingRad
            else { return }

            // --- LÓGICA CORRIGIDA ---

            // 1. Calcula a distância percorrida APENAS neste update (o delta)
            let newDistance = data.distance?.doubleValue ?? 0
            let deltaDistance = newDistance - self.lastDistance
            self.lastDistance = newDistance // Atualiza para o próximo cálculo

            // 2. Pega a direção atual e a alinha com a bússola da quadra
            let currentYaw = deviceMotion.attitude.yaw // Direção do corpo
            let finalAngle = currentYaw + courtHeading  // Direção na quadra

            // 3. Calcula o deslocamento (deltaX, deltaY) usando o delta da distância
            let deltaX = deltaDistance * sin(finalAngle)
            let deltaY = deltaDistance * cos(finalAngle)

            // 4. Adiciona o deslocamento à posição atual
            DispatchQueue.main.async {
                self.currentPosition.x += deltaX
                self.currentPosition.y += deltaY
                self.path.append(self.currentPosition)

                // Opcional: print para depuração
                 print(String(format: "ΔDist: %.2fm | Pos(%.2f, %.2f)",
                              deltaDistance, self.currentPosition.x, self.currentPosition.y))
            }
        }
    }

    // MARK: - HKWorkoutSessionDelegate
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.workoutState = toState
        }

        if toState == .running {
            builder?.beginCollection(withStart: date) { _,_ in }
        }

        if toState == .ended {
            builder?.endCollection(withEnd: date) { _, _ in
                self.builder?.finishWorkout { _, _ in
                    print("Treino finalizado. Pontos coletados: \(self.path.count)")
                    guard !self.path.isEmpty else { return }

                    let serializablePath = self.path.map { ["x": $0.x, "y": $0.y] }
                    let workoutData: [String: Any] = ["workoutPath": serializablePath]
                    
                    WatchConnectivityManager.shared.sendWorkoutData(workoutData)
                    print("Dados enviados ao iPhone: \(self.path.count) pontos.")
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Sessão de treino falhou com erro: \(error)")
    }
}

