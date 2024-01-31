//
//  RecordMeeting.swift
//  StandupsTCA
//
//  Created by Daniel Personal on 4/11/23.
//

import ComposableArchitecture
import Speech
import SwiftUI

@Reducer
struct RecordMeetingFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?
        var secondsElapsed = 0
        var speakerIndex = 0
        let standup: Standup
        var transcript = ""
        
        var durationRemaining: Duration {
            standup.duration - .seconds(secondsElapsed)
        }
    }
    enum Action: Equatable {
        case alert(PresentationAction<Alert>)
        case nextButtonTapped
        case endMeetingButtonTapped
        case onTask
        case speechResult(String)
        case timerTicked
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case saveMeeting(transcript: String)
        }
        
        enum Alert {
            case confirmDiscard
            case confirmSave
        }
    }
    
    @Dependency(\.continuousClock) var clock
    @Dependency(\.speechClient) var speechClient
    @Dependency(\.dismiss) var dismiss
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .endMeetingButtonTapped:
                state.alert = .endMeeting(isDiscardable: true)
                return .none
                
            case .nextButtonTapped:
                guard state.speakerIndex < state.standup.attendees.count - 1 else {
                    state.alert = .endMeeting(isDiscardable: false)
                    return .none
                }
                state.speakerIndex += 1
                state.secondsElapsed += Int(
                    state.standup.durationPerAttendee.components.seconds
                )
                return .none
                
            case .onTask:
                return .run { send in
                    await onTask(send: send)
                }
                
            case let .speechResult(transcript):
                state.transcript = transcript
                return .none
                
            case .timerTicked:
                guard state.alert == nil else { return .none }
                
                state.secondsElapsed += 1
                let secondsPerAttendee = Int(
                    state.standup.durationPerAttendee.components.seconds
                )
                if state.secondsElapsed.isMultiple(of: secondsPerAttendee) {
                    if state.speakerIndex == state.standup.attendees.count - 1 {
                        return .run { [transcript = state.transcript] send in
                            await send(.delegate(.saveMeeting(transcript: transcript)))
                            await dismiss()
                        }
                    }
                    state.speakerIndex += 1
                }
                return .none
                
            case .delegate:
                return .none
                
            case .alert(.presented(.confirmDiscard)):
                return .run { _ in await dismiss() }
                
            case .alert(.presented(.confirmSave)):
                return .run { [transcript = state.transcript] send in
                    await send(.delegate(.saveMeeting(transcript: transcript)))
                    await dismiss()
                }
                
            case .alert(.dismiss):
                return .none
            }
        }
        .ifLet(\.alert, action: /Action.alert)
    }
    
    private func onTask(send: Send<Action>) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                guard await speechClient.requestAuthorization() else {
                    return
                }

                do {
                    for try await transcript in speechClient.start() {
                        await send(.speechResult(transcript))
                    }
                } catch {
                    
                }
            }
            group.addTask {
                for await _ in self.clock.timer(interval: .seconds(1)) {
                    await send(.timerTicked)
                }
            }
        }
    }
}

extension AlertState where Action == RecordMeetingFeature.Action.Alert {
    static func endMeeting(isDiscardable: Bool) -> Self {
        Self {
            TextState("End meeting?")
        } actions: {
            ButtonState(action: .confirmSave) {
                TextState("Save and end")
            }
            if isDiscardable {
                ButtonState(action: .confirmDiscard) {
                    TextState("Discard")
                }
            }
            ButtonState(role: .cancel) {
                TextState("Resume")
            }
        } message: {
            TextState("You are ending the meeting early. What do you like to do?")
        }
    }
}

struct RecordMeetingView: View {
    let store: StoreOf<RecordMeetingFeature>
    
    var body: some View {
        WithPerceptionTracking {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(store.standup.theme.mainColor)
                
                VStack {
                    MeetingHeaderView(
                        secondsElapsed: store.secondsElapsed,
                        durationRemaining: store.durationRemaining,
                        theme: store.standup.theme
                    )
                    MeetingTimerView(
                        standup: store.standup,
                        speakerIndex: store.speakerIndex
                    )
                    MeetingFooterView(
                        standup: store.standup,
                        nextButtonTapped: {
                            store.send(.nextButtonTapped)
                        },
                        speakerIndex: store.speakerIndex
                    )
                }
            }
            .padding()
            .foregroundColor(store.standup.theme.accentColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End meeting") {
                        store.send(.endMeetingButtonTapped)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .task {
                await store.send(.onTask).finish()
            }
            .alert(
                store: store.scope(
                    state: \.$alert,
                    action: \.alert
                )
            )
        }
    }
}

struct MeetingHeaderView: View {
    let secondsElapsed: Int
    let durationRemaining: Duration
    let theme: Theme
    
    var body: some View {
        VStack {
            ProgressView(value: self.progress)
                .progressViewStyle(
                    MeetingProgressViewStyle(theme: self.theme)
                )
            HStack {
                VStack(alignment: .leading) {
                    Text("Time Elapsed")
                        .font(.caption)
                    Label(
                        Duration.seconds(self.secondsElapsed)
                            .formatted(.units()),
                        systemImage: "hourglass.bottomhalf.fill"
                    )
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Time Remaining")
                        .font(.caption)
                    Label(
                        durationRemaining.formatted(.units()),
                        systemImage: "hourglass.tophalf.fill"
                    )
                    .font(.body.monospacedDigit())
                    .labelStyle(.trailingIcon)
                }
            }
        }
        .padding([.top, .horizontal])
    }
    
    private var totalDuration: Duration {
        .seconds(secondsElapsed) + durationRemaining
    }
    
    private var progress: Double {
        guard self.totalDuration > .seconds(0) else { return 0 }
        return Double(self.secondsElapsed) / Double(self.totalDuration.components.seconds)
    }
}

struct MeetingProgressViewStyle: ProgressViewStyle {
    var theme: Theme
    
    func makeBody(
        configuration: Configuration
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accentColor)
                .frame(height: 20)
            
            ProgressView(configuration)
                .tint(theme.mainColor)
                .frame(height: 12)
                .padding(.horizontal)
        }
    }
}

struct MeetingTimerView: View {
    let standup: Standup
    let speakerIndex: Int
    
    var body: some View {
        Circle()
            .strokeBorder(lineWidth: 24)
            .overlay {
                VStack {
                    Group {
                        if speakerIndex
                            < standup.attendees.count {
                            Text(
                                self.standup.attendees[speakerIndex]
                                    .name
                            )
                        } else {
                            Text("Someone")
                        }
                    }
                    .font(.title)
                    Text("is speaking")
                    Image(systemName: "mic.fill")
                        .font(.largeTitle)
                        .padding(.top)
                }
                .foregroundStyle(standup.theme.accentColor)
            }
            .overlay {
                ForEach(
                    Array(standup.attendees.enumerated()),
                    id: \.element.id
                ) { index, attendee in
                    if index < speakerIndex + 1 {
                        SpeakerArc(
                            totalSpeakers: standup.attendees.count,
                            speakerIndex: index
                        )
                        .rotation(Angle(degrees: -90))
                        .stroke(
                            standup.theme.mainColor, lineWidth: 12
                        )
                    }
                }
            }
            .padding(.horizontal)
    }
}

struct SpeakerArc: Shape {
    let totalSpeakers: Int
    let speakerIndex: Int
    
    func path(in rect: CGRect) -> Path {
        let diameter = min(
            rect.size.width, rect.size.height
        ) - 24
        let radius = diameter / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
    }
    
    private var degreesPerSpeaker: Double {
        360 / Double(totalSpeakers)
    }
    private var startAngle: Angle {
        Angle(
            degrees: degreesPerSpeaker
            * Double(speakerIndex)
            + 1
        )
    }
    private var endAngle: Angle {
        Angle(
            degrees: startAngle.degrees
            + degreesPerSpeaker
            - 1
        )
    }
}

struct MeetingFooterView: View {
    let standup: Standup
    var nextButtonTapped: () -> Void
    let speakerIndex: Int
    
    var body: some View {
        VStack {
            HStack {
                if speakerIndex
                    < standup.attendees.count - 1 {
                    Text(
            """
            Speaker \(speakerIndex + 1) \
            of \(standup.attendees.count)
            """
                    )
                } else {
                    Text("No more speakers.")
                }
                Spacer()
                Button(action: nextButtonTapped) {
                    Image(systemName: "forward.fill")
                }
            }
        }
        .padding([.bottom, .horizontal])
    }
}

#Preview {
    NavigationStack {
        RecordMeetingView(
            store: Store(initialState: RecordMeetingFeature.State(standup: .mock)) {
                RecordMeetingFeature()
            }
        )
    }
}
