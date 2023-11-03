//
//  AppView.swift
//  StandupsTCA
//
//  Created by Daniel Personal on 31/10/23.
//

import ComposableArchitecture
import SwiftUI

struct AppFeature: Reducer {
    struct State: Equatable {
        var path = StackState<Path.State>()
        var standupsList = StandupsListFeature.State()
    }
    enum Action: Equatable {
        case path(StackAction<Path.State, Path.Action>)
        case standupsList(StandupsListFeature.Action)
    }
    
    struct Path: Reducer {
        enum State: Equatable {
            case detail(StandupDetailFeature.State)
        }
        enum Action: Equatable {
            case detail(StandupDetailFeature.Action)
        }
        
        var body: some ReducerOf<Self> {
            Scope(state: /State.detail, action: /Action.detail) {
                StandupDetailFeature()
            }
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(
            state: \.standupsList,
            action: /Action.standupsList
        ) {
            StandupsListFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .path(.element(id: _, action: .detail(.delegate(action)))):
                switch action {
                case let .sandupUpdated(standup):
                    state.standupsList.standups[id: standup.id] = standup
                    return .none
                }
                
            case .path:
                return .none
                
            case .standupsList:
                return .none
            }
        }
        .forEach(\.path, action: /Action.path) {
            Path()
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>
    var body: some View {
        NavigationStackStore(
            store.scope(state: \.path, action: { .path($0) })
        ) {
            StandupsListView(
                store: store.scope(
                    state: \.standupsList,
                    action: { .standupsList($0) }
                )
            )
        } destination: { state in
            switch state {
            case .detail:
                CaseLet(
                    /AppFeature.Path.State.detail,
                     action: AppFeature.Path.Action.detail,
                     then: { store in
                         StandupDetailView(store: store)
                     }
                )
            }
        }
    }
}

#Preview {
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
