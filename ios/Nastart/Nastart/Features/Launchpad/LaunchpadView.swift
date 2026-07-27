import SwiftUI

enum LaunchpadConcept: String, CaseIterable, Identifiable {
    case homeBase
    case serviceStacks
    case commandDeck

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .homeBase: return "launchpad.concept.home_base"
        case .serviceStacks: return "launchpad.concept.service_stacks"
        case .commandDeck: return "launchpad.concept.command_deck"
        }
    }
}

struct LaunchpadView: View {
    @State private var selectedConcept: LaunchpadConcept = .homeBase
    private let device = SampleData.device
    private let services = SampleData.services

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    conceptPicker

                    switch selectedConcept {
                    case .homeBase:
                        HomeBaseLaunchpad(device: device, services: services)
                    case .serviceStacks:
                        ServiceStacksLaunchpad(device: device, services: services)
                    case .commandDeck:
                        CommandDeckLaunchpad(device: device, services: services)
                    }
                }
                .padding(18)
            }
            .background(AppTheme.groupedBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("N")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.title2.weight(.bold))
                    Text(device.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var conceptPicker: some View {
        Picker("launchpad.concept.picker", selection: $selectedConcept) {
            ForEach(LaunchpadConcept.allCases) { concept in
                Text(concept.titleKey).tag(concept)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct HomeBaseLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]

    private var favoriteServices: [LaunchpadService] {
        services.filter { $0.category == .favorites }
    }

    private var otherServices: [LaunchpadService] {
        services.filter { $0.category != .favorites }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSummaryPanel(device: device)

            SectionHeader(titleKey: "category.favorites", trailingKey: "action.edit")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(favoriteServices) { service in
                    ServiceCardView(service: service)
                }
            }

            SectionHeader(titleKey: "launchpad.section.services", trailingKey: "launchpad.section.generated")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(otherServices) { service in
                    ServiceCardView(service: service)
                }
            }
        }
    }
}

private struct ServiceStacksLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeviceSummaryPanel(device: device)

            ForEach(ServiceCategory.allCases) { category in
                let categoryServices = services.filter { $0.category == category }
                if !categoryServices.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(titleKey: LocalizedStringKey(category.titleKey), trailingKey: "action.expand")
                        VStack(spacing: 0) {
                            ForEach(categoryServices) { service in
                                HStack(spacing: 12) {
                                    Text(service.iconText)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 34, height: 34)
                                        .background(AppTheme.secondarySurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(service.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(LocalizedStringKey(service.detail))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusDot(status: service.status)
                                }
                                .padding(12)

                                if service.id != categoryServices.last?.id {
                                    Divider().padding(.leading, 58)
                                }
                            }
                        }
                        .nastartCard(cornerRadius: 20)
                    }
                }
            }
        }
    }
}

private struct CommandDeckLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 10) {
                MetricPill(titleKey: "metric.cpu", value: "11%", progress: device.cpu)
                MetricPill(titleKey: "metric.memory", value: "32%", progress: device.memory)
                MetricPill(titleKey: "metric.storage", value: "78%", progress: device.storageUsed)
                MetricPill(titleKey: "metric.tls", value: "19d", progress: nil)
            }
            .frame(width: 92)

            VStack(spacing: 12) {
                ForEach(services) { service in
                    HStack(alignment: .center, spacing: 12) {
                        Text(service.iconText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(service.name)
                                .font(.subheadline.weight(.semibold))
                            Text(LocalizedStringKey(service.detail))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        StatusDot(status: service.status)
                    }
                    .padding(13)
                    .nastartCard(cornerRadius: 20)
                }
            }
        }
    }
}

private struct DeviceSummaryPanel: View {
    let device: NASDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("launchpad.summary.normal")
                        .font(.title3.weight(.bold))
                    Text("launchpad.summary.subtitle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(device.uptimeText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                MetricPill(titleKey: "metric.cpu", value: "11%", progress: device.cpu)
                MetricPill(titleKey: "metric.memory", value: "32%", progress: device.memory)
                MetricPill(titleKey: "metric.storage", value: device.storageFreeText, progress: device.storageUsed)
            }
        }
        .padding(16)
        .nastartCard(cornerRadius: 26)
    }
}
