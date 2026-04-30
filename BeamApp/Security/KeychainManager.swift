//
//  KeychainManager.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.beamapp.token"
    private let account = "userToken"
    
    private init() {}
    
    // MARK: - Token Management
    
    /// 토큰을 Keychain에 저장
    func saveToken(_ token: String) throws {
        #if DEBUG
        print("🔐 Keychain에 토큰 저장 시도: \(token.prefix(10))...")
        #endif
        
        // 기존 토큰 삭제
        try deleteToken()
        
        // 토큰을 Data로 변환
        guard let tokenData = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Keychain 쿼리 생성
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false
        ]
        
        // Keychain에 저장
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ 토큰이 Keychain에 성공적으로 저장됨")
        } else {
            print("❌ Keychain 저장 실패: \(status)")
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Keychain에서 토큰 가져오기
    func fetchToken() -> String? {
        print("🔍 Keychain에서 토큰 검색 중...")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            if let tokenData = result as? Data,
               let token = String(data: tokenData, encoding: .utf8) {
                #if DEBUG
                print("✅ Keychain에서 토큰 발견: \(token.prefix(10))...")
                #endif
                return token
            }
        } else if status == errSecItemNotFound {
            print("🔍 Keychain에 토큰이 없음")
        } else {
            print("❌ Keychain 검색 실패: \(status)")
        }
        
        return nil
    }
    
    /// Keychain에서 토큰 삭제
    func deleteToken() throws {
        print("🗑️ Keychain에서 토큰 삭제 시도...")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ 토큰이 Keychain에서 삭제됨")
        } else {
            print("❌ Keychain 삭제 실패: \(status)")
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// 토큰이 존재하는지 확인
    func hasToken() -> Bool {
        return fetchToken() != nil
    }
    
    /// 토큰이 유효한지 확인 (JWT 만료 시간 체크)
    func isTokenValid() -> Bool {
        guard let token = fetchToken() else {
            return false
        }
        
        // JWT 토큰의 만료 시간 확인
        return !isTokenExpired(token)
    }
    
    /// JWT 토큰의 만료 시간 확인
    private func isTokenExpired(_ token: String) -> Bool {
        let components = token.components(separatedBy: ".")
        
        guard components.count == 3,
              let payloadData = Data(base64Encoded: components[1].padding(toLength: ((components[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            print("❌ JWT 토큰 파싱 실패")
            return true
        }
        
        let currentTime = Date().timeIntervalSince1970
        let isExpired = currentTime >= exp
        
        if isExpired {
            print("⏰ 토큰이 만료됨: \(Date(timeIntervalSince1970: exp))")
        } else {
            let remainingTime = exp - currentTime
            let remainingHours = remainingTime / 3600
            print("⏰ 토큰 만료까지 남은 시간: \(String(format: "%.1f", remainingHours))시간")
        }
        
        return isExpired
    }
    
    /// 토큰의 만료 시간까지 남은 시간 (초)
    func getTokenExpirationTime() -> TimeInterval? {
        guard let token = fetchToken() else {
            return nil
        }
        
        let components = token.components(separatedBy: ".")
        
        guard components.count == 3,
              let payloadData = Data(base64Encoded: components[1].padding(toLength: ((components[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return nil
        }
        
        let currentTime = Date().timeIntervalSince1970
        return exp - currentTime
    }
}

// MARK: - Keychain Errors
enum KeychainError: Error, LocalizedError {
    case invalidData
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "토큰 데이터가 유효하지 않습니다."
        case .saveFailed(let status):
            return "Keychain 저장 실패: \(status)"
        case .deleteFailed(let status):
            return "Keychain 삭제 실패: \(status)"
        case .unknown:
            return "알 수 없는 Keychain 오류가 발생했습니다."
        }
    }
}

// MARK: - String Extensions
extension String {
    func truncate(to length: Int) -> String {
        return (self.count > length) ? self.prefix(length) + "..." : self
    }
}

