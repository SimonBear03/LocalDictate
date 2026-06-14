import Foundation
import LocalDictateCore

let arguments = CommandLine.arguments.dropFirst()

switch arguments.first {
case "status":
    print("LocalDictate CLI installed.")
    print("Local API: disabled by default in v1 scaffold.")
case "templates":
    for template in CleanupTemplate.builtIns {
        print("\(template.name): \(template.summary)")
    }
default:
    print("""
    LocalDictate CLI

    Usage:
      localdictate status
      localdictate templates

    The local HTTP API is intentionally opt-in and not enabled in this first scaffold.
    """)
}

