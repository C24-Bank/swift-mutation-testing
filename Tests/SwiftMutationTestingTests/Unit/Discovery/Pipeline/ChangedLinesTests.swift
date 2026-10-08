import Foundation
import Testing

@testable import SwiftMutationTesting

@Suite("ChangedLines")
struct ChangedLinesTests {
    @Test("Given a hunk with a count, when parsed, then every added line is changed")
    func hunkWithCount() {
        let diff = """
            diff --git a/Sources/Foo.swift b/Sources/Foo.swift
            --- a/Sources/Foo.swift
            +++ b/Sources/Foo.swift
            @@ -10,2 +12,3 @@ func foo() {
            """

        let result = ChangedLines.parse(diff: diff, root: "/repo")

        #expect(result["/repo/Sources/Foo.swift"] == [12, 13, 14])
    }

    @Test("Given a hunk without a count, when parsed, then its single line is changed")
    func hunkWithoutCount() {
        let diff = """
            +++ b/Foo.swift
            @@ -3 +5 @@
            """

        let result = ChangedLines.parse(diff: diff, root: "/repo")

        #expect(result["/repo/Foo.swift"] == [5])
    }

    @Test("Given a pure deletion, when parsed, then no line is changed")
    func pureDeletion() {
        let diff = """
            +++ b/Foo.swift
            @@ -7,4 +6,0 @@
            """

        let result = ChangedLines.parse(diff: diff, root: "/repo")

        #expect(result["/repo/Foo.swift"] == nil)
    }

    @Test("Given several files and hunks, when parsed, then lines are kept per file")
    func severalFiles() {
        let diff = """
            +++ b/A.swift
            @@ -1,0 +2,2 @@
            @@ -20 +30 @@
            +++ b/B.swift
            @@ -5,1 +5,1 @@
            """

        let result = ChangedLines.parse(diff: diff, root: "/repo")

        #expect(result["/repo/A.swift"] == [2, 3, 30])
        #expect(result["/repo/B.swift"] == [5])
    }

    @Test("Given a deleted file, when parsed, then it is ignored")
    func deletedFile() {
        let diff = """
            --- a/Gone.swift
            +++ /dev/null
            @@ -1,3 +0,0 @@
            """

        let result = ChangedLines.parse(diff: diff, root: "/repo")

        #expect(result.isEmpty)
    }
}
