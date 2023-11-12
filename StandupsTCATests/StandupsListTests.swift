//
//  StandupsListTests.swift
//  StandupsTCATests
//
//  Created by Daniel Personal on 29/10/23.
//

import ComposableArchitecture
import XCTest
@testable import StandupsTCA

@MainActor
final class StandupsListTests: XCTestCase {
    func testAddStandup() async {
        let title = "Talento Morning Daily"
        let store = TestStore(
            initialState: StandupsListFeature.State()
        ) {
            StandupsListFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.dataManager = .mock()
        }
        
        var standup = Standup(
            id: UUID(0),
            attendees: [Attendee(id: UUID(1))]
        )
        
        await store.send(.addButtonTapped) {
            $0.addStandup = StandupFormFeature.State(
                standup: standup
            )
        }
        
        standup.title = title
        await store.send(
            .addStandup(.presented(.set(\.$standup, standup)))
        ) {
            $0.addStandup?.standup.title = title
        }
        
        await store.send(.saveStandupButtonTapped) {
            $0.addStandup = nil
            $0.standups[0] = Standup(
                id: UUID(0),
                attendees: [Attendee(id: UUID(1))],
                title: title
            )
        }
    }
    
    func testAddStandup_NonExhaustive() async {
        let title = "Talento Morning Daily"
        let store = TestStore(
            initialState: StandupsListFeature.State()
        ) {
            StandupsListFeature()
        } withDependencies: {
            $0.dataManager = .mock()
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off(showSkippedAssertions: true)
        
        var standup = Standup(
            id: UUID(0),
            attendees: [Attendee(id: UUID(1))]
        )
        
        await store.send(.addButtonTapped)
        
        standup.title = title
        await store.send(
            .addStandup(.presented(.set(\.$standup, standup)))
        )
        
        await store.send(.saveStandupButtonTapped) {
            $0.standups[0] = Standup(
                id: UUID(0),
                attendees: [Attendee(id: UUID(1))],
                title: title
            )
        }
    }
}
