import SwiftUI

/// A lightweight onboarding sheet that explains why Ferrufi needs folder access
/// and gives the user two simple choices:
///  - Select a folder (recommended; pick Home to use `~/.ferrufi/`)
///  - Skip and use App Support (fallback)
///
/// The parent view (typically `ContentView`) should present this sheet when no
/// security-scoped bookmark for the vault exists yet. Callers provide closures:
///  - `onSelectFolder` should open the Open Panel (NSOpenPanel) to let the user pick a folder.
///  - `onSkip` should create a safe fallback (e.g., ~/Library/Application Support/Ferrufi/scripts)
@MainActor
public struct VaultOnboardingView: View {
    public let onSelectFolder: () -> Void
    public let onSkip: () -> Void
    public let onLearnMore: (() -> Void)?

    public init(
        onSelectFolder: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onLearnMore: (() -> Void)? = nil
    ) {
        self.onSelectFolder = onSelectFolder
        self.onSkip = onSkip
        self.onLearnMore = onLearnMore
    }

    public var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Where should I store your vault?")
                        .font(.title2)
                        .bold()
                    Text(
                        "Ferrufi needs permission to store and edit your scripts. You can pick a folder now and Ferrufi will remember it."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Recommended")
                    .font(.headline)
                Text("• Select your Home folder to use the default location `~/.ferrufi/`.")
                Text("• You can also choose any folder you want as your vault.")
                Text("• Hidden folders (like `.ferrufi`) are visible in the picker.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            Divider()

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button(action: {
                        onSelectFolder()
                    }) {
                        Text("Select Vault Folder")
                            .frame(minWidth: 180)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        onSkip()
                    }) {
                        Text("Skip (Use App Support)")
                            .frame(minWidth: 160)
                    }
                    .buttonStyle(.bordered)
                }

                if let onLearnMore = onLearnMore {
                    Button(action: onLearnMore) {
                        Text("How does this work?")
                    }
                    .buttonStyle(.link)
                    .foregroundColor(.secondary)
                } else {
                    Text(
                        "Tip: In the picker press ⇧⌘. to show hidden files if you want to select `.ferrufi` directly."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 260)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .padding()
    }
}

#if DEBUG
    struct VaultOnboardingView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                VaultOnboardingView(
                    onSelectFolder: { print("Select pressed") },
                    onSkip: { print("Skip pressed") },
                    onLearnMore: { print("Learn more") }
                )
                .previewDisplayName("Onboarding")
            }
            .environment(\.colorScheme, .light)
        }
    }
#endif
