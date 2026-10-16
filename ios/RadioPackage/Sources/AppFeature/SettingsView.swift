import ComposableArchitecture
import CoreTransferable
import DesignSystem
import L10n
import Models
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Bindable var store: StoreOf<Settings>
  @FocusState private var focusedField: Field?

  private enum Field {
    case name
    case url
  }

  var body: some View {
    Form {
      Section {
        ShareLink(
          item: BackupFile(favorites: Array(store.favorites)),
          preview: SharePreview(L10n.settingsBackupShareTitle, image: Image(systemName: "star"))
        ) {
          Label(L10n.settingsExport, systemImage: "square.and.arrow.up")
        }
        .disabled(store.favorites.isEmpty)

        Button {
          store.send(.importButtonTapped)
        } label: {
          Label(L10n.settingsImport, systemImage: "square.and.arrow.down")
        }
      } header: {
        Text(L10n.settingsBackupHeader)
      } footer: {
        Text(L10n.settingsBackupFooter)
      }

      Section {
        TextField(L10n.settingsManualName, text: $store.manualName)
          .textContentType(.name)
          .focused($focusedField, equals: .name)
          .submitLabel(.next)
          .onSubmit { focusedField = .url }
        TextField(L10n.settingsManualUrl, text: $store.manualURL)
          .keyboardType(.URL)
          .textContentType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focusedField, equals: .url)
          .submitLabel(.done)
          .onSubmit { store.send(.addManualButtonTapped) }
        Button(L10n.favoritesAdd) {
          focusedField = nil
          store.send(.addManualButtonTapped)
        }
        .disabled(!store.isManualFormValid)
      } header: {
        Text(L10n.settingsManualHeader)
      } footer: {
        Text(L10n.settingsManualFooter)
      }

      Section {
        switch store.siriAuthorization {
        case .authorized:
          Label(L10n.voiceSiriAllowed, systemImage: "checkmark.circle.fill")
            .foregroundStyle(Color.rpTextPrimary)
        case .denied:
          Label(L10n.voiceSiriDenied, systemImage: "mic.slash")
            .foregroundStyle(Color.rpTextSecondary)
        case .notDetermined:
          Button {
            store.send(.allowSiriButtonTapped)
          } label: {
            Label(L10n.voiceSiriAllow, systemImage: "mic")
          }
        }
      } header: {
        Text(L10n.voiceHeader)
      } footer: {
        Text(L10n.voiceSiriFooter(L10n.voiceExample, L10n.appName))
      }

      Section {
        Link(destination: URL(string: "https://www.radio-browser.info")!) {
          LabeledContent(L10n.settingsDatabase, value: "radio-browser.info")
        }
        LabeledContent(L10n.settingsVersion, value: Bundle.main.appVersion)
      } header: {
        Text(L10n.settingsAboutHeader)
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.rpBackground)
    .tint(Color.rpAccent)
    .navigationTitle(L10n.tabSettings)
    .scrollDismissesKeyboard(.interactively)
    .fileImporter(
      isPresented: $store.isImporterPresented,
      allowedContentTypes: [.json]
    ) { result in
      store.send(.importFileSelected(result))
    }
    .alert($store.scope(state: \.alert, action: \.alert))
    .onAppear { store.send(.onAppear) }
  }
}

/// Súbor zálohy na zdieľanie (AirDrop, Súbory, e-mail…).
struct BackupFile: Transferable {
  let favorites: [Station]

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .json) { file in
      try FavoritesBackup(favorites: file.favorites).encoded()
    }
    .suggestedFileName("radio-oblubene.json")
  }
}

extension Bundle {
  var appVersion: String {
    let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  }
}

#Preview {
  NavigationStack {
    SettingsView(store: Store(initialState: Settings.State()) { Settings() })
  }
}
