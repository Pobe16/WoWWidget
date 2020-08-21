//
//  GameData.swift
//  WoWWidget (iOS)
//
//  Created by Mikolaj Lukasik on 20/08/2020.
//

import Foundation
import SwiftUI

class GameData: ObservableObject {
    
    @Published var expansionsStubs: [ExpansionIndex]         = []
    @Published var expansions: [ExpansionJournal]           = []
    @Published var raids: [Any]                             = []
    @Published var dungeons: [Any]                          = []
    @Published var encounters: [Any]                        = []
    
    @Published var numberOfExpansions: Int                  = 0
    @Published var loadedExpansions: Int                    = 0
    @Published var numberOfRaids: Int                       = 0
    @Published var loadedRaids: Int                         = 0
    @Published var numberOfDungeons: Int                    = 0
    @Published var loadedDungeons: Int                      = 0
    @Published var numberOfEncounters: Int                  = 0
    @Published var loadedEncounters: Int                    = 0
}
