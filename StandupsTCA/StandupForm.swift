//
//  StandupForm.swift
//  StandupsTCA
//
//  Created by Daniel Personal on 13/10/23.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct StandupFormFeature {
    @ObservableState
    struct State: Equatable {
        var focus: Field?
        var standup: Standup
        
        enum Field: Hashable {
            case attendee(Attendee.ID)
            case title
        }
        
        init(focus: Field? = .title, standup: Standup) {
            self.focus = focus
            self.standup = standup
            if self.standup.attendees.isEmpty {
                @Dependency(\.uuid) var uuid
                self.standup.attendees.append(Attendee(id: uuid()))
            }
        }
    }
    enum Action: BindableAction, Equatable {
        case addAttendeeButtonTapped
        case binding(BindingAction<State>)
        case deleteAttendees(atOffsets: IndexSet)
    }
    
    @Dependency(\.uuid) var uuid
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .addAttendeeButtonTapped:
                let id = uuid()
                let attendee = Attendee(id: id)
                state.standup.attendees.append(attendee)
                state.focus = .attendee(id)
                return .none
                
            case .binding:
                return .none
                
            case let .deleteAttendees(atOffsets: indices):
                state.standup.attendees.remove(atOffsets: indices)
                if state.standup.attendees.isEmpty {
                    state.standup.attendees.append(
                        Attendee(id: uuid())
                    )
                }
                guard let firstIndex = indices.first else {
                    return .none
                }
                let index = min(firstIndex, state.standup.attendees.count - 1)
                state.focus = .attendee(state.standup.attendees[index].id)
                return.none
            }
        }
    }
}

struct StandupFormView: View {
    @BindableStore var store: StoreOf<StandupFormFeature>
    @FocusState var focus: StandupFormFeature.State.Field?
    
    var body: some View {
        WithPerceptionTracking {
            Form {
                Section {
                    TextField("Title", text: $store.standup.title)
                        .focused($focus, equals: .title)
                    HStack {
                        Slider(value: $store.standup.duration.minutes, in: 5...30, step: 1) {
                            Text("Length")
                        }
                        Spacer()
                        Text(store.standup.duration.formatted(.units()))
                    }
                    ThemePicker(selection: $store.standup.theme)
                } header: {
                    Text("Standup Info")
                }
                Section {
                    ForEach($store.standup.attendees) { $attendee in
                        TextField("Name", text: $attendee.name)
                            .focused(self.$focus, equals: .attendee(attendee.id))
                    }
                    .onDelete { indices in
                        store.send(.deleteAttendees(atOffsets: indices))
                    }
                    
                    Button("Add attendee") {
                        store.send(.addAttendeeButtonTapped)
                    }
                } header: {
                    Text("Attendees")
                }
            }
            .bind($store.focus, to: $focus)
        }
    }
}

extension Duration {
    var minutes: Double {
        get { Double(components.seconds / 60) }
        set { self = .seconds(newValue * 60) }
    }
}

struct ThemePicker: View {
  @Binding var selection: Theme

  var body: some View {
    Picker("Theme", selection: self.$selection) {
      ForEach(Theme.allCases) { theme in
        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(theme.mainColor)
          Label(theme.name, systemImage: "paintpalette")
            .padding(4)
        }
        .foregroundColor(theme.accentColor)
        .fixedSize(horizontal: false, vertical: true)
        .tag(theme)
      }
    }
  }
}

#Preview {
    NavigationStack {
      StandupFormView(
        store: Store(initialState: StandupFormFeature.State(standup: .mock)) {
            StandupFormFeature()
        }
      )
    }
}
