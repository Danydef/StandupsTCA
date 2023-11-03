//
//  AppTest.swift
//  StandupsTCATests
//
//  Created by Daniel Jimenez on 2/11/23.
//

import ComposableArchitecture
import XCTest
@testable import StandupsTCA

@MainActor
final class AppTest: XCTestCase {
    func testEdit() async {
        let standup = Standup.mock
        
        let store = TestStore(
            initialState: AppFeature.State(
                standupsList: StandupsListFeature.State(standups: [standup])
            )
        ) {
            AppFeature()
        }
        
        await store.send(
            .path(
                .push(
                    id: 0,
                    state: .detail(
                        StandupDetailFeature.State(standup: standup)
                    )
                )
            )
        ) {
            $0.path[id: 0] = .detail(
                StandupDetailFeature.State(standup: standup)
            )
        }
        
        await store.send(
            .path(
                .element(id: 0, action: .detail(.editButtonTapped))
            )
        ) {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?
                .editStandup = StandupFormFeature.State(
                    standup: standup
                )
        }
        
        var editedStandup = standup
        let title = "Talento Morning Sync"
        editedStandup.title = title
        await store.send(
            .path(
                .element(
                    id: 0,
                    action: .detail(
                        .editStandup(
                            .presented(.set(\.$standup, editedStandup))
                        )
                    )
                )
            )
        ) {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?
                .editStandup?.standup.title = title
        }
        
        await store.send(
            .path(
                .element(id: 0, action: .detail(.saveStandupButtonTapped))
            )
        ) {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?
                .editStandup = nil
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?
                .standup.title = title
        }
        await store.receive(
            .path(
                .element(
                    id: 0,
                    action: .detail(.delegate(.sandupUpdated(editedStandup))
                    )
                )
            )
        ) {
            $0.standupsList.standups[0].title = title
        }
    }
    
    func testEdit_NonExhaustive() async {
        let standup = Standup.mock
        
        let store = TestStore(
            initialState: AppFeature.State(
                standupsList: StandupsListFeature.State(
                    standups: [standup]
                )
            )
        ) {
            AppFeature()
        }
        store.exhaustivity = .off
        
        await store.send(
            .path(
                .push(
                    id: 0,
                    state: .detail(
                        StandupDetailFeature.State(standup: standup)
                    )
                )
            )
        )
        await store.send(
            .path(
                .element(id: 0, action: .detail(.editButtonTapped))
            )
        )
        let title = "Talento Morning Sync"
        var editedStandup = standup
        editedStandup.title = title
        await store.send(
            .path(
                .element(id: 0, action: .detail(.editStandup(.presented(.set(\.$standup, editedStandup)))))
            )
        )
        await store.send(
            .path(
                .element(id: 0, action: .detail(.saveStandupButtonTapped))
            )
        )
        await store.skipReceivedActions()
        store.assert {
            $0.standupsList.standups[0].title = title
        }
    }
}
