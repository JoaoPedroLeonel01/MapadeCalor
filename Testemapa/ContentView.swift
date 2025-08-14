//
//  ContentView.swift
//  Testemapa
//
//  Created by Joao pedro Leonel on 11/08/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            HeatmapResultView()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
