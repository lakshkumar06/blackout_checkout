import Foundation
import WebKit
import Security

@MainActor final class CryptoBridge: NSObject, WKNavigationDelegate {
  static let shared = CryptoBridge()
  private let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
  private var loaded = false
  private var loading: CheckedContinuation<Void, Error>?
  override private init() { super.init(); web.navigationDelegate = self; web.configuration.defaultWebpagePreferences.allowsContentJavaScript = true }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded = true; loading?.resume(); loading = nil }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loading?.resume(throwing: error); loading = nil }
  private func ready() async throws {
    if loaded { return }
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      loading = continuation
      let url = Bundle.main.url(forResource: "bridge", withExtension: "html")!
      web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
  }
  private func call(_ function: String, _ arguments: [String]) async throws -> String {
    try await ready()
    let result: Any = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any, Error>) in
      web.callAsyncJavaScript("return await window.Blackout[method](...args)", arguments: ["method": function, "args": arguments], in: nil, in: .page) { outcome in
        continuation.resume(with: outcome)
      }
    }
    guard let text = result as? String else { throw CheckoutError.message("Signing bridge returned no result") }
    return text
  }
  func address(key: String) async throws -> String { try await call("address", [key]) }
  func verifyReceive(_ json: String, contract: String) async throws -> String { try await call("verifyReceive", [json, contract]) }
  func sign(_ json: String, key: String, contract: String) async throws -> String { try await call("sign", [key, json, contract]) }
  func signDeposit(key: String, contract: String, amount: String, nonce: String, gasPrice: String) async throws -> String { try await call("signDeposit", [key, contract, amount, nonce, gasPrice]) }
}

enum SecureWallet {
  private static let account = "buyer-private-key-v1"
  static func read() -> String? {
    let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrAccount as String:account, kSecReturnData as String:true, kSecMatchLimit as String:kSecMatchLimitOne]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return String(data:data, encoding:.utf8)
  }
  static func save(_ key: String) throws {
    let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword, kSecAttrAccount as String:account]
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = Data(key.utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(add as CFDictionary, nil)
    guard status == errSecSuccess else { throw CheckoutError.message("Could not save wallet in Keychain (\(status))") }
  }
  static func create() throws -> String {
    var bytes = [UInt8](repeating:0,count:32)
    guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes) == errSecSuccess else { throw CheckoutError.message("Could not create wallet") }
    let key = "0x" + bytes.map { String(format:"%02x",$0) }.joined()
    try save(key)
    return key
  }
}
