import SwiftUI
import SceneKit

// MARK: - SceneKit container

struct SceneKitContainerView: UIViewRepresentable {
    @ObservedObject var game: GameState
    func makeCoordinator() -> SceneWorld { SceneWorld() }
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling2X
        view.autoenablesDefaultLighting = false
        return view
    }
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.sync(with: game)
    }
}

// MARK: - UI chrome

struct CockpitWindowOverlay: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    center: .center,
                    startRadius: min(geo.size.width, geo.size.height) * 0.3,
                    endRadius: max(geo.size.width, geo.size.height) * 0.65
                )
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(white: 0.3), Color.black, Color(white: 0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 22
                    )
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.28))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct RadarMapView: View {
    @ObservedObject var game: GameState
    var mapSize: CGFloat = 120
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55))
            Canvas { context, size in
                let maxZ: CGFloat = 70
                func map(angle: Double, z: CGFloat) -> CGPoint {
                    CGPoint(
                        x: CGFloat(angle / (2 * .pi)) * size.width,
                        y: size.height - (max(0, min(maxZ, z)) / maxZ) * size.height
                    )
                }
                for a in game.asteroids {
                    let p = map(angle: a.lateralAngle, z: a.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(.gray))
                }
                for a in game.swarmManager.aliens where !a.destroyed {
                    let p = map(angle: a.lateralAngle, z: a.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(.purple))
                }
                for a in game.flockManager.aliens where !a.destroyed {
                    let p = map(angle: a.lateralAngle, z: a.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(.teal))
                }
                if let e = game.enemySpaceShip, !e.destroyed {
                    let p = map(angle: e.lateralAngle, z: e.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(.red))
                }
                let shipP = map(angle: game.spaceShip.lateralAngle, z: 0)
                context.fill(Path(ellipseIn: CGRect(x: shipP.x - 2.5, y: shipP.y - 2.5, width: 5, height: 5)), with: .color(.cyan))
            }
            .padding(4)
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        }
        .frame(width: mapSize, height: mapSize * 0.85)
    }
}

struct JoystickView: View {
    var diameter: CGFloat = 120
    var knobDiameter: CGFloat = 56
    var baseColor: Color = .white
    var onChange: (CGVector) -> Void
    var onEnd: () -> Void
    @State private var knobOffset: CGSize = .zero
    @State private var active = false

    var body: some View {
        ZStack {
            Circle().fill(baseColor.opacity(0.12)).frame(width: diameter, height: diameter)
            Circle().strokeBorder(baseColor.opacity(0.35), lineWidth: 2).frame(width: diameter, height: diameter)
            Circle().fill(baseColor.opacity(active ? 0.55 : 0.35))
                .frame(width: knobDiameter, height: knobDiameter)
                .offset(knobOffset)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    active = true
                    let maxDistance = (diameter - knobDiameter) / 2
                    var dx = value.translation.width
                    var dy = value.translation.height
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance > maxDistance && distance > 0 {
                        dx = dx / distance * maxDistance
                        dy = dy / distance * maxDistance
                    }
                    knobOffset = CGSize(width: dx, height: dy)
                    onChange(CGVector(dx: dx / maxDistance, dy: dy / maxDistance))
                }
                .onEnded { _ in
                    active = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { knobOffset = .zero }
                    onChange(.zero)
                    onEnd()
                }
        )
    }
}

struct VolumeView: View {
    @Binding var volume: Double
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 20) {
            Text("Sound Volume").font(.headline)
            Slider(value: $volume, in: 0...1).padding(.horizontal)
            Text("Volume: \(Int(volume * 100))%").foregroundColor(.secondary)
            Button("Close") { dismiss() }.padding(.top, 8)
        }
        .padding()
        .presentationDetents([.height(220)])
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var game = GameState()
    @State private var showVolumeDialog = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                SceneKitContainerView(game: game)
                    .ignoresSafeArea()
                    .onAppear { game.start() }
                    .onDisappear { game.stopAll() }
                CockpitWindowOverlay()

                if game.gameOver {
                    VStack(spacing: 16) {
                        Text("Game Over").font(.system(size: 40, weight: .bold)).foregroundColor(.red)
                        Text("Score: \(game.score)").font(.system(size: 24)).foregroundColor(.white)
                        Button("Restart") { game.restart() }
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                    }
                }

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tube Runner").foregroundColor(.white).font(.system(size: 16, weight: .semibold))
                            Text("Blue: move · Red: aim + hold to fire")
                                .foregroundColor(.white.opacity(0.9)).font(.system(size: 12))
                            Text("Purple squid · Teal deep fish · Shield 2s")
                                .foregroundColor(.cyan).font(.system(size: 12, weight: .bold))
                            Text(String(format: "Speed %.1f  Dist %.0f",
                                         game.spaceShip.forwardSpeed, game.spaceShip.progress))
                                .foregroundColor(.orange).font(.system(size: 12, weight: .medium))
                            // Toggle collision sound effect
                            Toggle("Collision Sound", isOn: $game.playCollisionSound)
                                .toggleStyle(.switch)
                                .foregroundColor(.white)
                                .padding(.top, 6)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Button(action: { showVolumeDialog = true }) {
                                Image(systemName: "speaker.wave.2.fill").foregroundColor(.white).font(.system(size: 22))
                            }
                            RadarMapView(game: game)
                        }
                    }
                    .padding()
                    Spacer()
                }

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        JoystickView(
                            diameter: 110,
                            knobDiameter: 48,
                            baseColor: .blue,
                            onChange: { v in
                                game.joystickVector = CGVector(
                                    dx: v.dx,
                                    dy: v.dy
                                )
                            },
                            onEnd: {
                                game.joystickVector = .zero
                            }
                        )
                        
                            .padding(.leading, 28)
                        Spacer()
                        Text("Score: \(game.score)")
                            .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        VStack(spacing: 14) {
                            // Fire / aim stick — hold to rapid-fire
                            JoystickView(
                                diameter: 100,
                                knobDiameter: 44,
                                baseColor: .red,
                                onChange: { v in
                                    game.cannonAzimuth = Double(v.dx) * 0.8
                                    game.cannonElevation = max(-0.7, min(0.7, Double(-v.dy) * 0.7))
                                    game.startFiring()
                                },
                                onEnd: {
                                    game.cannonAzimuth = 0
                                    game.cannonElevation = 0
                                    game.stopFiring()
                                }
                            )
                            Button(action: { game.activateShield() }) {
                                ZStack {
                                    Circle().fill(Color.cyan.opacity(game.shieldActive ? 0.5 : 0.25))
                                        .frame(width: 52, height: 52)
                                    Circle().strokeBorder(Color.cyan.opacity(0.7), lineWidth: 2)
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "shield.fill").foregroundColor(.cyan).font(.system(size: 20))
                                }
                            }
                            .disabled(game.shieldActive)
                        }
                        .padding(.trailing, 28)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showVolumeDialog) { VolumeView(volume: $game.volume) }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}
