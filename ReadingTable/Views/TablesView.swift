import SwiftUI

struct TablesView: View {
    @ObservedObject var compositionViewModel: CoffeeTableCompositionViewModel
    var onDismiss: () -> Void
    @Environment(\.palette) private var palette

    @State private var newName = ""
    @State private var showNew = false
    @State private var duplicateName = ""
    @State private var showDuplicate = false
    @State private var renameTarget: CoffeeTableComposition?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your tables")
                        .displayTitleStyle()
                    Text("Save Christmas, autumn, work, or a plane tray. Open one whenever you like.")
                        .bodyStyle(muted: true)

                    ForEach(compositionViewModel.compositions, id: \.tableID) { table in
                        tableRow(table)
                    }
                }
                .padding(20)
            }
            .background(SanctuaryBackground())
            .navigationTitle("Tables")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New table") {
                            newName = ""
                            showNew = true
                        }
                        Button("Duplicate this table") {
                            let current = compositionViewModel.currentComposition?.name ?? "Table"
                            duplicateName = current + " copy"
                            showDuplicate = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New table")
                }
            }
            .alert("New table", isPresented: $showNew) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    Haptics.success()
                    compositionViewModel.createBlankTable(named: newName)
                    onDismiss()
                }
            } message: {
                Text("Starts empty. Your current table stays saved.")
            }
            .alert("Duplicate this table", isPresented: $showDuplicate) {
                TextField("Name", text: $duplicateName)
                Button("Cancel", role: .cancel) {}
                Button("Save copy") {
                    Haptics.success()
                    compositionViewModel.duplicateCurrent(named: duplicateName)
                    onDismiss()
                }
            }
            .alert("Rename", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let renameTarget {
                        compositionViewModel.rename(renameTarget, to: renameText)
                    }
                    renameTarget = nil
                }
            }
        }
    }

    private func tableRow(_ table: CoffeeTableComposition) -> some View {
        let isCurrent = table.tableID == compositionViewModel.currentComposition?.tableID
        return Button {
            Haptics.tap()
            compositionViewModel.selectComposition(table)
            onDismiss()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(table.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(palette.ink)
                    Text(isCurrent ? "On the table now" : table.createdDate.formatted(date: .abbreviated, time: .omitted))
                        .captionStyle()
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.accent)
                }
            }
            .padding(16)
            .background(palette.card, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                    .stroke(isCurrent ? palette.accent.opacity(0.45) : palette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") {
                renameText = table.name
                renameTarget = table
            }
            if compositionViewModel.compositions.count > 1 {
                Button("Delete", role: .destructive) {
                    compositionViewModel.deleteTable(table)
                }
            }
        }
    }
}
