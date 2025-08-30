import SwiftUI

// Heatmap “blurred” com rotação em torno da ORIGEM (0,0).
//- points: pontos no sistema do “mundo” (metros)
//- worldBounds: retângulo fixo do mundo (ex.: meia quadra)
//- rotationDegrees: rotação aplicada aos pontos ao redor da ORIGEM (0,0)
//- flipX/flipY: espelhamento opcional no mundo
struct HeatmapView: View {
    let points: [CGPoint]
    let worldBounds: CGRect
    var rotationDegrees: CGFloat = 0
    var flipX: Bool = false
    var flipY: Bool = false

    private let idealCellSize: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            // 1) Filtra pontos dentro do mundo ANTES de transformar (para manter coerência com bounds)
            let inBounds = points.filter { worldBounds.contains($0) }
            guard !inBounds.isEmpty else { return }

            // 2) Rotação no PRÓPRIO EIXO (origem 0,0) + flips
            func rotateOrigin(_ p: CGPoint, deg: CGFloat) -> CGPoint {
                let d = deg.truncatingRemainder(dividingBy: 360)
                if d == 0 { return p }
                let rad = d * .pi / 180
                let rx = p.x * cos(rad) - p.y * sin(rad)
                let ry = p.x * sin(rad) + p.y * cos(rad)
                return CGPoint(x: rx, y: ry)
            }
            func flip(_ p: CGPoint) -> CGPoint {
                CGPoint(x: flipX ? -p.x : p.x,
                        y: flipY ? -p.y : p.y)
            }
            let transformed = inBounds.map { flip( rotateOrigin($0, deg: rotationDegrees) ) }

            // 3) Clipa o desenho para o tamanho do canvas
            context.clip(to: Path(CGRect(origin: .zero, size: size)))

            // 4) Escala mundo → canvas (Y invertido para coordenada de tela)
            let minX = worldBounds.minX, maxX = worldBounds.maxX
            let minY = worldBounds.minY, maxY = worldBounds.maxY
            let spanX = max(maxX - minX, 0.0001)
            let spanY = max(maxY - minY, 0.0001)

            func scalePoint(_ p: CGPoint) -> CGPoint {
                let nx = (p.x - minX) / spanX
                let ny = (p.y - minY) / spanY
                return CGPoint(x: nx * size.width, y: (1 - ny) * size.height)
            }

            // 5) Heatmap por grade + blur
            let cols = max(Int(size.width / idealCellSize), 1)
            let rows = max(Int(size.height / idealCellSize), 1)

            let result = HeatmapProcessor.process(
                points: transformed,
                worldBounds: worldBounds,
                gridSize: (rows, cols)
            )

            let cellW = size.width / CGFloat(cols)
            let cellH = size.height / CGFloat(rows)

            if result.maxValue > 0 {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 10))

                    for r in 0..<rows {
                        for c in 0..<cols {
                            let value = result.grid[r][c]
                            if value == 0 { continue }

                            let t = CGFloat(value) / CGFloat(result.maxValue)

                            // círculo maior que a célula para ficar orgânico
                            let center = CGPoint(x: (CGFloat(c) + 0.5) * cellW,
                                                 y: (CGFloat(r) + 0.5) * cellH)
                            let radius = max(cellW, cellH)
                            let rect = CGRect(x: center.x - radius,
                                              y: center.y - radius,
                                              width: 2 * radius,
                                              height: 2 * radius)

                            layer.fill(Path(ellipseIn: rect),
                                       with: .color(color(forIntensity: t).opacity(0.2)))
                        }
                    }
                }
            }
        }
    }

    private func color(forIntensity t: CGFloat) -> Color {
        switch t {
        case ..<0.75:  return .yellow
        case ..<0.95: return .orange
        default:      return .red
        }
    }
}
 
