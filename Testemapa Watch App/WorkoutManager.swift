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

// Classe para gerenciar a sessão de treino e a captura de movimento de alta frequência
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
    @Published var path: [CGPoint] = [] // Histórico de posições
    
    private var referenceHeading: Double? // Ângulo de calibração inicial
    
    // Constantes e Estado para Detecção de Passo
    private let STEP_THRESHOLD_HIGH: Double = 0.35   // entra passo
    private let STEP_THRESHOLD_LOW: Double  = 0.15   // sai do passo
    private let STEP_LENGTH: Double = 0.80           // mantenha/ajuste depois
    private var isStepInProgress = false    // Trava para evitar detecção múltipla

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
    func startWorkout(referenceHeading: Double) {
        // Zera o estado anterior e armazena a referência
        self.referenceHeading = referenceHeading
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
        
        
        // Inicia a captura de movimento de alta frequência
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
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50Hz
        let queue = OperationQueue()
        
        motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: queue) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Processa os dados de movimento em uma função separada
            self.processDeviceMotion(motion)
        }
    }
    
    // Para a captura do CoreMotion
    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    // O ALGORITMO PRINCIPAL (PDR)
    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
        
        // Detecção de Passo (Algoritmo de Pico)
        if magnitude > STEP_THRESHOLD_HIGH && !isStepInProgress {
            isStepInProgress = true // Trava o passo
            
            // Cálculo da Posição
            guard let refHeading = self.referenceHeading else { return }
            
            let yawInRadians = motion.attitude.yaw // Direção atual em relação ao norte verdadeiro
            let currentHeading = yawInRadians.toDegrees()
            
            // Ajusta a direção com base na calibração
            let relativeDirection = currentHeading - refHeading
            
            // Calcula o deslocamento e atualiza a posição
            let deltaX = STEP_LENGTH * sin(relativeDirection.toRadians())
            let deltaY = STEP_LENGTH * cos(relativeDirection.toRadians())
            
            DispatchQueue.main.async {
                self.currentPosition.x += deltaX
                self.currentPosition.y += deltaY
                self.path.append(self.currentPosition)
            }
        } else if magnitude < STEP_THRESHOLD_LOW { // Limiar inferior para "resetar" a trava do passo
            isStepInProgress = false
        }
    }
    
    // HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.workoutState = toState
        }
        
        if toState == .running {
            builder?.beginCollection(withStart: date) { success, error in
                if !success {
                    print("Erro ao iniciar a coleção de dados do treino: \(String(describing: error))")
                }else{
                    print( " coleção de dados iniciada.")
                }
            }
        }
        
        if toState == .ended {
            builder?.endCollection(withEnd: date) { success, error in
                self.builder?.finishWorkout { workout, error in
                    // O treino está finalizado e salvo no HealthKit
                    // O array `self.path` contém todas as coordenadas.
                    print("Treino finalizado. Pontos de mapa de calor coletados: \(self.path.count)")
                    
                    guard !self.path.isEmpty else {
                        print("ERRO: array 'path' está vazio. Nenhum passo foi detectado.")
                        return
                    }
                    
                    print("Dados a serem enviados: \(self.path.count) pontos.")
                    
                    let serializablePath = self.path.map{ ["x": $0.x, "y": $0.y]}
                    let workoutData: [String: Any] = [
                        "workoutPath": serializablePath,
                        "workoutEndData": Date()
                    ]
                    
                    WatchConnectivityManager.shared.sendWorkoutData(workoutData)
                }
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Sessão de treino falhou com erro: \(error)")
    }
}
