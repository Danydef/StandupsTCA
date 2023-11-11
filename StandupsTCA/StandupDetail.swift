//
//  StandupDetail.swift
//  StandupsTCA
//
//  Created by Daniel Jimenez on 30/10/23.
//

import ComposableArchitecture
import SwiftUI

struct StandupDetailFeature: Reducer {
    struct State: Equatable {
        @PresentationState var destination: Destination.State?
        var standup: Standup
    }
    
    enum Action: Equatable {
        case delegate(Delegate)
        case deleteButtonTapped
        case deleteMeetings(atOffsets: IndexSet)
        case destination(PresentationAction<Destination.Action>)
        case editButtonTapped
        case cancelEditStandupButtonTapped
        case saveStandupButtonTapped
        
        enum Alert {
            case confirmDeletion
        }
        
        enum Delegate: Equatable {
            case deleteStandup(id: Standup.ID)
            case sandupUpdated(Standup)
        }
    }
    
    struct Destination: Reducer {
        enum State: Equatable {
            case alert(AlertState<Action.Alert>)
            case editStandup(StandupFormFeature.State)
        }
        enum Action: Equatable {
            case alert(Alert)
            case editStandup(StandupFormFeature.Action)
            
            enum Alert {
                case confirmDeletion
            }
        }
        
        var body: some ReducerOf<Self> {
            Scope(state: /State.editStandup, action: /Action.editStandup) {
                StandupFormFeature()
            }
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case .deleteButtonTapped:
                state.destination = .alert(AlertState {
                    TextState("Are you sure you want to delete this standup?")
                    } actions: {
                        ButtonState(
                            role: .destructive, action: .confirmDeletion
                        ) {
                            TextState("Delete")
                        }
                    }
                )
                return .none
                
            case .delegate:
                return .none
                
            case let .deleteMeetings(atOffsets: indices):
                state.standup.meetings.remove(atOffsets: indices)
                return .none
                
            case .editButtonTapped:
                state.destination = .editStandup(StandupFormFeature.State(standup: state.standup))
                return .none
                
            case .destination(.dismiss):
                return .none
                
            case .cancelEditStandupButtonTapped:
                state.destination = nil
                return .none
                
            case .saveStandupButtonTapped:
                guard case let .editStandup(standupForm) = state.destination else {
                    return .none
                }
                state.standup = standupForm.standup
                state.destination = nil
                return .none
                
            case .destination(.presented(.alert(.confirmDeletion))):
                 return .run { [id = state.standup.id] send in
                    await send(.delegate(.deleteStandup(id: id)))
                    await dismiss()
                }
                
            case .destination:
                return .none
            }
            
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
        .onChange(of: \.standup) { _, newValue in
            Reduce { _, _ in
                .send(.delegate(.sandupUpdated(newValue)))
            }
        }
    }
}

struct StandupDetailView: View {
    let store: StoreOf<StandupDetailFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            List {
                Section {
                    NavigationLink(
                        state: AppFeature.Path.State.recordMeeting(
                            RecordMeetingFeature.State(standup: viewStore.standup)
                        )
                    ) {
                        Label("Start Meeting", systemImage: "timer")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    HStack {
                        Label("Length", systemImage: "clock")
                        Spacer()
                        Text(viewStore.standup.duration.formatted(.units()))
                    }
                    
                    HStack {
                        Label("Theme", systemImage: "paintpalete")
                        Spacer()
                        Text(viewStore.standup.theme.name)
                            .padding(4)
                            .foregroundColor(viewStore.standup.theme.accentColor)
                            .background(viewStore.standup.theme.mainColor)
                            .cornerRadius(4)
                        
                    }
                } header: {
                    Text("Standup Info")
                }
                
                if !viewStore.standup.meetings.isEmpty {
                    Section {
                        ForEach(viewStore.standup.meetings) { meeting in
                            NavigationLink(
                                state: AppFeature.Path.State.meeting(
                                    meeting,
                                    standup: viewStore.standup
                                )
                            ) {
                                HStack {
                                    Image(systemName: "calendar")
                                    Text(meeting.date, style: .date)
                                    Text(meeting.date, style: .time)
                                }
                            }
                        }
                        .onDelete{ indices in
                            viewStore.send(.deleteMeetings(atOffsets: indices))
                        }
                    } header: {
                        Text("Past mettings")
                    }
                }
                
                Section {
                    ForEach(viewStore.standup.attendees) { attendee in
                        Label(attendee.name, systemImage: "person")
                    }
                } header: {
                    Text("Attendees")
                }
                
                Section {
                    Button("Delete") {
                        viewStore.send(.deleteButtonTapped)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(viewStore.standup.title)
            .toolbar {
                Button("Edit") {
                    viewStore.send(.editButtonTapped)
                }
            }
            .alert(
                store: store.scope(state: \.$destination, action: { .destination($0) }),
                state: /StandupDetailFeature.Destination.State.alert,
                action: StandupDetailFeature.Destination.Action.alert
            )
            .sheet(
                store: store.scope(state: \.$destination, action: { .destination($0) }),
                state: /StandupDetailFeature.Destination.State.editStandup,
                action: StandupDetailFeature.Destination.Action.editStandup
            ) { store in
                NavigationView {
                    StandupFormView(store: store)
                        .navigationTitle("Edit standup")
                        .toolbar {
                            ToolbarItem {
                                Button("Save") {
                                    viewStore.send(.saveStandupButtonTapped)
                                }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    viewStore.send(.cancelEditStandupButtonTapped)
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StandupDetailView(
            store: Store(
                initialState: StandupDetailFeature.State(
                    standup: .mock
                )
            ) {
                StandupDetailFeature()
                    ._printChanges()
            }
        )
    }
}
