//
//  HeatmapView.swift
//  Testemapa
//
//  Created by Joao pedro Leonel on 14/08/25.
//

import SwiftUI
import Combine

struct HeatmapView: View {
    let gridData: [[Int]]
    let maxValue: Int
    
    private let gradientColors: [Color] = [.blue, .green, .yellow, .red]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(0..<gridData.count, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<gridData[row].count, id: \.self) { col in
                            Rectangle()
                                .fill(color(forValue: gridData[row][col]))
                                .frame(width: geometry.size.width / CGFloat(gridData[row].count),
                                       height: geometry.size.height / CGFloat(gridData.count))
                        }
                    }
                }
            }
        }
        .opacity(0.7)
    }
    
    // Lógica de coloração
    private func color(forValue value: Int) -> Color {
        // Primeiro, trata o caso de não haver calor. Retorna transparente.
        guard value > 0, maxValue > 0 else {
            return .clear
        }
        
        // para qualquer valor > 0, calcula a cor com base na escala visível.
        let intensity = Double(value) / Double(maxValue)
        
        // O índice é calculado com base na contagem da nova lista `gradientColors`.
        // (count - 1) para o cálculo, mas garantimos que o índice não seja negativo.
        let colorIndex = max(0, Int((intensity * Double(gradientColors.count - 1)).rounded(.toNearestOrAwayFromZero)))
        
        // Retorna a cor do gradiente, garantindo que o índice não ultrapasse o limite.
        return gradientColors[min(gradientColors.count - 1, colorIndex)]
    }
}

struct HeatmapResultView: View {
    @State private var latestPoints: [CGPoint] = [] // <- pontos crus
    @State private var cancellables = Set<AnyCancellable>()
    private let courtImage = "quadra-futevolei"
    
    var body: some View {
        VStack {
            Text("Mapa de Calor do Treino").font(.title)
            ZStack {
                Image(courtImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                GeometryReader { geo in
                    let minCell: CGFloat = 12    // célula mínima (px)
                    let rows = max(8, Int(geo.size.height / minCell))
                    let cols = max(8, Int(geo.size.width  / minCell))
                    
                    if !latestPoints.isEmpty {
                        let result = HeatmapProcessor.process(
                            points: latestPoints,
                            intoGridOfSize: (rows: rows, cols: cols)
                        )
                        // Confirmação final de que a View está sendo desenhada
                        let _ = print("Renderizando HeatmapView com grade \(result.grid.count)x\(result.grid.first?.count ?? 0) e valor máximo \(result.maxValue)")
                        
                        HeatmapView(gridData: result.grid, maxValue: result.maxValue)
                    } else {
                        Text("Aguardando dados ou treino sem movimento detectado...")
                    }
                }
            }
            .padding()
        }
        .onAppear(perform: setupConnectivity)
    }
    
    private func setupConnectivity() {
        let manager = WatchConnectivityManager.shared
        manager.workoutDataPublisher
            .sink { points in
                print("View recebeu \(points.count) pontos. Processando...")
                self.latestPoints = points // <- só guarda; processa no layout
            }
            .store(in: &cancellables)
    }
}
