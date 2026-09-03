
import SwiftUI
import SceneKit
import QuartzCore

// ============================================================
// MARK: - SceneKit Container
// ============================================================

// Coordinator that owns both scene worlds and switches between
// them based on GameState.currentSection.

final class GameSceneCoordinator: NSObject {

    // ============================================================
    // WORLDS
    // ============================================================

    let oceanWorld = OceanSceneWorld()
    let tunnelWorld = TunnelSceneWorld()

    // ============================================================
    // ACTIVE WORLD
    // ============================================================

    private(set) var usingOcean = false

    // ============================================================
    // SCENE
    // ============================================================

    var scene: SCNScene {
        usingOcean
            ? oceanWorld.scene
            : tunnelWorld.scene
    }

    // ============================================================
    // CAMERA
    // ============================================================

    var camera: SCNNode {
        usingOcean
            ? oceanWorld.camera
            : tunnelWorld.camera
    }

    // ============================================================
    // SYNC
    //
    // GameState.currentSection is the source of truth.
    //
    // If GameState.gameOver becomes true, stop synchronizing
    // the SceneKit worlds.
    // ============================================================

    @discardableResult
    func sync(with game: GameState) -> Bool {

        // ========================================================
        // GAME OVER
        // ========================================================

        if game.gameOver {
            return false
        }

        // ========================================================
        // DETERMINE ACTIVE WORLD
        // ========================================================

        let shouldUseOcean =
            game.currentSection == .ocean

        let switched =
            shouldUseOcean != usingOcean

        usingOcean =
            shouldUseOcean

        // ========================================================
        // RENDER ACTIVE WORLD
        // ========================================================

        if usingOcean {

            oceanWorld.sync(
                with: game
            )

        } else {

            tunnelWorld.sync(
                with: game
            )
        }

        // ========================================================
        // REPORT WHETHER THE ACTIVE SCENE CHANGED
        // ========================================================

        return switched
    }
}


// ============================================================
// MARK: - SceneKit Container View
// ============================================================

struct SceneKitContainerView: UIViewRepresentable {

    @ObservedObject var game: GameState

    func makeCoordinator() -> GameSceneCoordinator {
        GameSceneCoordinator()
    }

    func makeUIView(
        context: Context
    ) -> SCNView {

        let view = SCNView()

        view.scene =
            context.coordinator.scene

        view.pointOfView =
            context.coordinator.camera

        view.backgroundColor =
            .black

        view.antialiasingMode =
            .multisampling2X

        view.autoenablesDefaultLighting =
            false

        return view
    }

    func updateUIView(
        _ uiView: SCNView,
        context: Context
    ) {

        let switched =
            context.coordinator.sync(
                with: game
            )

        if switched {

            uiView.scene =
                context.coordinator.scene

            uiView.pointOfView =
                context.coordinator.camera
        }
    }
}


// ============================================================
// MARK: - Cockpit Window Overlay
// ============================================================

struct CockpitWindowOverlay: View {

    var body: some View {

        GeometryReader { geo in

            ZStack {

                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.55)
                    ],
                    center: .center,
                    startRadius:
                        min(
                            geo.size.width,
                            geo.size.height
                        ) * 0.3,
                    endRadius:
                        max(
                            geo.size.width,
                            geo.size.height
                        ) * 0.65
                )

                RoundedRectangle(
                    cornerRadius: 28
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(white: 0.3),
                            Color.black,
                            Color(white: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 22
                )

                Image(
                    systemName: "plus"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .ultraLight
                    )
                )
                .foregroundColor(
                    .white.opacity(0.28)
                )
                .position(
                    x: geo.size.width / 2,
                    y: geo.size.height / 2
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}


// ============================================================
// MARK: - Radar Map
// ============================================================

struct RadarMapView: View {

    @ObservedObject var game: GameState

    var mapSize: CGFloat = 120

    var body: some View {

        ZStack {

            RoundedRectangle(
                cornerRadius: 8
            )
            .fill(
                Color.black.opacity(0.55)
            )

            Canvas { context, size in

                let maxZ: CGFloat = 70

                func map(
                    angle: Double,
                    z: CGFloat
                ) -> CGPoint {

                    CGPoint(
                        x:
                            CGFloat(
                                angle / (2 * .pi)
                            ) * size.width,

                        y:
                            size.height -
                            (
                                max(
                                    0,
                                    min(
                                        maxZ,
                                        z
                                    )
                                ) / maxZ
                            ) * size.height
                    )
                }

                // ====================================================
                // ASTEROIDS
                // ====================================================

                for asteroid in game.asteroids {

                    let p =
                        map(
                            angle: asteroid.lateralAngle,
                            z: asteroid.z
                        )

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x: p.x - 2,
                                    y: p.y - 2,
                                    width: 4,
                                    height: 4
                                )
                        ),
                        with: .color(.gray)
                    )
                }

                // ====================================================
                // PURPLE SQUIDS
                // ====================================================

                for squid in
                    game.swarmManager.squids
                where !squid.destroyed {

                    let p =
                        map(
                            angle: squid.lateralAngle,
                            z: squid.z
                        )

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x: p.x - 1.5,
                                    y: p.y - 1.5,
                                    width: 3,
                                    height: 3
                                )
                        ),
                        with: .color(.purple)
                    )
                }

                // ====================================================
                // TEAL DEEP FISH
                // ====================================================

                for fish in
                    game.flockManager.aliens
                where !fish.destroyed {

                    let p =
                        map(
                            angle: fish.lateralAngle,
                            z: fish.z
                        )

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x: p.x - 1.5,
                                    y: p.y - 1.5,
                                    width: 3,
                                    height: 3
                                )
                        ),
                        with: .color(.teal)
                    )
                }

                // ====================================================
                // ENEMY SPACESHIP
                // ====================================================

                if let enemy =
                    game.enemySpaceShip,
                   !enemy.destroyed {

                    let p =
                        map(
                            angle: enemy.lateralAngle,
                            z: enemy.z
                        )

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x: p.x - 2.5,
                                    y: p.y - 2.5,
                                    width: 5,
                                    height: 5
                                )
                        ),
                        with: .color(.red)
                    )
                }

                // ====================================================
                // PLAYER SHIP
                // ====================================================

                let shipP =
                    map(
                        angle:
                            game.spaceShip.lateralAngle,
                        z: 0
                    )

                context.fill(
                    Path(
                        ellipseIn:
                            CGRect(
                                x: shipP.x - 2.5,
                                y: shipP.y - 2.5,
                                width: 5,
                                height: 5
                            )
                    ),
                    with: .color(.cyan)
                )
            }
            .padding(4)

            RoundedRectangle(
                cornerRadius: 8
            )
            .strokeBorder(
                Color.white.opacity(0.3),
                lineWidth: 1
            )
        }
        .frame(
            width: mapSize,
            height: mapSize * 0.85
        )
    }
}


// ============================================================
// MARK: - Joystick
// ============================================================

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

            Circle()
                .fill(
                    baseColor.opacity(0.12)
                )
                .frame(
                    width: diameter,
                    height: diameter
                )

            Circle()
                .strokeBorder(
                    baseColor.opacity(0.35),
                    lineWidth: 2
                )
                .frame(
                    width: diameter,
                    height: diameter
                )

            Circle()
                .fill(
                    baseColor.opacity(
                        active ? 0.55 : 0.35
                    )
                )
                .frame(
                    width: knobDiameter,
                    height: knobDiameter
                )
                .offset(knobOffset)
        }
        .contentShape(Circle())
        .gesture(

            DragGesture(
                minimumDistance: 0
            )

            .onChanged { value in

                active = true

                let maxDistance =
                    (diameter - knobDiameter) / 2

                var dx =
                    value.translation.width

                var dy =
                    value.translation.height

                let distance =
                    sqrt(
                        dx * dx +
                        dy * dy
                    )

                if distance > maxDistance,
                   distance > 0 {

                    dx =
                        dx / distance *
                        maxDistance

                    dy =
                        dy / distance *
                        maxDistance
                }

                knobOffset =
                    CGSize(
                        width: dx,
                        height: dy
                    )

                onChange(
                    CGVector(
                        dx: dx / maxDistance,
                        dy: dy / maxDistance
                    )
                )
            }

            .onEnded { _ in

                active = false

                withAnimation(
                    .spring(
                        response: 0.25,
                        dampingFraction: 0.6
                    )
                ) {
                    knobOffset = .zero
                }

                onChange(.zero)

                onEnd()
            }
        )
    }
}


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


// ============================================================
// MARK: - Content View
// ============================================================

struct ContentView: View {

    @StateObject private var game =
        GameState()

    @State private var showVolumeDialog =
        false

    var body: some View {

        GeometryReader { geo in

            ZStack {

                // ====================================================
                // BLACK BACKGROUND
                // ====================================================

                Color.black
                    .ignoresSafeArea()


                // ====================================================
                // SCENEKIT GAME
                // ====================================================

                SceneKitContainerView(
                    game: game
                )
                .ignoresSafeArea()
                .onAppear {
                    game.start()
                }
                .onDisappear {
                    game.stopAll()
                }


                // ====================================================
                // COCKPIT WINDOW
                // ====================================================

                CockpitWindowOverlay()


                // ====================================================
                // SCENE LABEL
                // ====================================================

                VStack {

                    Text(
                        sceneLabel(
                            for:
                                game.currentSection
                        )
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundColor(
                        .white.opacity(0.9)
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .frame(
                        maxWidth: .infinity
                    )
                    .background(
                        Color.black.opacity(0.4)
                    )

                    Spacer()
                }
                .ignoresSafeArea(
                    edges: .top
                )


                // ====================================================
                // GAME OVER
                //
                // This is displayed whenever:
                //
                // game.gameOver == true
                // ====================================================

                if game.gameOver {

                    VStack(spacing: 16) {

                        Text("Game Over")
                            .font(
                                .system(
                                    size: 40,
                                    weight: .bold
                                )
                            )
                            .foregroundColor(.red)

                        Text(
                            "Score: \(game.score)"
                        )
                        .font(
                            .system(size: 24)
                        )
                        .foregroundColor(.white)

                        Button("Restart") {

                            game.restart()
                        }
                        .padding(
                            .horizontal,
                            24
                        )
                        .padding(
                            .vertical,
                            10
                        )
                        .background(
                            Color.blue
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }


                // ====================================================
                // TOP INFORMATION / RADAR
                // ====================================================

                VStack {

                    HStack(
                        alignment: .top
                    ) {

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {

                            Text(
                                "Blue: move · Red: aim + hold to fire"
                            )
                            .foregroundColor(
                                .white.opacity(0.9)
                            )
                            .font(
                                .system(size: 12)
                            )

                            Text(
                                "Purple squid · Teal deep fish · Shield 2s"
                            )
                            .foregroundColor(
                                .cyan
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .bold
                                )
                            )

                            Text(
                                String(
                                    format:
                                        "Speed %.1f  Dist %.0f",
                                    game.spaceShip.forwardSpeed,
                                    game.spaceShip.progress
                                )
                            )
                            .foregroundColor(
                                .orange
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .medium
                                )
                            )

                            // ====================================================
                            // COLLISION SOUND
                            // ====================================================

                            Toggle(
                                "Collision Sound",
                                isOn:
                                    $game.playCollisionSound
                            )
                            .toggleStyle(.switch)
                            .foregroundColor(.white)
                            .padding(.top, 6)
                        }

                        Spacer()

                        VStack(
                            alignment: .trailing,
                            spacing: 8
                        ) {

                            // ====================================================
                            // VOLUME
                            // ====================================================

                            Button(
                                action: {
                                    showVolumeDialog = true
                                }
                            ) {

                                Image(
                                    systemName:
                                        "speaker.wave.2.fill"
                                )
                                .foregroundColor(.white)
                                .font(
                                    .system(size: 22)
                                )
                            }

                            // ====================================================
                            // RADAR
                            // ====================================================

                            RadarMapView(
                                game: game
                            )
                        }
                    }
                    .padding()

                    Spacer()
                }


                // ====================================================
                // BOTTOM CONTROLS
                // ====================================================

                VStack {

                    Spacer()

                    HStack(
                        alignment: .bottom
                    ) {

                        // ====================================================
                        // MOVEMENT JOYSTICK
                        // ====================================================

                        JoystickView(
                            diameter: 110,
                            knobDiameter: 48,
                            baseColor: .blue,

                            onChange: { v in

                                game.joystickVector =
                                    CGVector(
                                        dx: v.dx,
                                        dy: v.dy
                                    )

                                // Clamp ship to the ocean surface.
                                clampShipToSurfaceIfNeeded()
                            },

                            onEnd: {

                                game.joystickVector =
                                    .zero

                                clampShipToSurfaceIfNeeded()
                            }
                        )
                        .padding(
                            .leading,
                            28
                        )


                        Spacer()


                        // ====================================================
                        // SCORE
                        // ====================================================

                        Text(
                            "Score: \(game.score)"
                        )
                        .font(
                            .system(
                                size: 18,
                                weight: .semibold
                            )
                        )
                        .foregroundColor(.white)


                        Spacer()


                        // ====================================================
                        // AIM / FIRE + SHIELD
                        // ====================================================

                        VStack(spacing: 14) {

                            // ====================================================
                            // FIRE / AIM JOYSTICK
                            //
                            // Hold to rapid-fire.
                            // ====================================================

                            JoystickView(
                                diameter: 100,
                                knobDiameter: 44,
                                baseColor: .red,

                                onChange: { v in

                                    game.cannonAzimuth =
                                        Double(v.dx) * 0.8

                                    game.cannonElevation =
                                        max(
                                            -0.7,
                                            min(
                                                0.7,
                                                Double(-v.dy) * 0.7
                                            )
                                        )

                                    game.startFiring()
                                },

                                onEnd: {

                                    game.cannonAzimuth =
                                        0

                                    game.cannonElevation =
                                        0

                                    game.stopFiring()
                                }
                            )


                            // ====================================================
                            // SHIELD
                            // ====================================================

                            Button(
                                action: {
                                    game.activateShield()
                                }
                            ) {

                                ZStack {

                                    Circle()
                                        .fill(
                                            Color.cyan.opacity(
                                                game.shieldActive
                                                    ? 0.5
                                                    : 0.25
                                            )
                                        )
                                        .frame(
                                            width: 52,
                                            height: 52
                                        )

                                    Circle()
                                        .strokeBorder(
                                            Color.cyan.opacity(0.7),
                                            lineWidth: 2
                                        )
                                        .frame(
                                            width: 52,
                                            height: 52
                                        )

                                    Image(
                                        systemName:
                                            "shield.fill"
                                    )
                                    .foregroundColor(
                                        .cyan
                                    )
                                    .font(
                                        .system(
                                            size: 20
                                        )
                                    )
                                }
                            }
                            .disabled(
                                game.shieldActive
                            )
                        }
                        .padding(
                            .trailing,
                            28
                        )
                    }
                    .padding(
                        .bottom,
                        40
                    )
                }
            }
        }

        // ============================================================
        // VOLUME SHEET
        // ============================================================

        .sheet(
            isPresented:
                $showVolumeDialog
        ) {

            VolumeView(
                volume:
                    $game.volume
            )
        }

        .preferredColorScheme(
            .dark
        )

        .statusBarHidden()
    }


    // ============================================================
    // MARK: - Scene Label
    // ============================================================

    private func sceneLabel(
        for section: SceneSection
    ) -> String {

        switch section {

        case .tunnel:
            return "SPACE TUNNEL"

        case .ocean:
            return "ALIEN OCEAN"
        }
    }


    // ============================================================
    // MARK: - Ocean Surface Clamp
    // ============================================================

    /// Prevents the spaceship from going below the ocean surface.

    private func clampShipToSurfaceIfNeeded() {

        guard
            game.currentSection == .ocean
        else {
            return
        }

        if game.spaceShip.position.y < 0 {

            var pos =
                game.spaceShip.position

            pos.y = 0

            game.spaceShip.position =
                pos
        }
    }
}

