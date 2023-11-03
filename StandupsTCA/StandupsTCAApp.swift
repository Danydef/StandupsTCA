//
//  StandupsTCAApp.swift
//  StandupsTCA
//
//  Created by Daniel Personal on 13/10/23.
//

import ComposableArchitecture
import SwiftUI

@main
struct StandupsTCAApp: App {
    var body: some Scene {
        WindowGroup {
            AppView(
                store: Store(
                    initialState: AppFeature.State(
                        standupsList: StandupsListFeature.State(
                            standups: [.mock]
                        )
                    )
                ) {
                    AppFeature()
                        ._printChanges()
                }
            )
        }
    }
}
