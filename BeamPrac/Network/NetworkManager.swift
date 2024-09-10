//
//  NetworkManager.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import Foundation
import Combine

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, Error> {
        // 네트워크 요청 구현
        fatalError("Network request not implemented")
    }
}

struct Endpoint {
    // 엔드포인트 정의
}

