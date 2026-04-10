import SwiftUI

struct HomeView: View {
    @Binding var selectedProfile: VoiceProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Shinsoku")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text("Native voice input for iPhone and iPad.")
                        .foregroundStyle(.secondary)
                }

                profileCard
                keyboardCard
                roadmapCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Shinsoku")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current profile")
                .font(.headline)
            Picker("Profile", selection: $selectedProfile) {
                ForEach(VoiceProfile.defaults) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.menu)
            Text(selectedProfile.mode.summary)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var keyboardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard extension")
                .font(.headline)
            Text("The keyboard shell is scaffolded and ready for iterative build-out. Voice capture, prompt execution, and native-core reuse will be layered in next.")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shared-core direction")
                .font(.headline)
            Text("Prompt rules, profile derivation, post-processing logic, and provider/runtime abstractions are intended to converge with the desktop and Android implementations instead of becoming a separate iOS-only stack.")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
