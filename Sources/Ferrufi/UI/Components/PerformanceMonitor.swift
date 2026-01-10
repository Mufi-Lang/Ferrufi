//
//  PerformanceMonitor.swift
//  Ferrufi
//
//  Performance monitoring component with FPS counter and system metrics
//

import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#endif

/// Real-time performance monitoring component
@MainActor
public class PerformanceMonitor: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var fps: Double = 0.0
    @Published public private(set) var frameTime: Double = 0.0
    @Published public private(set) var memoryUsage: Double = 0.0
    @Published public private(set) var cpuUsage: Double = 0.0
    @Published public private(set) var isVisible: Bool = false

    // MARK: - Private Properties

    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private var displayLink: CADisplayLink?
    private var updateTimer: Timer?
    private let maxFrameSamples: Int = 60

    // MARK: - Singleton

    public static let shared = PerformanceMonitor()

    private init() {
        setupDisplayLink()
        setupUpdateTimer()
    }

    // deinit removed to avoid Sendable issues - cleanup handled by stopMonitoring()

    // MARK: - Public Methods

    /// Start performance monitoring
    public func startMonitoring() {
        isVisible = true
        displayLink?.isPaused = false
        updateTimer?.invalidate()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemMetrics()
            }
        }
    }

    /// Stop performance monitoring
    public func stopMonitoring() {
        isVisible = false
        displayLink?.isPaused = true
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Toggle monitoring visibility
    public func toggle() {
        if isVisible {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    /// Record a frame for FPS calculation
    public func recordFrame() {
        let currentTime = CACurrentMediaTime()

        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimes.append(frameTime)

            // Keep only recent samples
            if frameTimes.count > maxFrameSamples {
                frameTimes.removeFirst()
            }

            // Calculate FPS from recent frames
            if frameTimes.count >= 10 {
                let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                fps = 1.0 / averageFrameTime
                self.frameTime = averageFrameTime * 1000.0  // Convert to milliseconds
            }
        }

        lastFrameTime = currentTime
        frameCount += 1
    }

    // MARK: - Private Methods

    private func setupDisplayLink() {
        #if os(macOS)
            // For macOS, we'll use a timer-based approach since CADisplayLink is iOS/tvOS only
            // The recordFrame() method can be called from Metal renderers or SwiftUI updates
        #endif
    }

    private func setupUpdateTimer() {
        // Timer will be set up when monitoring starts
    }

    private func updateSystemMetrics() {
        updateMemoryUsage()
        updateCPUUsage()
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count)
            }
        }

        if result == KERN_SUCCESS {
            // Convert bytes to MB
            memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }

    private func updateCPUUsage() {
        // Simplified CPU monitoring - actual implementation would be more complex
        // For now, we'll use a placeholder value
        cpuUsage = 0.0
    }
}

// MARK: - Performance Monitor View

/// SwiftUI view for displaying performance metrics
public struct PerformanceMonitorView: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    @EnvironmentObject var themeManager: ThemeManager

    public init() {}

    public var body: some View {
        if monitor.isVisible {
            HStack(spacing: 12) {
                // FPS Counter
                MetricView(
                    label: "FPS",
                    value: String(format: "%.0f", monitor.fps),
                    color: fpsColor
                )

                // Frame Time
                MetricView(
                    label: "MS",
                    value: String(format: "%.1f", monitor.frameTime),
                    color: frameTimeColor
                )

                // Memory Usage
                MetricView(
                    label: "MEM",
                    value: String(format: "%.0f MB", monitor.memoryUsage),
                    color: memoryColor
                )

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        themeManager.currentTheme.colors.backgroundSecondary.opacity(0.95)
                    )
                    .stroke(
                        themeManager.currentTheme.colors.border.opacity(0.3),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 4,
                x: 0,
                y: 2
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                )
            )
            .onAppear {
                // Start recording frames when view appears
                startFrameRecording()
            }
        }
    }

    // MARK: - Computed Properties

    private var fpsColor: Color {
        if monitor.fps >= 58 {
            return .green
        } else if monitor.fps >= 30 {
            return .yellow
        } else {
            return .red
        }
    }

    private var frameTimeColor: Color {
        if monitor.frameTime <= 17 {  // ~60 FPS
            return .green
        } else if monitor.frameTime <= 33 {  // ~30 FPS
            return .yellow
        } else {
            return .red
        }
    }

    private var memoryColor: Color {
        if monitor.memoryUsage <= 200 {
            return .green
        } else if monitor.memoryUsage <= 500 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Private Methods

    private func startFrameRecording() {
        // Use a timer to simulate frame recording
        // In a real implementation, this would be called from the render loop
        Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { _ in
            Task { @MainActor in
                monitor.recordFrame()
            }
        }
    }
}

// MARK: - Metric View

private struct MetricView: View {
    let label: String
    let value: String
    let color: Color

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Performance Monitor Control

/// Button to toggle performance monitor
public struct PerformanceToggleButton: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    @EnvironmentObject var themeManager: ThemeManager

    public init() {}

    public var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                monitor.toggle()
            }
        } label: {
            Image(systemName: monitor.isVisible ? "speedometer.fill" : "speedometer")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    monitor.isVisible
                        ? themeManager.currentTheme.colors.accent
                        : themeManager.currentTheme.colors.foregroundTertiary
                )
        }
        .buttonStyle(.plain)
        .help("Toggle Performance Monitor")
    }
}

// MARK: - Extensions

extension PerformanceMonitor {
    /// Convenience method for Metal renderers to report frame timing
    public func reportMetalFrame(renderTime: Double) {
        Task { @MainActor in
            self.frameTime = renderTime * 1000.0  // Convert to milliseconds
            self.fps = renderTime > 0 ? 1.0 / renderTime : 0.0
        }
    }

    /// Report custom metrics from various subsystems
    public func reportCustomMetric(name: String, value: Double) {
        // Could be extended to track custom metrics
        // For now, we'll focus on the core metrics
    }
}

// MARK: - Debug Extensions

#if DEBUG
    extension PerformanceMonitor {
        /// Force specific FPS for testing UI states
        public func setTestFPS(_ fps: Double) {
            self.fps = fps
            self.frameTime = fps > 0 ? 1000.0 / fps : 0.0
        }

        /// Force specific memory usage for testing
        public func setTestMemoryUsage(_ mb: Double) {
            self.memoryUsage = mb
        }
    }
#endif
