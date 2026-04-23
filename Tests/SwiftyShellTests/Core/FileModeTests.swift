import Testing
@testable import SwiftyShell

struct FileModeTests {
    @Test func rendersTypedPermissionsAsOctal() {
        let mode = FileMode(
            owner: [.read, .write, .execute],
            group: [.read, .execute],
            other: [.read, .execute]
        )

        #expect(mode.rawValue == "755")
    }

    @Test func rendersSpecialBitsAsLeadingDigit() {
        let mode = FileMode(
            owner: [.read, .write, .execute],
            group: [.read, .execute],
            other: [.read, .execute],
            special: [.sticky]
        )

        #expect(mode.rawValue == "1755")
    }

    @Test func rendersCombinedSpecialBits() {
        let mode = FileMode(
            owner: [.read, .write, .execute],
            group: [.read, .execute],
            other: [.read, .execute],
            special: [.setUserID, .setGroupID]
        )

        #expect(mode.rawValue == "6755")
    }

    @Test func rendersOctalModesWithoutPrefix() {
        #expect(FileMode.octal(0o755).rawValue == "755")
        #expect(FileMode.octal(0o1755).rawValue == "1755")
    }
}
