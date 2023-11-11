//
//  Meeting.swift
//  StandupsTCA
//
//  Created by Daniel Personal on 9/11/23.
//

import SwiftUI

struct MeetingView: View {
    let meeting: Meeting
    let standup: Standup
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Divider()
                    .padding(.bottom)
                Text("Attendees")
                    .font(.headline)
                ForEach(standup.attendees) { attendee in
                    Text(attendee.name)
                }
                Text("Transcript:")
                    .font(.headline)
                    .padding(.top)
                Text(meeting.transcript)
            }
        }
        .navigationTitle(Text(meeting.date, style: .date))
        .padding()
    }
}
