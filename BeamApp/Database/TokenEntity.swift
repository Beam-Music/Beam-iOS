//
//  TokenEntity.swift
//  BeamApp
//
//  Created by freed on 9/20/24.
//

import SwiftData
import Foundation

@Model
class TokenEntity {
    @Attribute var token: String

    init( token: String) {
        self.token = token
    }
}

