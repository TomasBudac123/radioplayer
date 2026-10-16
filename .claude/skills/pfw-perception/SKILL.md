---
name: pfw-perception
description: Back-port Swift Observation to earlier platforms using the Perception library
metadata:
  short-description: Back-port Swift Observation to earlier platforms
---

# Perception

## Goal

Back-port Swift Observation to earlier platforms using the [Perception] library.

[Perception]: http://github.com/pointfreeco/swift-perception

## Quick start

1. Add the `swift-perception` package dependency from `2.0.0`.
2. Add the `Perception` product to your target's dependencies.
3. `import Perception` as needed

## API interface

* Core APIs: `references/interface/PerceptionCore.swiftinterface`
* Macro definitions: `references/interface/Perception.swiftinterface`

## Observation vs. Perception

* `@Observable` -> `@Perceptible`
* `@ObservationIgnored` -> `@PerceptionIgnored`
* `Observations` -> `Perceptions`
* `withObservationTracking` -> `withPerceptionTracking`

## How to integrate with SwiftUI

### Step 1: Use `WithPerceptionTracking`

Wrap any view that accesses perceptible properties in `WithPerceptionTracking`:

```swift
var body: some View {
  WithPerceptionTracking {
    ...
  }
}
```

Wrap the contents of escaping view builder closures, like `ForEach` and `GeometryReader`, when the closure accesses perceptible properties:

```swift
ForEach(items) { item in
  WithPerceptionTracking {
    ...
  }
}
```

* **DO NOT** use `WithPerceptionTracking` outside of a view builder.

### Step 2: Use `@Perception.Bindable`

To derive perceptible bindings, prefer `@Perception.Bindable` over deriving directly from `@State`:

```swift
@State var model = MyPerceptibleModel()

var body: some View {
  @Perception.Bindable var model = model
  TextField("Title", text: $model.title)
}
