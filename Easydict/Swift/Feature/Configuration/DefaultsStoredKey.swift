//
//  DefaultsStoredKey.swift
//  Easydict
//
//  Created by tisfeng on 2024/4/28.
//  Copyright © 2024 izual. All rights reserved.
//

import Foundation

func storedKey(_ key: StoredKey, serviceType: ServiceType) -> String {
    // This key should be compatible with existing OpenAI config keys
    // EZOpenAIServiceUsageStatusKey
    // EZOpenAIDictionaryKey
    "EZ" + serviceType.rawValue + key.rawValue.capitalizeFirstLetter() + "Key"
}

extension UserDefaults {
    static func bool(forKey key: StoredKey, serviceType: ServiceType) -> Bool {
        let key = storedKey(key, serviceType: serviceType)
        let value = standard.bool(forKey: key)
        return value
    }

    static func string(forKey key: StoredKey, serviceType: ServiceType) -> String? {
        let key = storedKey(key, serviceType: serviceType)
        let value = standard.string(forKey: key)
        return value
    }
}

// MARK: - StoredKey

enum StoredKey: String {
    case serviceUsageStatus
    case translation
    case dictionary
    case sentence
    case availableModels // save in String
    case validModels // save in [String]
    case model
    case apiKey = "API"
    case endpoint = "EndPoint"
    case name
}

extension String {
    func capitalizeFirstLetter() -> String {
        prefix(1).uppercased() + dropFirst()
    }
}
