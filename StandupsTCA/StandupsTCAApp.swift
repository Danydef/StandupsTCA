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
            var standup = Standup.mock
            let _ = standup.duration = .seconds(6)
            AppView(
                store: Store(
                    initialState: AppFeature.State(
                        path: StackState([
//                            .detail(StandupDetailFeature.State(standup: .mock)),
//                            .recordMeeting(RecordMeetingFeature.State())
                        ]),
                        standupsList: StandupsListFeature.State(
                            standups: [standup]
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
