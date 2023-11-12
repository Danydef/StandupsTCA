//
//  DataManager.swift
//  StandupsTCA
//
//  Created by Daniel Personal on 11/11/23.
//

import Foundation

struct DataManager: Sendable {
    var load: @Sendable (URL) throws -> Data
    var save: @Sendable (Data, URL) throws -> Void
}

import Dependencies

extension DataManager: DependencyKey {
    static let liveValue = Self(
        load: { url in try Data(contentsOf: url) },
        save: { data, url in try data.write(to: url) }
    )
    
    static let previewValue = mock()
    
    static let failToWrite = Self(
        load: { _ in Data() },
        save: { _, _ in
            struct SaveError: Error {}
            throw SaveError()
        }
    )
    
    static let failToLoad = Self(
        load: { _ in
            struct LoadError: Error {}
            throw LoadError()
        }, 
        save: { _, _ in }
    )
    
    static func mock(initialData: Data? = nil) -> Self {
        let data = LockIsolated(initialData)
        return Self(
            load: { _ in
                guard let data = data.value else {
                    struct FileNotFound: Error {}
                    throw FileNotFound()
                }
                return data
            },
            save: { newData, _ in data.setValue(newData) }
        )
    }
}

extension DependencyValues {
    var dataManager: DataManager {
        get { self[DataManager.self] }
        set { self[DataManager.self] = newValue }
    }
}
