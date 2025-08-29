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
    private var latestYaw: Double = 0.0    // Guarda o yaw mais recente de forma confiável

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
        self.latestYaw = 0.0

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
        pedometer.stopUpdates()
        motionManager.stopDeviceMotionUpdates()
        session?.end()
    }

    // MARK: - Coleta de Dados de Movimento

    private func startDirectionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0 // Frequência boa para dados frescos

        // Usa um handler para atualizar a propriedade de forma confiável, evitando race conditions
        motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            self.latestYaw = motion.attitude.yaw
        }
    }

    private func startPedometerUpdates() {
        guard CMPedometer.isDistanceAvailable() else {
            print("Pedômetro não disponível.")
            return
        }

        pedometer.startUpdates(from: Date()) { [weak self] pedometerData, error in
            guard let self = self, let data = pedometerData, error == nil else { return }
            
            // Agora só precisamos da referência da quadra, pois o yaw já está salvo
            guard let courtHeading = self.courtHeadingRad else { return }

            // --- LÓGICA REVISADA E CORRIGIDA ---

            // 1. Calcula a distância percorrida APENAS neste update (o delta)
            let newDistance = data.distance?.doubleValue ?? 0
            let deltaDistance = newDistance - self.lastDistance
            
            // IMPORTANTE: Ignora updates sem movimento real para evitar ruído
            guard deltaDistance > 0.1 else { return } // Ignora se o movimento for menor que 10cm
            
            self.lastDistance = newDistance // Atualiza para o próximo cálculo

            // 2. Pega a direção do corpo (da nossa propriedade) e calcula o ângulo relativo à quadra
            let currentYaw = self.latestYaw
            let finalAngle = currentYaw - courtHeading // CORREÇÃO: Subtração

            // 3. Calcula o deslocamento, corrigindo o eixo X para não ficar espelhado
            let deltaX = -deltaDistance * sin(finalAngle)
            let deltaY = deltaDistance * cos(finalAngle)

            // 4. Adiciona o deslocamento à posição atual
            DispatchQueue.main.async {
                self.currentPosition.x += deltaX
                self.currentPosition.y += deltaY
                self.path.append(self.currentPosition)

                // Print de depuração ativado para análise no console do Xcode
                print(String(format: "ΔDist: %.2fm | Yaw: %.2f | Angle: %.2f | ΔPos(%.2f, %.2f) | NewPos(%.2f, %.2f)",
                             deltaDistance,
                             currentYaw,
                             finalAngle,
                             deltaX,
                             deltaY,
                             self.currentPosition.x,
                             self.currentPosition.y))
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

