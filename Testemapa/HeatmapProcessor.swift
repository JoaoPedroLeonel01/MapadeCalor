//
//  HeatmapProcessor.swift
//  Testemapa
//
//  Created by Joao pedro Leonel on 14/08/25.
//

import Foundation
import CoreGraphics

struct HeatmapProcessor {
    
    // Função principal que converte uma lista de pontos em uma grade de contagem
    static func process(points: [CGPoint], intoGridOfSize size: (rows: Int, cols: Int)) -> (grid: [[Int]], maxValue: Int) {
        guard !points.isEmpty else {
            return (grid: Array(repeating: Array(repeating: 0, count: size.cols), count: size.rows), maxValue: 0)
        }

        var grid = Array(repeating: Array(repeating: 0, count: size.cols), count: size.rows)
        
        // Encontra os limites dos dados para normalização
        let minX = points.min(by: { $0.x < $1.x })!.x
        let maxX = points.max(by: { $0.x < $1.x })!.x
        let minY = points.min(by: { $0.y < $1.y })!.y
        let maxY = points.max(by: { $0.y < $1.y })!.y
        
        let spanX = maxX - minX
        let spanY = maxY - minY
        
        for point in points {
            // Normaliza a posição para o intervalo [0, 1]
            let normalizedX = spanX == 0 ? 0.5 : (point.x - minX) / spanX
            let normalizedY = spanY == 0 ? 0.5 : (point.y - minY) / spanY
            
            // Mapeia para as coordenadas da grade
            var col = Int(normalizedX * CGFloat(size.cols))
            var row = Int(normalizedY * CGFloat(size.rows))
            
            // Garante que não saia dos limites
            col = max(0, min(size.cols - 1, col))
            row = max(0, min(size.rows - 1, row))
            
            // Incrementa a célula da grade
            grid[row][col] += 1
        }
        
        let maxValue = grid.flatMap { $0 }.max() ?? 0
        return (grid: grid, maxValue: maxValue)
    }
}
