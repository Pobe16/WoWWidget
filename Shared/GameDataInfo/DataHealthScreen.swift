//
//  DataHealthScreen.swift
//  WoWWidget (iOS)
//
//  Created by Mikolaj Lukasik on 19/08/2020.
//

import SwiftUI

struct DataHealthScreen: View {
    @EnvironmentObject var authorization: Authentication
    @EnvironmentObject var gameData: GameData
    @State var gameDataCreationDate: String = "Loading"
    @State var timeRetries: Int = 0
    @State var connectionRetries: Int = 0
    
    var body: some View {
        ScrollView(Axis.Set.vertical, showsIndicators: true) {
            VStack{
                if gameData.expansions.count > 0 {
                    ForEach(gameData.expansions){ expansion in
                        ExpansionGameDataPreview( expansion: expansion )
                    }
                } else {
                    EmptyView()
                }
                Text("Last refreshed: \(gameDataCreationDate)")
                Spacer(minLength: 20)

            }
            
        }
        .onAppear(perform: {
            checkDataCreationDate()
        })
        .toolbar{
            ToolbarItem(placement: .principal) {
                Text("Expansions")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if gameData.loadingAllowed {
                    Button {
                        deleteDataBeforeUpdating()
                    } label: {
                        Text("Refresh!")
                    }
                } else {
                    ProgressView(
                        value: Double(gameData.downloadedItems),
                        total: Double(max(gameData.estimatedItemsToDownload, gameData.actualItemsToDownload))
                        
                    )
                    .frame(width: 80)
                }
            }
        }
        
    }
    
    func checkDataCreationDate(){
        let requestUrlAPIHost = UserDefaults.standard.object(forKey: "APIRegionHost") as? String ?? APIRegionHostList.Europe
        let requestUrlAPIFragment = "/data/wow/journal-expansion/index"
        
        if let savedData = JSONCoreDataManager.shared.fetchJSONData(withName: requestUrlAPIHost + requestUrlAPIFragment, maximumAgeInDays: 90) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
//            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: savedData.creationDate!)
            gameDataCreationDate = dateString
        } else {
            gameDataCreationDate = "Nothing saved"
        }
    }
    
    func deleteDataBeforeUpdating() {
        DispatchQueue.main.async {
            gameData.expansionsStubs.removeAll()
            gameData.raidsStubs.removeAll()
            gameData.dungeonsStubs.removeAll()
            gameData.downloadedItems = 1
            gameData.actualItemsToDownload = 0
            
            withAnimation {
                gameData.expansions.removeAll()
                gameData.raids.removeAll()
                gameData.dungeons.removeAll()
                
            }
            loadExpansionIndex()
        }
    }
    
    func loadExpansionIndex() {
        
        if gameData.expansions.count == 0 && gameData.loadingAllowed {
            withAnimation {
                gameData.loadingAllowed = false
            }
            let requestUrlAPIHost = UserDefaults.standard.object(forKey: "APIRegionHost") as? String ?? APIRegionHostList.Europe
            let requestUrlAPIFragment = "/data/wow/journal-expansion/index"
            
            let regionShortCode = APIRegionShort.Code[UserDefaults.standard.integer(forKey: "loginRegion")]
            let requestAPINamespace = "static-\(regionShortCode)"
            let requestLocale = UserDefaults.standard.object(forKey: "localeCode") as? String ?? EuropeanLocales.BritishEnglish
            
            let fullRequestURL = URL(string:
                                        requestUrlAPIHost +
                                        requestUrlAPIFragment +
                                        "?namespace=\(requestAPINamespace)" +
                                        "&locale=\(requestLocale)" +
                                        "&access_token=\(authorization.oauth2?.accessToken ?? "")"
            )!
            
            
            guard let req = authorization.oauth2?.request(forURL: fullRequestURL) else { return }
            
            let task = authorization.oauth2?.session.dataTask(with: req) { data, response, error in
                if let data = data {
                    decodeExpansionIndexData(data, fromURL: fullRequestURL)
                }
                if let error = error {
                    // something went wrong, check the error
                    print("error")
                    print(error.localizedDescription)
                }
            }
            task?.resume()
        }
    }
    
    func decodeExpansionIndexData(_ data: Data, fromURL url: URL? = nil) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let dataResponse = try decoder.decode(ExpansionTop.self, from: data)
            print(dataResponse.tiers.count)
            
            if let url = url {
                JSONCoreDataManager.shared.saveJSON(data, withURL: url)
            }
            DispatchQueue.main.async {
                gameData.expansionsStubs = dataResponse.tiers
                gameData.actualItemsToDownload += dataResponse.tiers.count
                loadExpansionJournal()
            }
            
            
        } catch {
            print(error)
        }
    }
    
    func loadExpansionJournal() {
        
        if timeRetries > 5 || connectionRetries > 5 {
            print("Failed after \(timeRetries) timer retries, and or \(connectionRetries) connection errors")
            return
        }
        
        guard let stub = gameData.expansionsStubs.first else {
            if gameData.expansions.count > 0 {
                print("finished loading expansions")
                print("loaded \(gameData.expansions.count) expansions")
                DispatchQueue.main.async {
                    withAnimation {
                        gameData.expansions.sort()
                        gameData.actualItemsToDownload += gameData.raidsStubs.count
                        gameData.actualItemsToDownload += gameData.dungeonsStubs.count
                    }
                }
                
                loadRaidsInfo()
                return
            }
            timeRetries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("data saving problem - retrying in 1s")
                loadExpansionJournal()
            }
            return
        }
        
        let requestLocale = UserDefaults.standard.object(forKey: "localeCode") as? String ?? EuropeanLocales.BritishEnglish
        let accessToken = authorization.oauth2?.accessToken ?? ""
        
        let requestUrlAPIHost = "\(stub.key.href)"
        
        let fullRequestURL = URL(string:
                                    requestUrlAPIHost +
                                    "&locale=\(requestLocale)" +
                                    "&access_token=\(accessToken)"
        )!
        
        
        guard let req = authorization.oauth2?.request(forURL: fullRequestURL) else { return }
        
        let task = authorization.oauth2?.session.dataTask(with: req) { data, response, error in
            if let data = data {
                timeRetries = 0
                connectionRetries = 0
                
                decodeExpansionJournalData(data, fromURL: fullRequestURL)
                
            }
            if let error = error {
                // something went wrong, check the error
                print("error")
                print(error.localizedDescription)
                connectionRetries += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    loadExpansionJournal()
                }
            }
        }
        task?.resume()
        
        
    }
    
    func decodeExpansionJournalData(_ data: Data, fromURL url: URL? = nil) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let dataResponse = try decoder.decode(ExpansionJournal.self, from: data)
            
            if let url = url {
                JSONCoreDataManager.shared.saveJSON(data, withURL: url)
            }
                
            DispatchQueue.main.async {
                
                withAnimation {
                    gameData.expansions.append(dataResponse)
                    gameData.downloadedItems += 1
                }
                
                gameData.raidsStubs.append(contentsOf: dataResponse.raids ?? [])
                gameData.dungeonsStubs.append(contentsOf: dataResponse.dungeons ?? [])
                
                if gameData.expansionsStubs.count > 0 {
                    gameData.expansionsStubs.removeFirst()
                }
                
                loadExpansionJournal()
            }
            
            
        } catch {
            print(error)
        }
    }
    
    func loadRaidsInfo(){
        if timeRetries > 5 || connectionRetries > 5 {
            print("Failed after \(timeRetries) timer retries, and or \(connectionRetries) connection errors")
            return
        }
        guard let currentRaidToLoad = gameData.raidsStubs.first else {
            if gameData.raids.count > 0 {
                print("finished loading raids")
                print("loaded \(gameData.raids.count) raids")
                
                DispatchQueue.main.async {
                    withAnimation {
                        gameData.raids.sort()
                    }
                    loadDungeonsInfo()
                }
                return
            }
            timeRetries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                loadRaidsInfo()
            }
            return
        }
        
        let requestUrlAPIHost = "\(currentRaidToLoad.key.href)"
        
        let requestLocale = UserDefaults.standard.object(forKey: "localeCode") as? String ?? EuropeanLocales.BritishEnglish
        let accessToken = authorization.oauth2?.accessToken ?? ""
        
        let fullRequestURL = URL(string:
                                    requestUrlAPIHost +
                                    "&locale=\(requestLocale)" +
                                    "&access_token=\(accessToken)"
        )!
        
        
        guard let req = authorization.oauth2?.request(forURL: fullRequestURL) else { return }
        
        let task = authorization.oauth2?.session.dataTask(with: req) { data, response, error in
            if let data = data {
                timeRetries = 0
                connectionRetries = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    decodeRaidData(data, fromURL: fullRequestURL)
                }
                
            }
            if let error = error {
                // something went wrong, check the error
                print("error, retrying in 1 second")
                print(error.localizedDescription)
                connectionRetries += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    loadRaidsInfo()
                }
            }
        }
        task?.resume()
        
    }
    func decodeRaidData(_ data: Data, fromURL url: URL? = nil) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let dataResponse = try decoder.decode(InstanceJournal.self, from: data)
            
//          For some reason Blizz have put a Greater Legion Invasion here as a raid…
//          I'm not allowing it.
            if dataResponse.category.type == "EVENT" {
                if gameData.raidsStubs.count > 0{
                    gameData.raidsStubs.removeFirst()
                }
                loadRaidsInfo()
                return
            }
            
            if let url = url {
                JSONCoreDataManager.shared.saveJSON(data, withURL: url)
            }
                
            DispatchQueue.main.async {
                withAnimation {
                    gameData.raids.append(dataResponse)
                    gameData.downloadedItems += 1
                }
                if gameData.raidsStubs.count > 0 {
                    gameData.raidsStubs.removeFirst()
                }
                loadRaidsInfo()
            }
            
        } catch {
            print(error)
        }
    }
    
    func loadDungeonsInfo(){
        if timeRetries > 5 || connectionRetries > 5 {
            print("Failed after \(timeRetries) timer retries, and or \(connectionRetries) connection errors")
            return
        }
        guard let currentDungeonToLoad = gameData.dungeonsStubs.first else {
            if gameData.dungeons.count > 0 {
                print("finished loading dungeons")
                // some dungeons are doubled, as they were "refreshed" in newer expansions,
                // but it does not reflect in their "expansion id", just in the expansion journal
                // here I am removing duplicates, and sorting it
                let noDuplicates = Array(Set(gameData.dungeons))

                DispatchQueue.main.async {
                    withAnimation {
                        gameData.dungeons = noDuplicates.sorted()
                        gameData.loadingAllowed = true
                    }
                }
                print("loaded \(gameData.dungeons.count) dungeons")
                return
            }
            timeRetries += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                loadRaidsInfo()
            }
            return
        }
        
        let requestUrlAPIHost = "\(currentDungeonToLoad.key.href)"
        
        let requestLocale = UserDefaults.standard.object(forKey: "localeCode") as? String ?? EuropeanLocales.BritishEnglish
        let accessToken = authorization.oauth2?.accessToken ?? ""
        
        let fullRequestURL = URL(string:
                                    requestUrlAPIHost +
                                    "&locale=\(requestLocale)" +
                                    "&access_token=\(accessToken)"
        )!
        
        
        guard let req = authorization.oauth2?.request(forURL: fullRequestURL) else { return }
        
        let task = authorization.oauth2?.session.dataTask(with: req) { data, response, error in
            if let data = data {
                timeRetries = 0
                connectionRetries = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    decodeDungeonData(data, fromURL: fullRequestURL)
                }
                
            }
            if let error = error {
                // something went wrong, check the error
                print("error, retrying in 1 second")
                print(error.localizedDescription)
                connectionRetries += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    loadRaidsInfo()
                }
            }
        }
        task?.resume()
        
    }
    func decodeDungeonData(_ data: Data, fromURL url: URL? = nil) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let dataResponse = try decoder.decode(InstanceJournal.self, from: data)
            
            if let url = url {
                JSONCoreDataManager.shared.saveJSON(data, withURL: url)
            }
                
            DispatchQueue.main.async {
                
                withAnimation {
                    gameData.dungeons.append(dataResponse)
                    gameData.downloadedItems += 1
                }
                
                if gameData.dungeonsStubs.count > 0 {
                    gameData.dungeonsStubs.removeFirst()
                }
                loadDungeonsInfo()
            }
            
        } catch {
            print(error)
        }
    }
    
}
