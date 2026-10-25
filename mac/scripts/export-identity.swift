// Writes one code-signing identity from the keychain to a PKCS#12 file.
// Usage: swift export-identity.swift <certificate SHA-1> <output.p12> <password>
import CryptoKit
import Foundation
import Security

let args = CommandLine.arguments
guard args.count == 4 else { fputs("usage: export-identity.swift <sha1> <out.p12> <password>\n", stderr); exit(2) }
let wanted = args[1].uppercased()

func sha1(_ identity: SecIdentity) -> String? {
    var certificate: SecCertificate?
    guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else { return nil }
    let data = SecCertificateCopyData(certificate) as Data
    return Insecure.SHA1.hash(data: data).map { String(format: "%02X", $0) }.joined()
}

let query: [String: Any] = [kSecClass as String: kSecClassIdentity, kSecMatchLimit as String: kSecMatchLimitAll,
                            kSecReturnRef as String: true]
var found: CFTypeRef?
guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
      let identity = (found as? [SecIdentity])?.first(where: { sha1($0) == wanted }) else {
    fputs("error: no identity with certificate SHA-1 \(wanted) in the keychain\n", stderr); exit(1)
}

var parameters = SecItemImportExportKeyParameters()
parameters.version = UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION)
parameters.passphrase = Unmanaged.passUnretained(args[3] as CFString)
var exported: CFData?
let status = SecItemExport(identity, .formatPKCS12, [], &parameters, &exported)
guard status == errSecSuccess, let exported else {
    fputs("error: export failed (\(status)); allow access when the keychain asks\n", stderr); exit(1)
}
try (exported as Data).write(to: URL(fileURLWithPath: args[2]), options: .atomic)
