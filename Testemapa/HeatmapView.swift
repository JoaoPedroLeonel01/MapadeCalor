import SwiftUI
import Combine

struct HeatmapView: View {
    // Recebe os pontos brutos para desenhar o caminho e o mapa
    let points: [CGPoint]
    
    // Define um tamanho ideal para as "células" da nuvem de calor
    let idealCellSize: CGFloat = 20.0
    
    var body: some View {
        // Canvas para desenho customizado
        Canvas { context, size in
            guard points.count > 1 else { return }
            
            // Processar os dados para o tamanho do Canvas
            
            // Calcula a grade ideal para o tamanho disponível
            let cols = max(1, Int(size.width / idealCellSize))
            let rows = max(1, Int(size.height / idealCellSize))
            let result = HeatmapProcessor.process(points: points, intoGridOfSize: (rows: rows, cols: cols))
            let gridData = result.grid
            let maxValue = result.maxValue
            
            // Cria uma função auxiliar para escalar os pontos do treino para o tamanho do canvas
            func scalePoint(_ point: CGPoint) -> CGPoint {
                // Encontra os limites dos dados para normalização
                let minX = points.min(by: { $0.x < $1.x })!.x
                let maxX = points.max(by: { $0.x < $1.x })!.x
                let minY = points.min(by: { $0.y < $1.y })!.y
                let maxY = points.max(by: { $0.y < $1.y })!.y
                
                let spanX = maxX - minX
                let spanY = maxY - minY
                
                // Normaliza a posição para o intervalo [0, 1]
                let normalizedX = spanX == 0 ? 0.5 : (point.x - minX) / spanX
                let normalizedY = spanY == 0 ? 0.5 : (point.y - minY) / spanY
                
                // Mapeia para as coordenadas do canvas
                // Invertemos o eixo Y porque o Core Graphics começa no topo (0,0) e o SwiftUI no fundo.
                return CGPoint(x: normalizedX * size.width, y: (1.0 - normalizedY) * size.height)
            }
            
            // Desenhar a Nuvem de Calor
            // Aplica um filtro de "blur" a tudo que for desenhado dentro deste bloco
            context.addFilter(.blur(radius: 10))
            
            for row in 0..<gridData.count {
                for col in 0..<gridData[row].count {
                    let value = gridData[row][col]
                    guard value > 0 else { continue }
                    
                    let intensity = Double(value) / Double(maxValue)
                    let color = color(forIntensity: intensity)
                    
                    // Calcula a posição central da célula no canvas
                    let cellWidth = size.width / CGFloat(cols)
                    let cellHeight = size.height / CGFloat(rows)
                    let cellX = (CGFloat(col) * cellWidth) + (cellWidth / 2)
                    let cellY = (CGFloat(row) * cellHeight) + (cellHeight / 2)
                    
                    // Desenha um círculo semi-transparente que, com o blur, cria o efeito de nuvem
                    context.fill(
                        Path(ellipseIn: CGRect(x: cellX - cellWidth, y: cellY - cellHeight, width: cellWidth * 2, height: cellHeight * 2)),
                        with: .color(color.opacity(0.9))
                    )
                }
            }
            
            // Desenhar o Rastro (Linha Amarela)
            var path = Path()
            let scaledPoints = points.map(scalePoint)
            
            // Move para o primeiro ponto
            path.move(to: scaledPoints.first!)
            
            // Adiciona uma linha para cada ponto subsequente
            for i in 1..<scaledPoints.count {
                path.addLine(to: scaledPoints[i])
            }
            
            // Desenha a linha amarela sobre a nuvem de calor
            context.stroke(path, with: .color(.yellow), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            
            // Etapa D: Desenhar os Pontos (Círculos Vermelhos)
            for point in scaledPoints {
                let pointRect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: pointRect), with: .color(.red))
            }
        }
        .clipped()
    }
    
    private func color(forIntensity intensity: Double) -> Color {
        let gradientColors: [Color] = [.blue, .green, .yellow, .red]
        let colorIndex = max(0, Int((intensity * Double(gradientColors.count - 1)).rounded(.toNearestOrAwayFromZero)))
        return gradientColors[min(gradientColors.count - 1, colorIndex)]
    }
}


struct HeatmapResultView: View {
    @State private var latestPoints: [CGPoint] = []
    @State private var cancellables = Set<AnyCancellable>()
    //private let courtImage = "quadra-futevolei"
    
    var body: some View {
        VStack {
            Text("Mapa de Calor do Treino")
                .font(.title)
            
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .foregroundColor(.gray)
                    .frame(width: 350, height: 200)
                
                VStack(){
                    // A HeatmapView agora só precisa dos pontos brutos
                    HeatmapView(points: latestPoints)
                        .frame(width: 175, height: 200)
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
                self.latestPoints = points
            }
            .store(in: &cancellables)
    }
}
