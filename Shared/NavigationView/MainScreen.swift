//
//  MainScreen.swift
//  WoWWidget
//
//  Created by Mikolaj Lukasik on 13/08/2020.
//

import SwiftUI

struct MainScreen: View {
    @EnvironmentObject var gameData: GameData
    @EnvironmentObject var authorization: Authentication
    @State var characters: [CharacterInProfile] = []
    @State var selection: String? = ""
    
    #if os(iOS)
    var listStyle = InsetGroupedListStyle()
    #elseif os(macOS)
    var listStyle =  DefaultListStyle()
    #endif
    
    var body: some View {
        NavigationView {
            List() {
                
                Section(header: Text(gameData.loadingAllowed ? "Characters" : "Loading game data")){
                    if characters.count > 0 {
                        ForEach(characters) { character in
                            NavigationLink(
                                destination:
                                    CharacterMainView(character: character),
                                tag: "\(character.name)-\(character.realm.slug)",
                                selection: $selection) {
                                CharacterListItem(character: character)
                            }
                            .disabled(!gameData.loadingAllowed)
                        }
                    } else {
                        CharacterLoadingListItem()
                    }
                }
                Section(header: Text("Settings")){
                    NavigationLink(destination: DataHealthScreen(), tag: "data-health", selection: $selection) {
                        GameDataLoader()
                    }
                    
                    NavigationLink(destination: RaidOptions(), tag: "raid-settings", selection: $selection) {
                        RaidOptionsListItem()
                    }
                    
                    NavigationLink(destination: LogOutDebugScreen(), tag: "log-out", selection: $selection) {
                        LogOutListItem()
                    }
                    
                }
                
            }
            .listStyle(listStyle)
            .toolbar{
                ToolbarItem(placement: .principal){
                    Text("WoWWidget")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !gameData.loadingAllowed {
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                    }
                }
                    
            }
        }
        .navigationViewStyle(DefaultNavigationViewStyle())
        .onAppear {
            loadCharacters()
        }
        
    }
    
    func loadCharacters() {
        let requestUrlAPIHost = UserDefaults.standard.object(forKey: "APIRegionHost") as? String ?? APIRegionHostList.Europe
        let requestUrlAPIFragment = "/profile/user/wow"
        let regionShortCode = APIRegionShort.Code[UserDefaults.standard.integer(forKey: "loginRegion")]
        let requestAPINamespace = "profile-\(regionShortCode)"
        let requestLocale = UserDefaults.standard.object(forKey: "localeCode") as? String ?? EuropeanLocales.BritishEnglish
        
        let fullRequestURL = URL(string:
                                    requestUrlAPIHost +
                                    requestUrlAPIFragment +
                                    "?namespace=\(requestAPINamespace)" +
                                    "&locale=\(requestLocale)" +
                                    "&access_token=\(authorization.oauth2.accessToken ?? "")"
        )!
//        print(fullRequestURL)
        let req = authorization.oauth2.request(forURL: fullRequestURL)
        
        let task = authorization.oauth2.session.dataTask(with: req) { data, response, error in
            if let data = data {
//                print(data)
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let dataResponse = try decoder.decode(UserProfile.self, from: data)
                    
                    for account in dataResponse.wowAccounts {
                        withAnimation {
                            characters.append(contentsOf: account.characters)
                        }
                    }
                    
                } catch {
                    print(error)
                }
                
                
            }
            if let error = error {
                // something went wrong, check the error
                print("error")
                print(error.localizedDescription)
            }
        }
        task.resume()
    }
}

struct MainScreen_Previews: PreviewProvider {
    static var previews: some View {
        MainScreen()
            .previewLayout(.fixed(width: 2732, height: 2048))
    }
}