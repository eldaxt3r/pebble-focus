import Foundation

public struct AIVerdict: Sendable {
    public let approved: Bool
    public let feedback: String
}

/// Evaluates app-open reasons & ambiguous browser tabs using the user's local CLIs:
/// - Claude Code CLI (`claude -p`, uses existing Claude subscription)
/// - Antigravity CLI (`agy`)
/// - OpenCode CLI (`opencode`)
/// Falls back cleanly to fast local rules if CLI is missing or times out.
public actor CLIAIJudge {
    public init() {}

    public func evaluateAppReason(
        backend: AIBackend,
        goal: String,
        targetApp: String,
        reason: String
    ) async -> AIVerdict {
        // Fast local sanity check for obviously off-task reasons
        let lower = reason.lowercased()
        let obviousDistractions = ["bored", "scroll", "twitter", "tiktok", "instagram", "procrastinate", "meme", "netflix", "game"]
        if obviousDistractions.contains(where: { lower.contains($0) }) {
            return AIVerdict(approved: false, feedback: "Sounds like a distraction — stay locked in!")
        }

        if backend == .localRulesOnly {
            try? await Task.sleep(nanoseconds: 450_000_000)
            return AIVerdict(approved: true, feedback: "Approved for \(targetApp)")
        }

        let prompt = """
        You are Pebble, a strict but fair macOS focus companion.
        User's current focus goal: "\(goal)"
        User wants to temporarily open app: "\(targetApp)"
        User's stated reason: "\(reason)"

        Decide if this reason genuinely supports their focus goal.
        Reply ONLY in this exact single-line format:
        APPROVE: <short 5-8 word encouraging note>
        or
        DENY: <short 5-8 word nudge back to focus>
        """

        if let output = await runCLI(backend: backend, prompt: prompt, timeoutSeconds: 8) {
            return parseVerdict(output, defaultApprove: true)
        }

        // Graceful fallback if CLI isn't available or timed out
        return AIVerdict(approved: true, feedback: "Allowed (local fallback)")
    }

    public func evaluateBrowserTab(
        backend: AIBackend,
        goal: String,
        tempReason: String,
        url: String,
        title: String
    ) async -> AIVerdict {
        if backend == .localRulesOnly {
            return AIVerdict(approved: false, feedback: "Blocked distraction site")
        }

        let prompt = """
        You are Pebble, a macOS focus companion.
        User's focus goal: "\(goal)"
        Approved browser task: "\(tempReason)"
        Current browser tab title: "\(title)"
        Current browser URL: "\(url)"

        Is this tab directly helpful for their goal/task, or is it a distraction?
        Reply ONLY in this exact single-line format:
        APPROVE: <short 5-8 word note>
        or
        DENY: <short 5-8 word distraction callout>
        """

        if let output = await runCLI(backend: backend, prompt: prompt, timeoutSeconds: 8) {
            return parseVerdict(output, defaultApprove: false)
        }

        return AIVerdict(approved: false, feedback: "Off-task tab detected")
    }

    public func generateSessionRecap(
        backend: AIBackend,
        goal: String,
        durationFormatted: String,
        distractionAlerts: Int,
        eventsSummary: String
    ) async -> String {
        if backend == .localRulesOnly {
            return "You locked in for \(durationFormatted) on \"\(goal)\" with \(distractionAlerts) distraction alert(s). Take a quick breather, then pick your next concrete step."
        }

        let prompt = """
        You are Pebble, a crisp, encouraging macOS focus companion.
        The user just finished a focus sprint.
        Goal: "\(goal)"
        Time focused: \(durationFormatted)
        Distraction alerts triggered: \(distractionAlerts)
        Recent session events:
        \(eventsSummary)

        Write a concise 2-sentence recap:
        1) Acknowledge their sprint and focus discipline.
        2) Suggest one sharp, concrete next step.
        Keep it under 45 words. Plain text only, no markdown.
        """

        if let output = await runCLI(backend: backend, prompt: prompt, timeoutSeconds: 12) {
            return output
        }

        return "Sprint complete (\(durationFormatted)) on \"\(goal)\" with \(distractionAlerts) alert(s). Review what you shipped and queue up the next small milestone."
    }

    public func generateUnstickNudge(
        backend: AIBackend,
        goal: String,
        activeApp: String,
        windowTitle: String,
        browserURL: String
    ) async -> String {
        if backend == .localRulesOnly {
            return "Break \"\(goal)\" into one 5-minute action right now inside \(activeApp) — write the smallest working piece first."
        }

        let contextLine = [
            "Active app: \(activeApp)",
            windowTitle.isEmpty ? nil : "Window title: \(windowTitle)",
            browserURL.isEmpty ? nil : "Browser URL: \(browserURL)"
        ].compactMap { $0 }.joined(separator: " | ")

        let prompt = """
        You are Pebble, a sharp macOS focus coach. The user clicked "Unstick Me" because they feel stuck or tempted to drift.
        Goal: "\(goal)"
        Current context: \(contextLine)

        Give a punchy 1-2 sentence tactical nudge to get them moving again in the next 2 minutes. Keep it under 32 words. Plain text only, no markdown.
        """

        if let output = await runCLI(backend: backend, prompt: prompt, timeoutSeconds: 10) {
            return output
        }

        return "Pick the tiniest next step for \"\(goal)\" in \(activeApp) and work on it for just 2 minutes."
    }

    private func parseVerdict(_ raw: String, defaultApprove: Bool) -> AIVerdict {
        let lines = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("APPROVE:") {
                let msg = String(line.dropFirst("APPROVE:".count)).trimmingCharacters(in: .whitespaces)
                return AIVerdict(approved: true, feedback: msg)
            }
            if upper.hasPrefix("DENY:") {
                let msg = String(line.dropFirst("DENY:".count)).trimmingCharacters(in: .whitespaces)
                return AIVerdict(approved: false, feedback: msg)
            }
        }
        return AIVerdict(approved: defaultApprove, feedback: lines.last ?? "")
    }

    public func resolveCLIPath(for backend: AIBackend) -> String? {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let candidates: [String]

        switch backend {
        case .claudeCLI:
            candidates = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.local/bin/claude"]
        case .agyCLI:
            candidates = ["\(home)/.local/bin/agy", "/opt/homebrew/bin/agy", "/usr/local/bin/agy"]
        case .opencodeCLI:
            candidates = ["\(home)/.opencode/bin/opencode", "/opt/homebrew/bin/opencode", "\(home)/.local/bin/opencode", "/usr/local/bin/opencode"]
        case .localRulesOnly:
            return nil
        }

        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    private func runCLI(backend: AIBackend, prompt: String, timeoutSeconds: Double) async -> String? {
        guard let execPath = resolveCLIPath(for: backend) else { return nil }

        let args: [String]
        switch backend {
        case .claudeCLI:
            args = ["-p", prompt, "--output-format", "text"]
        case .agyCLI:
            args = ["-p", prompt]
        case .opencodeCLI:
            args = ["run", prompt]
        case .localRulesOnly:
            return nil
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = args

            var env = ProcessInfo.processInfo.environment
            let extraPaths = "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin:\(NSHomeDirectory())/.opencode/bin"
            env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "/usr/bin:/bin")
            process.environment = env

            let outPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = Pipe()

            final class ResumeBox: @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false
                private let continuation: CheckedContinuation<String?, Never>
                init(_ continuation: CheckedContinuation<String?, Never>) {
                    self.continuation = continuation
                }
                func finish(_ value: String?) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: value)
                }
            }
            let box = ResumeBox(continuation)

            let timeoutWork = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
                box.finish(nil)
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWork)

            process.terminationHandler = { proc in
                timeoutWork.cancel()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if proc.terminationStatus == 0, let text, !text.isEmpty {
                    box.finish(text)
                } else {
                    box.finish(nil)
                }
            }

            do {
                try process.run()
            } catch {
                timeoutWork.cancel()
                box.finish(nil)
            }
        }
    }
}
