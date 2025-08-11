//
//  MotionManager.swift
//  Testemapa Watch App
//
//  Created by Joao pedro Leonel on 11/08/25.
//

import Foundation
import CoreMotion
import Combine // É necessário para criar um ObservableObject ( notifica o usuário sobre mudanças na propriedade)

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    //@Published notifica a sua View sempre que esses valores mudarem
    @Published var x: Double = 0.0  //Eixo x
    @Published var y: Double = 0.0  //Eixo y
    @Published var z: Double = 0.0  //Eixo z
    
    init(){
        motionManager.accelerometerUpdateInterval = 0.1
        startAccelerometerUpdates()
    }
    
    private func startAccelerometerUpdates(){
        //Verifica se o acelerômetro está disponivel
        
        if motionManager.isAccelerometerAvailable{
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                //Garante que a atualização da UI ocorra na thread principal.
                //[ weak self] evita cilcos de retenção de memória.
                guard let data = data, error == nil else{
                    //Caso seja necessario trate o erro aqui!
                        return
                }
                
                self?.x = data.acceleration.x
                self?.y = data.acceleration.y
                self?.z = data.acceleration.z
            }
        }
    }
    
}
