// DiskBrowserViewModel+ExternalOpen.swift — Finder Quick Action and external URL handling.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Finder / external open

    func analyzeExternalURLs(_ urls: [URL]) {
        let targets = urls.map { ExternalOpenResolver.analyzeTarget(for: $0) }
        guard let target = targets.first else { return }

        activePanel = .browser
        NSApp.activate(ignoringOtherApps: true)

        Task {
            if volumes.isEmpty {
                volumes = await scanner.listVolumes()
            }

            let volumeRoots = volumes.map {
                ExternalOpenResolver.VolumeRoot(id: $0.id, scanRoot: $0.scanRoot)
            }
            guard let volumeID = ExternalOpenResolver.containingVolumeID(for: target, volumes: volumeRoots),
                  let volume = volumes.first(where: { $0.id == volumeID }) else {
                errorMessage = L10n.finderAnalyzeVolumeNotFound
                return
            }

            selectedVolume = volume
            pendingExternalAnalyzeURL = target

            switch appPhase {
            case .ready:
                pendingExternalAnalyzeURL = nil
                navigate(to: target)
            case .welcome, .permissions:
                if appPhase != .scanning {
                    startInitialScan()
                }
            case .scanning:
                break
            }
        }
    }

    func applyPendingExternalAnalyzeIfNeeded() {
        guard appPhase == .ready, let target = pendingExternalAnalyzeURL else { return }
        pendingExternalAnalyzeURL = nil
        guard let volume = selectedVolume,
              PathUtils.isWithinVolume(target, scanRoot: volume.scanRoot) else { return }
        navigate(to: target)
    }

}
