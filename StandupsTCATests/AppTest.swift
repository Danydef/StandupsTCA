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
                standupsList: StandupsListFeature.State(
                )
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.dataManager = .mock(initialData: try? JSONEncoder().encode([standup]))
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
                .destination = .editStandup(StandupFormFeature.State(standup: standup))
        }
        
        var editedStandup = standup
        let title = "Talento Morning Sync"
        editedStandup.title = title
        await store.send(
            .path(
                .element(
                    id: 0,
                    action: .detail(
                        .destination(.presented(.editStandup(.set(\.$standup, editedStandup))))
                    )
                )
            )
        ) {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?
                .$destination[case: /StandupDetailFeature.Destination.State.editStandup]?.standup.title = title
        }
        
        await store.send(
            .path(
                .element(id: 0, action: .detail(.saveStandupButtonTapped))
            )
        ) {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?
                .destination = nil
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
                standupsList: StandupsListFeature.State()
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.dataManager = .mock(initialData: try? JSONEncoder().encode([standup]))
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
                .element(id: 0, action: .detail(.destination(.presented(.editStandup(.set(\.$standup, editedStandup))))))
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
    
    func testDelete_NonExhaustive() async {
        let standup = Standup.mock
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([
                    .detail(
                        StandupDetailFeature.State(standup: standup)
                    )
                ]),
                standupsList: StandupsListFeature.State()
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.dataManager = .mock(initialData: try? JSONEncoder().encode([standup]))
        }
        
        store.exhaustivity = .off
        
        await store.send(
            .path(
                .element(id: 0, action: .detail(.deleteButtonTapped))
            )
        )
        
        await store.send(
            .path(
                .element(
                    id: 0,
                    action: .detail(
                        .destination(.presented(.alert(.confirmDeletion)))
                    )
                )
            )
        )
        
        await store.skipReceivedActions()
        store.assert {
            $0.path = StackState([])
            $0.standupsList.standups = []
        }
    }
    
    func testTimerRunOutEndMeeting() async {
        let standup = Standup(
            id: UUID(),
            attendees: [Attendee(id: UUID())],
            duration: .seconds(1),
            meetings: [],
            theme: .bubblegum,
            title: "Talento"
        )
        
        let date = Date()
        
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([
                    .detail(
                        StandupDetailFeature.State(standup: standup)
                    ),
                    .recordMeeting(
                        RecordMeetingFeature.State(standup: standup)
                    )
                ]),
                standupsList: StandupsListFeature.State()
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.date.now = date
            $0.speechClient.requestAuthorization = { false }
            $0.uuid = .incrementing
            $0.dataManager = .mock(initialData: try? JSONEncoder().encode([standup]))
        }
        store.exhaustivity = .off
        
        await store.send(.path(.element(id: 1, action: .recordMeeting(.onTask))))
        await store.receive(.path(.element(id: 1, action: .recordMeeting(.delegate(.saveMeeting(transcript: ""))))))
        await store.receive(.path(.popFrom(id: 1)))
        store.assert {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?.standup.meetings = [
                Meeting(
                    id: UUID(0),
                    date: date,
                    transcript: ""
                )
            ]
            XCTAssertEqual($0.path.count, 1)
        }
    }
    
    func testTimerRunOutEndMeeting_WithSpeechRecognizer() async {
        let standup = Standup(
            id: UUID(),
            attendees: [Attendee(id: UUID())],
            duration: .seconds(1),
            meetings: [],
            theme: .bubblegum,
            title: "Talento"
        )
        
        let date = Date()
        let transcript = "This was a really good meeting!"
        
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([
                    .detail(
                        StandupDetailFeature.State(standup: standup)
                    ),
                    .recordMeeting(
                        RecordMeetingFeature.State(standup: standup)
                    )
                ]),
                standupsList: StandupsListFeature.State()
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.date.now = date
            $0.speechClient.requestAuthorization = { true }
            $0.speechClient.start = {
                AsyncThrowingStream { $0.yield(transcript) }
            }
            $0.uuid = .incrementing
            $0.dataManager = .mock(initialData: try? JSONEncoder().encode([standup]))
        }
        store.exhaustivity = .off
        
        await store.send(.path(.element(id: 1, action: .recordMeeting(.onTask))))
        await store.receive(.path(.element(id: 1, action: .recordMeeting(.delegate(.saveMeeting(transcript: transcript))))))
        await store.receive(.path(.popFrom(id: 1)))
        store.assert {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?.standup.meetings = [
                Meeting(
                    id: UUID(0),
                    date: date,
                    transcript: transcript
                )
            ]
            XCTAssertEqual($0.path.count, 1)
        }
    }

    
    func testEndMeetingEarlyDicard() async {
        let standup = Standup(
            id: UUID(),
            attendees: [Attendee(id: UUID())],
            duration: .seconds(1),
            meetings: [],
            theme: .bubblegum,
            title: "Talento"
        )
                
        let store = TestStore(
            initialState: AppFeature.State(
                path: StackState([
                    .detail(
                        StandupDetailFeature.State(standup: standup)
                    ),
                    .recordMeeting(
                        RecordMeetingFeature.State(standup: standup)
                    )
                ]),
                standupsList: StandupsListFeature.State()
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.speechClient.requestAuthorization = { false }
            $0.dataManager = .mock(initialData: try? JSONEncoder().encode([standup]))
        }
        store.exhaustivity = .off
        
        await store.send(.path(.element(id: 1, action: .recordMeeting(.onTask))))
        await store.send(.path(.element(id: 1, action: .recordMeeting(.endMeetingButtonTapped))))
        await store.send(.path(.element(id: 1, action: .recordMeeting(.alert(.presented(.confirmDiscard))))))
        await store.skipReceivedActions()
        
        store.assert {
            $0.path[id: 0, case: /AppFeature.Path.State.detail]?.standup.meetings = []
            XCTAssertEqual($0.path.count, 1)
        }
    }
    
    func testAdd() async {
        let store = TestStore(
            initialState: AppFeature.State(
                standupsList: StandupsListFeature.State()
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.continuousClock = ImmediateClock()
            $0.dataManager = .mock()
        }
        store.exhaustivity = .off
        
        await store.send(.standupsList(.addButtonTapped))
        await store.send(.standupsList(.saveStandupButtonTapped))
        store.assert {
            $0.standupsList.standups = [
                Standup(
                    id: UUID(0),
                    attendees: [Attendee(id: UUID(1))]
                )
            ]
        }
    }
}
