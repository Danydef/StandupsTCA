//
//  StandupDetailTests.swift
//  StandupsTCATests
//
//  Created by Daniel Jimenez on 31/10/23.
//

import ComposableArchitecture
import XCTest
@testable import StandupsTCA

@MainActor
final class StandupDetailTests: XCTestCase {
    func testEdit() async {
        let title = "Standup Morning Daily"
        var standup = Standup.mock
        let store = TestStore(initialState: StandupDetailFeature.State(standup: standup)) {
            StandupDetailFeature()
        }
        store.exhaustivity = .off
        
        await  store.send(.editButtonTapped)
        standup.title = title
        await store.send(.editStandup(.presented(.set(\.$standup, standup))))
        await store.send(.saveStandupButtonTapped) {
            $0.standup.title = title
        }
    }
}
