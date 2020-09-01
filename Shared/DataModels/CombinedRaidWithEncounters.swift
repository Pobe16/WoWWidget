//
//  CombinedRaidWithEncounters.swift
//  WoWWidget
//
//  Created by Mikolaj Lukasik on 31/08/2020.
//

import Foundation

struct CombinedRaidWithEncounters: Hashable{
    let raidId: Int
    let raidName: String
    let description: String?
    let minimumLevel: Int
    let expansion: ExpansionIndex
    let media: InstanceMediaStub
    let modes: [InstanceMode]
    let records: [RaidEncountersForCharacter]
}