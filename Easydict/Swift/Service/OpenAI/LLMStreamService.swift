//
//  LLMStreamService.swift
//  Easydict
//
//  Created by tisfeng on 2024/5/20.
//  Copyright © 2024 izual. All rights reserved.
//

import Combine
import Defaults
import Foundation

// MARK: - LLMStreamService

@objcMembers
@objc(EZLLMStreamService)
public class LLMStreamService: QueryService, ObservableObject {
    // MARK: Public

    public override func isStream() -> Bool {
        true
    }

    public override func intelligentQueryTextType() -> EZQueryTextType {
        Configuration.shared.intelligentQueryTextTypeForServiceType(serviceType())
    }

    public override func supportLanguagesDictionary() -> MMOrderedDictionary<AnyObject, AnyObject> {
        let allLanguages = EZLanguageManager.shared().allLanguages
        let supportedLanguages = allLanguages.filter { language in
            !unsupportedLanguages.contains(language)
        }

        let orderedDict = MMOrderedDictionary<AnyObject, AnyObject>()
        for language in supportedLanguages {
            orderedDict.setObject(language.rawValue as NSString, forKey: language.rawValue as NSString)
        }
        return orderedDict
    }

    public override func queryTextType() -> EZQueryTextType {
        var typeOptions: EZQueryTextType = []

        let isTranslationEnabled = Defaults[translationKey].boolValue
        let isSentenceEnabled = Defaults[sentenceKey].boolValue
        let isDictionaryEnabled = Defaults[dictionaryKey].boolValue

        if isTranslationEnabled {
            typeOptions.insert(.translation)
        }
        if isSentenceEnabled {
            typeOptions.insert(.sentence)
        }
        if isDictionaryEnabled {
            typeOptions.insert(.dictionary)
        }

        return typeOptions
    }

    public override func serviceUsageStatus() -> EZServiceUsageStatus {
        let usageStatus = Defaults[serviceUsageStatusKey]
        guard let value = UInt(usageStatus.rawValue) else { return .default }
        return EZServiceUsageStatus(rawValue: value) ?? .default
    }

    // MARK: Internal

    let throttler = Throttler()

    let mustOverride = "This property or method must be overridden by a subclass"

    var cancellables: Set<AnyCancellable> = []

    var unsupportedLanguages: [Language] {
        []
    }

    var model: String {
        get { Defaults[modelKey] }
        set {
            if model != newValue {
                Defaults[modelKey] = newValue
            }
        }
    }

    var modelKey: Defaults.Key<String> {
        stringDefaultsKey(.model)
    }

    var supportedModels: String {
        get { Defaults[supportedModelsKey] }
        set {
            if supportedModels != newValue {
                Defaults[supportedModelsKey] = newValue
            }
        }
    }

    var supportedModelsKey: Defaults.Key<String> {
        stringDefaultsKey(.supportedModels)
    }

    var validModels: [String] {
        supportedModels.components(separatedBy: ",")
            .map { $0.trim() }.filter { !$0.isEmpty }
    }

    var validModelsKey: Defaults.Key<[String]> {
        serviceDefaultsKey(.validModels, defaultValue: [""])
    }

    var apiKey: String {
        Defaults[apiKeyKey]
    }

    var apiKeyKey: Defaults.Key<String> {
        stringDefaultsKey(.apiKey)
    }

    var endpoint: String {
        Defaults[endpointKey]
    }

    var endpointKey: Defaults.Key<String> {
        stringDefaultsKey(.endpoint)
    }

    var nameKey: Defaults.Key<String> {
        stringDefaultsKey(.name)
    }

    var translationKey: Defaults.Key<String> {
        stringDefaultsKey(.translation)
    }

    var sentenceKey: Defaults.Key<String> {
        stringDefaultsKey(.sentence)
    }

    var dictionaryKey: Defaults.Key<String> {
        stringDefaultsKey(.dictionary)
    }

    var serviceUsageStatusKey: Defaults.Key<ServiceUsageStatus> {
        serviceDefaultsKey(.serviceUsageStatus, defaultValue: .default)
    }

    /// Base on chat query, convert prompt dict to LLM service prompt model.
    func serviceChatMessageModels(_ chatQuery: ChatQueryParam)
        -> [Any] {
        fatalError(mustOverride)
    }

    func getFinalResultText(_ text: String) -> String {
        var resultText = text.trim()

        // Remove last </s>, fix Groq model mixtral-8x7b-32768
        let stopFlag = "</s>"
        if !queryModel.queryText.hasSuffix(stopFlag), resultText.hasSuffix(stopFlag) {
            resultText = String(resultText.dropLast(stopFlag.count)).trim()
        }

        // Since it is more difficult to accurately remove redundant quotes in streaming, we wait until the end of the request to remove the quotes
        let nsText = resultText as NSString
        resultText = nsText.tryToRemoveQuotes().trim()

        return resultText
    }

    /// Get query type by text and from && to language.
    func queryType(text: String, from: Language, to: Language) -> EZQueryTextType {
        let enableDictionary = queryTextType().contains(.dictionary)
        var isQueryDictionary = false
        if enableDictionary {
            isQueryDictionary = (text as NSString).shouldQueryDictionary(withLanguage: from, maxWordCount: 2)
            if isQueryDictionary {
                return .dictionary
            }
        }

        let enableSentence = queryTextType().contains(.sentence)
        var isQueryEnglishSentence = false
        if !isQueryDictionary, enableSentence {
            let isEnglishText = from == .english
            if isEnglishText {
                isQueryEnglishSentence = (text as NSString).shouldQuerySentence(withLanguage: from)
                if isQueryEnglishSentence {
                    return .sentence
                }
            }
        }

        return .translation
    }

    /// Cancel stream request manually.
    func cancelStream() {}
}

extension LLMStreamService {
    func updateResultText(
        _ resultText: String?,
        queryType: EZQueryTextType,
        error: Error?,
        completion: @escaping (EZQueryResult, Error?) -> ()
    ) {
        if result.isStreamFinished {
            cancelStream()
            return
        }

        var translatedTexts: [String]?
        if let resultText {
            translatedTexts = [resultText.trim()]
        }

        result.isStreamFinished = error != nil
        result.translatedResults = translatedTexts

        let updateCompletion = {
            self.throttler.throttle { [weak self] in
                guard let self else { return }

                completion(result, error)
            }
        }

        switch queryType {
        case .dictionary:
            if error != nil {
                result.showBigWord = false
                result.translateResultsTopInset = 0
                updateCompletion()
                return
            }

            result.showBigWord = true
            result.queryText = queryModel.queryText
            result.translateResultsTopInset = 6
            updateCompletion()

        default:
            updateCompletion()
        }
    }
}

// MARK: - ChatQueryParam

struct ChatQueryParam {
    let text: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let queryType: EZQueryTextType
    let enableSystemPrompt: Bool

    func unpack() -> (String, Language, Language, EZQueryTextType, Bool) {
        (text, sourceLanguage, targetLanguage, queryType, enableSystemPrompt)
    }
}
