---
name: pfw-snapshot-testing
description: Snapshot test your Swift code using the SnapshotTesting library
metadata:
  short-description: Snapshot test your Swift code
---

# SnapshotTesting

## Goal

Snapshot test your Swift code using the [SnapshotTesting] library.

[SnapshotTesting]: http://github.com/pointfreeco/swift-snapshot-testing

## Quick start

 1. Add the `swift-snapshot-testing` package dependency from `1.0.0` or newer.
 2. Add the `SnapshotTesting` product to your test target's dependencies.
 3. `import SnapshotTesting` as needed

## API interface

Full API interface for when solution can't be found elsewhere: `references/interface/SnapshotTesting.swiftinterface`

## Inline snapshots

* **DO NOT** write the content of the inline snapshot trailing closures. Run the test suite in record mode to record fresh snapshots.
* **DO NOT** update the content of the inline snapshot trailing closures. Run the test suite in record mode to record fresh snapshots.
* **DO NOT** interpolate values into the trailing closure strings.

### Custom inline snapshot testing helpers

Custom inline snapshot testing functions can be defined that use `assertInlineSnapshot`: `references/custom-assert-inline-snapshot.md`

## TODO
- [ ] describe record mode
- [ ] Swift Testing
- [ ] XCTest
