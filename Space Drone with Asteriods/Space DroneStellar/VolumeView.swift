//
//  File.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 9/6/26.
//

import Foundation
import SwiftUI
import SceneKit

// ============================================================
// MARK: - Volume View
// ============================================================

struct VolumeView: View {

    @Binding var volume: Double

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {

        VStack(spacing: 20) {

            Text("Sound Volume")
                .font(.headline)

            Slider(
                value: $volume,
                in: 0...1
            )
            .padding(.horizontal)

            Text(
                "Volume: \(Int(volume * 100))%"
            )
            .foregroundColor(.secondary)

            Button("Close") {
                dismiss()
            }
            .padding(.top, 8)
        }
        .padding()
        .presentationDetents(
            [.height(220)]
        )
    }
}
