//
//  Helper.swift
//  JackPot
//
//  Created by ty on 12/21/24.
//

import Foundation
import CryptoKit
import SwiftUI
import Security
import SwiftyRSA


func md5(_ string: String) -> String {
    let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
    return digest.map { String(format: "%02hhx", $0) }.joined()
}

func colorForValue(_ value: Double, min: Double, mid: Double, max: Double) -> Color {
    // Ensure a valid range
    guard max > min, mid > min, mid < max else { return Color.white }
    
    if value <= mid {
        // Scale from Dark Red to White
        let normalized = (value - min) / (mid - min)
        return interpolateColor(from: Color(hex: "#e67d74"), to: Color(hex: "#ffffff"), fraction: normalized)
    } else {
        // Scale from White to Dark Green
        let normalized = (value - mid) / (max - mid)
        return interpolateColor(from: Color(hex: "#ffffff"), to: Color(hex: "#57ba89"), fraction: normalized)
    }
}

func colorForValueWinlost(_ value: Double, min: Double, mid: Double, max: Double) -> Color {
    // Ensure a valid range
    guard max > min, mid > min, mid < max else { return Color.white }
    
    if value <= mid {
        // Scale from Dark Red to White
        let normalized = (value - min) / (mid - min)
        return interpolateColor(from: Color(hex: "#57ba89"), to: Color(hex: "#ffffff"), fraction: normalized)
    } else {
        // Scale from White to Dark Green
        let normalized = (value - mid) / (max - mid)
        return interpolateColor(from: Color(hex: "#ffffff"), to: Color(hex: "#e67d74"), fraction: normalized)
    }
}

func formatNumber(_ number: Double) -> String {
    let billion = 1_000_000_000.0
    let million = 1_000_000.0
    let thousand = 1_000.0
    
    if number >= billion {
        if number < 100 * billion {
            return String(format: "%.2fB", number / billion)
        } else {
            return String(format: "%.0fB", number / billion)
        }
    } else if number >= million {
        return String(format: "%.0fM", number / million)
    } else if number >= thousand {
        if number < 100 * thousand {
            return String(format: "%.2fK", number / thousand)
        } else {
            return String(format: "%.0fK", number / thousand)
        }
    } else {
        return String(format: "%.0f", number)
    }
}

// Linear interpolation between two colors
func interpolateColor(from: Color, to: Color, fraction: Double) -> Color {
    let fromComponents = from.getComponents()
    let toComponents = to.getComponents()
    
    // Interpolate each color component
    let red = fromComponents.red + (toComponents.red - fromComponents.red) * fraction
    let green = fromComponents.green + (toComponents.green - fromComponents.green) * fraction
    let blue = fromComponents.blue + (toComponents.blue - fromComponents.blue) * fraction
    
    return Color(red: red, green: green, blue: blue)
}

func calculatePercentile(_ values: [Double], percentile: Double) -> Double {
    guard !values.isEmpty else {
        return 0.0 // Default value for empty arrays
    }
    let sortedValues = values.sorted()
    let index = (percentile / 100.0) * Double(sortedValues.count - 1)
    let lowerIndex = Int(floor(index))
    let upperIndex = Int(ceil(index))
    let weight = index - Double(lowerIndex)
    
    if lowerIndex == upperIndex {
        return sortedValues[lowerIndex]
    }
    return sortedValues[lowerIndex] * (1.0 - weight) + sortedValues[upperIndex] * weight
}

// MARK: - Helper Functions
func delay(seconds: Double) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

func decryptAES256(encryptedText: String) -> [String: Any]? {
    guard let encryptedData = Data(base64Encoded: encryptedText) else {
        print("❌ Lỗi: Không thể decode Base64")
        return nil
    }
    
    let keyData = (Env.shared.CRYPT_KEY).data(using: .utf8)! // Đảm bảo key đúng 32 bytes
    if keyData.count != 32 {
        print("❌ API_CLIENT_KEY không phải 32 bytes!")
        return nil
    }
    
    let symmetricKey = SymmetricKey(data: keyData)
    
    // 📌 Tách IV, CipherText, và Tag chính xác
    let iv = encryptedData.prefix(12) // IV 12 bytes
    let tag = encryptedData.suffix(16) // Tag 16 bytes
    let cipherText = encryptedData[12..<(encryptedData.count - 16)] // CipherText
    //
    //    print("🔍 Debug - keyData: \(keyData.map { String(format: "%02x", $0) }.joined())")
    //    print("🔍 Debug - iv: \(iv.map { String(format: "%02x", $0) }.joined())")
    //    print("🔍 Debug - tag: \(tag.map { String(format: "%02x", $0) }.joined())")
    //    print("🔍 Debug - cipherText: \(cipherText.map { String(format: "%02x", $0) }.joined())")
    
    do {
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: cipherText, tag: tag)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        if let json = try? JSONSerialization.jsonObject(with: decryptedData, options: []) as? [String: Any] {
            return json
        }
    } catch {
        print("❌ Giải mã thất bại: \(error)")
    }
    
    return nil
}

// MARK: - Success Alert
func showSuccess(title: String, message: String) {
    showAlert(title: title, message: message, style: .alert, tintColor: UIColor.systemGreen)
}

// MARK: - Danger Alert
func showDanger(title: String, message: String) {
    showAlert(title: title, message: message, style: .alert, tintColor: UIColor.systemRed)
}

// MARK: - Warning Alert
func showWarning(title: String, message: String) {
    showAlert(title: title, message: message, style: .alert, tintColor: UIColor.systemOrange)
}

// MARK: - Base Alert Function
private func showAlert(title: String, message: String, style: UIAlertController.Style, tintColor: UIColor) {
    DispatchQueue.main.async {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        alert.view.tintColor = tintColor
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}


enum SortOption {
    case clientId, depositAmount, withdrawAmount, diffDepositWithdraw , totalBet, totalWinlost, totalStake , activeBetUsers, brand, amount , createdAt
}


extension Color {
    // Extract RGB components from SwiftUI Color
    func getComponents() -> (red: Double, green: Double, blue: Double) {
        // Use a UIColor representation to extract components
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
    
    // Initialize SwiftUI Color from Hex String
    init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.currentIndex = hex.hasPrefix("#") ? hex.index(after: hex.startIndex) : hex.startIndex
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
