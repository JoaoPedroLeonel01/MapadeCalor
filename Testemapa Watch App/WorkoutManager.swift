//
//  WorkoutManager.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 13/08/25.
//

import Foundation
import HealthKit
import CoreMotion
import Combine
import CoreGraphics

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate {
    
    // Módulos Principais
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    
    // Estado do Treino
    private var session: HKWorkoutSession?
    private var builder: HKWorkoutBuilder?
    @Published var workoutState: HKWorkoutSessionState = .notStarted
    
    // Dados de Posição (PDR)
    @Published var currentPosition: CGPoint = .zero
    @Published var path: [CGPoint] = []
    
    // Referência unificada: YAW do CoreMotion (em radianos)
    private var refYawRad: Double?
    
    // Constantes de detecção de passo (ajuste fino conforme necessário)
    private let STEP_THRESHOLD_HIGH: Double = 0.20
    private let STEP_THRESHOLD_LOW:  Double = 0.12
    private let ROTATION_LIMIT:      Double = 1.0   // rad/s para ignorar giro de punho
    private let STEP_LENGTH:         Double = 0.75  // metros por passo (aprox.)
    private var isStepInProgress = false
    
    // Pedir autorização para o HealthKit
    func requestAuthorization() {
        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("Erro ao autorizar HealthKit: \(String(describing: error))")
            }
        }
    }
    
    // Iniciar o treino
    // Mantemos a assinatura original, mas ignoramos referenceHeading para evitar mismatch com CLHeading.
    func startWorkout(referenceHeading: Double) {
        self.refYawRad = nil // será definido no primeiro sample do CoreMotion
        self.currentPosition = .zero
        self.path = [.zero]
        
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
        
        let startDate = Date()
        session?.startActivity(with: startDate)
        
        startMotionUpdates()
    }
    
    // Parar o treino
    func stopWorkout() {
        stopMotionUpdates()
        session?.end()
    }
    
    // Iniciar captura do CoreMotion
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion não está disponível")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.5 / 50.0 // 50Hz
        let queue = OperationQueue()
        
        motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: queue) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Define a referência de yaw (em radianos) no primeiro sample
            if self.refYawRad == nil {
                self.refYawRad = motion.attitude.yaw
                print(String(format: "Ref yaw definida: %.3f rad", self.refYawRad ?? 0))
            }
            self.processDeviceMotion(motion)
        }
    }
    
    // Para a captura do CoreMotion
    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    // Algoritmo principal
    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        let forwardAccel = motion.userAcceleration.y // eixo Y = frente/trás do braço
        let rotation = motion.rotationRate           // velocidade angular (giroscópio)
        
        // Filtro: ignora se giro de punho for muito alto
        let isRotatingWrist = abs(rotation.x) > ROTATION_LIMIT ||
                              abs(rotation.y) > ROTATION_LIMIT ||
                              abs(rotation.z) > ROTATION_LIMIT
        
        if forwardAccel > STEP_THRESHOLD_HIGH && !isStepInProgress && !isRotatingWrist {
            isStepInProgress = true
            
            guard let refYaw = self.refYawRad else { return }
            let yaw = motion.attitude.yaw // radianos
            var rel = yaw - refYaw        // radianos
            
            // Normaliza para [-π, π]
            while rel > .pi { rel -= 2 * .pi }
            while rel < -.pi { rel += 2 * .pi }
            
            // Direção do deslocamento (Opção A – mais comum para .xTrueNorthZVertical) =====
            // Se parecer rotacionado 90° ou espelhado, veja as opções comentadas abaixo.
            let deltaX = STEP_LENGTH * cos(rel)
            let deltaY = STEP_LENGTH * -sin(rel)
            
            DispatchQueue.main.async {
                self.currentPosition.x += deltaX
                self.currentPosition.y += deltaY
                self.path.append(self.currentPosition)
                print(String(format: "STEP ok | relYaw: %.3f rad | Δ(%.2f, %.2f) | pos(%.2f, %.2f) | count=%d",
                             rel, deltaX, deltaY, self.currentPosition.x, self.currentPosition.y, self.path.count))
            }
        } else if forwardAccel < STEP_THRESHOLD_LOW {
            isStepInProgress = false
        }
    }
    
    /*
     ===== Caso a direção ainda pareça errada, teste rapidamente: =====
     
     // Opção B (troca e espelho em Y):
     let deltaX = STEP_LENGTH * sin(rel)
     let deltaY = STEP_LENGTH *  cos(rel)
     
     // Opção C (troca + sinal diferente):
     let deltaX = STEP_LENGTH *  sin(rel)
     let deltaY = STEP_LENGTH * -cos(rel)
    */
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.workoutState = toState
        }
        
        if toState == .running {
            builder?.beginCollection(withStart: date) { success, error in
                if !success {
                    print("Erro ao iniciar a coleção de dados do treino: \(String(describing: error))")
                } else {
                    print("Coleção de dados iniciada.")
                }
            }
        }
        
        if toState == .ended {
            builder?.endCollection(withEnd: date) { success, error in
                self.builder?.finishWorkout { workout, error in
                    print("Treino finalizado. Pontos de mapa de calor coletados: \(self.path.count)")
                    
                    guard !self.path.isEmpty else {
                        print("ERRO: array 'path' está vazio.")
                        return
                    }
                    
                    let serializablePath = self.path.map { ["x": $0.x, "y": $0.y] }
                    let workoutData: [String: Any] = [
                        "workoutPath": serializablePath,
                        "workoutEndData": Date()
                    ]
                    
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
