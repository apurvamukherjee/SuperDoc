import Darwin
import Foundation
import IOKit.ps
import Observation
import SwiftUI
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "system-stats")

/// System readings shared by every tile that shows them. Each metric is only sampled while at least one
/// on-screen tile uses it (`.subscribes(to:)`), and all sampled metrics share one 2 s timer.
@MainActor @Observable
final class SystemStatsService {
    static let shared = SystemStatsService()

    enum Metric: CaseIterable {
        case cpu, memory, network, disk, battery
    }

    struct Battery: Equatable {
        var level: Double             // 0...1
        var isCharging: Bool
        var isOnPower: Bool
        var minutesRemaining: Int?    // nil while macOS is still estimating
        var minutesToFull: Int?       // nil unless charging and estimated
    }

    enum MemoryPressure { case normal, warning, critical }

    struct Memory: Equatable {
        var used: UInt64
        var total: UInt64
        var pressure: MemoryPressure
    }

    private struct ByteCounters {
        var received: UInt64
        var sent: UInt64
        var time: Date
    }

    struct Disk: Equatable {
        var available: Int64
        var total: Int64
        /// Space macOS frees on demand (caches, local snapshots); already counted in `available`.
        var purgeable: Int64 = 0
        var name: String?
    }

    /// Busy share of each core type, 0...1.
    struct CPUClusters: Equatable {
        var performance: Double
        var efficiency: Double
    }

    /// 0...1, nil until two samples exist.
    private(set) var cpuUsage: Double?
    private(set) var cpuHistory: [Double] = []
    /// nil on Intel Macs, which have one kind of core.
    private(set) var cpuClusters: CPUClusters?
    private(set) var memory: Memory?
    /// Bytes per second, nil until two samples exist.
    private(set) var download: Double?
    private(set) var upload: Double?
    private(set) var downloadHistory: [Double] = []
    private(set) var uploadHistory: [Double] = []
    private(set) var disk: Disk?
    /// nil on Macs without a battery.
    private(set) var battery: Battery?

    private static let interval: TimeInterval = 2
    private static let diskEvery = 30          // ticks: disk space changes slowly, so once a minute
    private static let historyLength = 30

    @ObservationIgnored private var subscribers: [Metric: Int] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var tick = 0
    @ObservationIgnored private var previousTicks: [[UInt32]]?
    @ObservationIgnored private var previousBytes: ByteCounters?
    // mach_host_self() adds a port reference on every call, so take one and keep it.
    @ObservationIgnored private let host = mach_host_self()
    @ObservationIgnored private var batterySource: CFRunLoopSource?

    func subscribe(_ metric: Metric) {
        subscribers[metric, default: 0] += 1
        guard subscribers[metric] == 1 else { return }
        if metric == .battery { startBattery() } else { sample(metric); updateTimer() }
    }

    func unsubscribe(_ metric: Metric) {
        subscribers[metric, default: 0] -= 1
        guard subscribers[metric] == 0 else { return }
        switch metric {
        case .battery: stopBattery()
        case .cpu: previousTicks = nil
        case .network: previousBytes = nil
        case .memory, .disk: break
        }
        updateTimer()
    }

    private var active: Set<Metric> { Set(subscribers.filter { $0.value > 0 }.keys) }

    private func updateTimer() {
        let needsTimer = !active.subtracting([.battery]).isEmpty
        if needsTimer, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sampleAll() }
            }
        } else if !needsTimer {
            timer?.invalidate()
            timer = nil
        }
    }

    private func sampleAll() {
        tick += 1
        for metric in active where metric != .battery && (metric != .disk || tick % Self.diskEvery == 0) {
            sample(metric)
        }
    }

    private func sample(_ metric: Metric) {
        switch metric {
        case .cpu: sampleCPU()
        case .memory: sampleMemory()
        case .network: sampleNetwork()
        case .disk: sampleDisk()
        case .battery: readBattery()
        }
    }

    // MARK: CPU

    private func sampleCPU() {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return log.error("host_processor_info failed: \(result)") }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        let states = Int(CPU_STATE_MAX)
        let ticks = (0..<Int(cpuCount)).map { cpu in (0..<states).map { UInt32(bitPattern: info[cpu * states + $0]) } }
        defer { previousTicks = ticks }
        guard let previousTicks, previousTicks.count == ticks.count else { return }
        // Ticks are cumulative since boot, so usage is the share of non-idle ticks since the last sample.
        let cores = zip(ticks, previousTicks).map { now, before in
            let deltas = zip(now, before).map { Double($0 &- $1) }
            let total = deltas.reduce(0, +)
            return (busy: total - deltas[Int(CPU_STATE_IDLE)], total: total)
        }
        func usage(_ slice: ArraySlice<(busy: Double, total: Double)>) -> Double? {
            let total = slice.reduce(0) { $0 + $1.total }
            return total > 0 ? slice.reduce(0) { $0 + $1.busy } / total : nil
        }
        guard let overall = usage(cores[...]) else { return }
        cpuUsage = overall
        cpuHistory = Array((cpuHistory + [overall]).suffix(Self.historyLength))
        if let efficiency = Self.efficiencyCoreCount, efficiency < cores.count {
            cpuClusters = CPUClusters(performance: usage(cores[efficiency...]) ?? 0, efficiency: usage(cores[..<efficiency]) ?? 0)
        }
    }

    /// ponytail: assumes efficiency cores are logical CPUs 0..<n, true on M1–M4 (checked against IORegistry
    /// `cluster-type`); read `cluster-type` per CPU if a chip breaks that.
    private static let efficiencyCoreCount: Int? = {
        func read(_ name: String) -> Int? {
            var value: Int32 = 0
            var size = MemoryLayout<Int32>.size
            return sysctlbyname(name, &value, &size, nil, 0) == 0 ? Int(value) : nil
        }
        guard read("hw.nperflevels") == 2, let count = read("hw.perflevel1.logicalcpu"), count > 0 else { return nil }
        return count
    }()

    // MARK: Memory

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return log.error("host_statistics64 failed: \(result)") }
        let page = UInt64(sysconf(_SC_PAGESIZE))
        // Matches Activity Monitor's "Memory Used": app memory + wired + compressed.
        let appPages = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
        let used = (appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        memory = Memory(used: used, total: ProcessInfo.processInfo.physicalMemory,
                        pressure: level >= 4 ? .critical : level >= 2 ? .warning : .normal)
    }

    // MARK: Network

    private func sampleNetwork() {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return log.error("getifaddrs failed") }
        defer { freeifaddrs(head) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            // Link-layer entries carry the byte counters; skip loopback so local traffic doesn't count.
            guard entry.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), let data = entry.ifa_data,
                  String(cString: entry.ifa_name) != "lo0" else { continue }
            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            received += UInt64(counters.ifi_ibytes)
            sent += UInt64(counters.ifi_obytes)
        }
        let now = Date()
        defer { previousBytes = ByteCounters(received: received, sent: sent, time: now) }
        guard let previous = previousBytes else { return }
        let seconds = now.timeIntervalSince(previous.time)
        // Counters are 32-bit per interface and can wrap or reset (interface down); treat a drop as no traffic.
        download = received >= previous.received ? Double(received - previous.received) / seconds : 0
        upload = sent >= previous.sent ? Double(sent - previous.sent) / seconds : 0
        downloadHistory = Array((downloadHistory + [download ?? 0]).suffix(Self.historyLength))
        uploadHistory = Array((uploadHistory + [upload ?? 0]).suffix(Self.historyLength))
    }

    // MARK: Disk

    private func sampleDisk() {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey, .volumeTotalCapacityKey,
                          .volumeLocalizedNameKey]
            )
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            disk = Disk(available: available, total: Int64(values.volumeTotalCapacity ?? 0),
                        purgeable: max(available - Int64(values.volumeAvailableCapacity ?? Int(available)), 0),
                        name: values.volumeLocalizedName)
        } catch {
            log.error("Disk capacity unavailable: \(error)")
        }
    }

    // MARK: Battery (event-driven)

    private func startBattery() {
        readBattery()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<SystemStatsService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.readBattery() }
        }, context)?.takeRetainedValue() else {
            return log.error("Couldn't watch power source changes")
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        batterySource = source
    }

    private func stopBattery() {
        guard let batterySource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), batterySource, .defaultMode)
        self.batterySource = nil
    }

    private func readBattery() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let minutes = description[kIOPSTimeToEmptyKey] as? Int   // -1 while estimating
            let toFull = description[kIOPSTimeToFullChargeKey] as? Int
            battery = Battery(
                level: Double(current) / Double(max),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isOnPower: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                minutesRemaining: minutes.flatMap { $0 > 0 ? $0 : nil },
                minutesToFull: toFull.flatMap { $0 > 0 ? $0 : nil }
            )
            return
        }
        battery = nil
    }
}

extension View {
    /// Keeps `metric` sampled while this view is on screen.
    func subscribes(to metric: SystemStatsService.Metric) -> some View {
        onAppear { SystemStatsService.shared.subscribe(metric) }
            .onDisappear { SystemStatsService.shared.unsubscribe(metric) }
    }
}
