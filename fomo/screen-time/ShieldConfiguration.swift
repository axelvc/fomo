//
//  ShieldConfiguration.swift
//  fomo
//
//  Created by Axel on 29/11/25.
//

import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import SwiftUI

@MainActor
private func retrieveConfig(for token: ApplicationToken) -> ItemConfig? {
    let defaults = SharedDefaults.shared
    let dictionary = defaults.dictionaryRepresentation()

    for (key, value) in dictionary {
        guard key.hasPrefix("fomo."),
            let data = value as? Data,
            let config = try? JSONDecoder().decode(ItemConfig.self, from: data)
        else { continue }

        if config.activitySelection.applicationTokens.contains(token) {
            return config
        }
    }

    return nil
}

nonisolated final class CustomShieldConfiguration: ShieldConfigurationDataSource {

    override func configuration(
        shielding application: ManagedSettings.Application
    ) -> ShieldConfiguration {
        MainActor.assumeIsolated {
            let isOpensBlock: Bool = {
                guard let token = application.token,
                    let config = retrieveConfig(for: token)
                else { return false }

                return config.blockMode == .opens
            }()

            let secondaryLabel: ShieldConfiguration.Label? =
                isOpensBlock
                ? .init(text: "Use app", color: .tertiaryLabel)
                : nil

            return ShieldConfiguration(
                backgroundBlurStyle: .regular,
                backgroundColor: .black,
                title: .some(.init(text: "Stay focused", color: .label)),
                subtitle: .some(
                    .init(text: "This app is currently blocked by Fomo", color: .secondaryLabel)),
                primaryButtonLabel: .some(.init(text: "Close app", color: .label)),
                primaryButtonBackgroundColor: .white,
                secondaryButtonLabel: secondaryLabel
            )
        }
    }
}

nonisolated final class CustomShieldActions: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        MainActor.assumeIsolated {
            switch action {
            case .primaryButtonPressed:
                completionHandler(.close)
            case .secondaryButtonPressed:
                if let config = retrieveConfig(for: application), config.blockMode == .opens {
                    BlockController.shared.useOpen(for: config)
                }

                completionHandler(.defer)
            @unknown default:
                fatalError()
            }
        }
    }
}
