#if DEBUG
import SwiftUI

struct FlapseDesignConceptView: View {
    private enum Tab: String, CaseIterable {
        case home
        case projects
        case saved
        case settings

        var icon: String {
            switch self {
            case .home: "house"
            case .projects: "square.grid.2x2"
            case .saved: "film.stack"
            case .settings: "gearshape"
            }
        }

        var activeIcon: String { "\(icon).fill" }

        var label: String {
            switch self {
            case .home: "Bugün"
            case .projects: "Projeler"
            case .saved: "Filmler"
            case .settings: "Ayarlar"
            }
        }
    }

    @State private var tab: Tab
    @State private var showsProjectDetail: Bool
    @State private var capturePulse = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let requestedTab = arguments
            .first(where: { $0.hasPrefix("--concept-tab=") })?
            .replacingOccurrences(of: "--concept-tab=", with: "")
        _tab = State(initialValue: Tab(rawValue: requestedTab ?? "") ?? .home)
        _showsProjectDetail = State(initialValue: arguments.contains("--concept-detail"))
    }

    var body: some View {
        ZStack {
            ConceptPalette.canvas.ignoresSafeArea()

            Group {
                if showsProjectDetail {
                    ConceptProjectDetailView {
                        withAnimation(.snappy(duration: 0.28)) {
                            showsProjectDetail = false
                        }
                    }
                } else {
                    switch tab {
                    case .home:
                        ConceptHomeView {
                            withAnimation(.snappy(duration: 0.28)) {
                                tab = .projects
                                showsProjectDetail = true
                            }
                        }
                    case .projects:
                        ConceptProjectsView {
                            withAnimation(.snappy(duration: 0.28)) {
                                showsProjectDetail = true
                            }
                        }
                    case .saved:
                        ConceptSavedView()
                    case .settings:
                        ConceptSettingsView()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !showsProjectDetail {
                conceptTabBar
            }
        }
        .preferredColorScheme(.light)
        .tint(ConceptPalette.accent)
    }

    private var conceptTabBar: some View {
        HStack(spacing: 4) {
            tabButton(.home)
            tabButton(.projects)

            Button {
                capturePulse.toggle()
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(ConceptPalette.ink, in: Circle())
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: ConceptPalette.ink.opacity(0.2), radius: 16, y: 8)
                    .symbolEffect(.bounce, value: capturePulse)
            }
            .buttonStyle(.plain)
            .offset(y: -15)
            .accessibilityLabel(Text(verbatim: "Kare çek"))

            tabButton(.saved)
            tabButton(.settings)
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ConceptPalette.line)
                .frame(height: 0.5)
        }
    }

    private func tabButton(_ item: Tab) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { tab = item }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab == item ? item.activeIcon : item.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(height: 22)
                Text(verbatim: item.label)
                    .font(.system(size: 10, weight: tab == item ? .semibold : .medium))
            }
            .foregroundStyle(tab == item ? ConceptPalette.accent : ConceptPalette.muted)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private enum ConceptPalette {
    static let canvas = Color(red: 0.965, green: 0.957, blue: 0.933)
    static let surface = Color.white.opacity(0.82)
    static let solidSurface = Color(red: 0.995, green: 0.992, blue: 0.98)
    static let ink = Color(red: 0.075, green: 0.105, blue: 0.094)
    static let muted = Color(red: 0.36, green: 0.405, blue: 0.38)
    static let accent = Color(red: 0.11, green: 0.43, blue: 0.31)
    static let accentSoft = Color(red: 0.82, green: 0.9, blue: 0.83)
    static let warm = Color(red: 0.94, green: 0.58, blue: 0.35)
    static let lavender = Color(red: 0.55, green: 0.51, blue: 0.78)
    static let line = ink.opacity(0.09)
}

private struct ConceptHomeView: View {
    let openProject: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header
                dailyStory
                rhythm
                projects
                recentFrames
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "Günaydın, Rıdvan")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(ConceptPalette.ink)
                Text(verbatim: "20 Temmuz · Bugün 2 çekim var")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ConceptPalette.muted)
            }
            Spacer()
            ZStack {
                Circle().fill(ConceptPalette.accentSoft)
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ConceptPalette.accent)
            }
            .frame(width: 44, height: 44)
            .overlay {
                Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2)
            }
        }
    }

    private var dailyStory: some View {
        Button(action: openProject) {
            ZStack(alignment: .bottomLeading) {
                ConceptPhoto(
                    colors: [Color(red: 0.77, green: 0.63, blue: 0.45), Color(red: 0.25, green: 0.42, blue: 0.36)],
                    symbol: "figure.and.child.holdinghands",
                    symbolScale: 86
                )
                LinearGradient(
                    colors: [.clear, ConceptPalette.ink.opacity(0.78)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(ConceptPalette.warm)
                            .frame(width: 8, height: 8)
                        Text(verbatim: "BUGÜNÜN KARESİ")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(.white.opacity(0.9))

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(verbatim: "Burcu")
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                            Text(verbatim: "142. gün · 18 günlük seri")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.76))
                        }
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .frame(width: 50, height: 50)
                            .foregroundStyle(ConceptPalette.ink)
                            .background(.white, in: Circle())
                    }
                }
                .foregroundStyle(.white)
                .padding(20)
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(verbatim: "Hizalama açık")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(.black.opacity(0.24), in: Capsule())
                .padding(14)
            }
            .shadow(color: ConceptPalette.ink.opacity(0.13), radius: 24, y: 14)
        }
        .buttonStyle(.plain)
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "Ritmin")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ConceptPalette.ink)
                    Text(verbatim: "Bu hafta 6 kare yakaladın")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ConceptPalette.muted)
                }
                Spacer()
                Label {
                    Text(verbatim: "18")
                } icon: {
                    Image(systemName: "flame.fill")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ConceptPalette.warm)
            }

            HStack(spacing: 0) {
                ForEach(Array(zip(["P", "S", "Ç", "P", "C", "C", "P"], [true, true, true, true, true, true, false])).indices, id: \.self) { index in
                    let item = Array(zip(["P", "S", "Ç", "P", "C", "C", "P"], [true, true, true, true, true, true, false]))[index]
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(item.1 ? ConceptPalette.accent : ConceptPalette.ink.opacity(0.06))
                            if item.1 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .strokeBorder(ConceptPalette.line, lineWidth: 1)
                            }
                        }
                        .frame(width: 28, height: 28)
                        Text(verbatim: item.0)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ConceptPalette.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .conceptSurface()
    }

    private var projects: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConceptSectionHeader(title: "Projelerin", action: "Tümünü gör")
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ConceptMiniProject(title: "Biz", detail: "Bugün", progress: 0.84, colors: [.indigo, .purple], symbol: "person.2.fill")
                    ConceptMiniProject(title: "Ela", detail: "Yarın", progress: 0.62, colors: [.orange, .pink], symbol: "figure.2.and.child.holdinghands")
                    ConceptMiniProject(title: "Aç köpek", detail: "Bugün", progress: 0.74, colors: [.mint, .teal], symbol: "pawprint.fill")
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 1, for: .scrollContent)
        }
    }

    private var recentFrames: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConceptSectionHeader(title: "Son kareler", action: "Zaman çizelgesi")
            HStack(spacing: 10) {
                ForEach(0..<4) { index in
                    ConceptPhoto(
                        colors: ConceptProjectData.palette(index),
                        symbol: ConceptProjectData.symbol(index),
                        symbolScale: 28
                    )
                    .frame(height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }
}

private struct ConceptProjectsView: View {
    let openProject: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "Projeler")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(ConceptPalette.ink)
                        Text(verbatim: "4 hikâye · 1.371 kare")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ConceptPalette.muted)
                    }
                    Spacer()
                    conceptCircleButton("photo.badge.plus")
                    conceptCircleButton("plus")
                }

                HStack(spacing: 9) {
                    ConceptFilterPill(title: "Tümü", isSelected: true)
                    ConceptFilterPill(title: "Bugün", isSelected: false)
                    ConceptFilterPill(title: "Birlikte", isSelected: false)
                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(0..<4) { index in
                        Button(action: openProject) {
                            ConceptProjectCard(index: index)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func conceptCircleButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(ConceptPalette.ink)
            .frame(width: 42, height: 42)
            .background(ConceptPalette.solidSurface, in: Circle())
            .overlay { Circle().strokeBorder(ConceptPalette.line, lineWidth: 0.7) }
    }
}

private struct ConceptProjectDetailView: View {
    let close: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 24) {
                    metrics
                    today
                    timeline
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {} label: {
                Label {
                    Text(verbatim: "Bugünün karesini çek")
                } icon: {
                    Image(systemName: "camera.fill")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(ConceptPalette.ink, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            ConceptPhoto(
                colors: [Color(red: 0.74, green: 0.49, blue: 0.32), Color(red: 0.26, green: 0.34, blue: 0.28)],
                symbol: "figure.and.child.holdinghands",
                symbolScale: 96
            )
            LinearGradient(colors: [.clear, ConceptPalette.ink.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                    Text(verbatim: "18 günlük seri")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 1, green: 0.74, blue: 0.5))
                Text(verbatim: "Burcu")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(verbatim: "142 kare · Her gün")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
            }
            .padding(22)
        }
        .frame(height: 365)
        .overlay(alignment: .top) {
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Button {} label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Button {} label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.top, 58)
        }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            ConceptMetric(value: "142", label: "Kare")
            Divider().frame(height: 34)
            ConceptMetric(value: "98%", label: "Ritim")
            Divider().frame(height: 34)
            ConceptMetric(value: "04:12", label: "Film")
        }
        .padding(.vertical, 16)
        .conceptSurface()
    }

    private var today: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(ConceptPalette.accentSoft, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: 0.84)
                    .stroke(ConceptPalette.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ConceptPalette.accent)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "Bugünkü ritim")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(ConceptPalette.ink)
                Text(verbatim: "Aynı saat aralığında çekime 42 dk kaldı")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ConceptPalette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .background(ConceptPalette.accentSoft.opacity(0.48), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(verbatim: "Temmuz")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(ConceptPalette.ink)
                Spacer()
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(ConceptPalette.muted)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9) { index in
                    ZStack(alignment: .bottomLeading) {
                        ConceptPhoto(colors: ConceptProjectData.palette(index), symbol: ConceptProjectData.symbol(index), symbolScale: 30)
                        Text(verbatim: "\(19 - index) Tem")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.3), in: Capsule())
                            .padding(7)
                    }
                    .aspectRatio(0.82, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

private struct ConceptSavedView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "Filmler")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(ConceptPalette.ink)
                    Text(verbatim: "Değişimin, izlenmeye hazır")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ConceptPalette.muted)
                }
                featured
                ConceptSectionHeader(title: "Son oluşturulanlar", action: "Seç")
                ForEach(0..<3) { index in
                    ConceptFilmRow(index: index)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var featured: some View {
        ZStack(alignment: .bottomLeading) {
            ConceptPhoto(colors: [.purple, .indigo], symbol: "person.2.fill", symbolScale: 76)
            LinearGradient(colors: [.clear, .black.opacity(0.74)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(ConceptPalette.ink)
                        .frame(width: 48, height: 48)
                        .background(.white, in: Circle())
                    Spacer()
                    Text(verbatim: "04:12")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.34), in: Capsule())
                }
                Text(verbatim: "Biz · Bir yıl")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(verbatim: "365 kare · Müzikle senkron")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(18)
        }
        .frame(height: 270)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: ConceptPalette.ink.opacity(0.12), radius: 22, y: 12)
    }
}

private struct ConceptSettingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text(verbatim: "Ayarlar")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(ConceptPalette.ink)

                HStack(spacing: 14) {
                    Circle()
                        .fill(ConceptPalette.accentSoft)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 25, weight: .medium))
                                .foregroundStyle(ConceptPalette.accent)
                        }
                        .frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "Rıdvan Özcan")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(ConceptPalette.ink)
                        Text(verbatim: "Flapse Pro · iCloud eşitleniyor")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ConceptPalette.muted)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(ConceptPalette.accent)
                }
                .padding(18)
                .conceptSurface()

                ConceptSettingsGroup(title: "Deneyim", rows: [
                    ("paintpalette.fill", "Görünüm", "Sıcak Kâğıt"),
                    ("globe", "Uygulama dili", "Türkçe"),
                    ("bell.badge.fill", "Hatırlatıcı", "Her gün 19:00")
                ])

                ConceptSettingsGroup(title: "Arşiv ve gizlilik", rows: [
                    ("icloud.fill", "iCloud yedekleme", "Açık"),
                    ("eye.slash.fill", "Gizlenenler", "Face ID"),
                    ("trash.fill", "Son Silinenler", "30 gün")
                ])

                ConceptSettingsGroup(title: "Flapse", rows: [
                    ("sparkles", "Akıllı hizalama", "Açık"),
                    ("questionmark.circle.fill", "Yardım ve destek", ""),
                    ("info.circle.fill", "Uygulama hakkında", "1.0")
                ])
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ConceptPhoto: View {
    let colors: [Color]
    let symbol: String
    let symbolScale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 2)
                    .offset(x: proxy.size.width * 0.27, y: -proxy.size.height * 0.2)
                Circle()
                    .fill(.black.opacity(0.08))
                    .frame(width: proxy.size.width * 0.48)
                    .offset(x: -proxy.size.width * 0.34, y: proxy.size.height * 0.35)
                Image(systemName: symbol)
                    .font(.system(size: symbolScale, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }
}

private struct ConceptSectionHeader: View {
    let title: String
    let action: String

    var body: some View {
        HStack {
            Text(verbatim: title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(ConceptPalette.ink)
            Spacer()
            Text(verbatim: action)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ConceptPalette.accent)
        }
    }
}

private struct ConceptMiniProject: View {
    let title: String
    let detail: String
    let progress: Double
    let colors: [Color]
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ConceptPhoto(colors: colors, symbol: symbol, symbolScale: 42)
                    .frame(width: 142, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                ZStack {
                    Circle().stroke(.white.opacity(0.36), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 25, height: 25)
                .padding(9)
            }
            Text(verbatim: title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ConceptPalette.ink)
            Text(verbatim: detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ConceptPalette.muted)
        }
        .frame(width: 142, alignment: .leading)
    }
}

private struct ConceptFilterPill: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? .white : ConceptPalette.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? ConceptPalette.ink : ConceptPalette.solidSurface, in: Capsule())
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(ConceptPalette.line, lineWidth: 0.7)
                }
            }
    }
}

private struct ConceptProjectCard: View {
    let index: Int

    private var titles: [String] { ["Burcu", "Biz", "Aç köpek", "Ela"] }
    private var counts: [String] { ["142 kare", "365 kare", "87 kare", "96 kare"] }
    private var due: [String] { ["Bugün", "Bugün", "Yarın", "3 gün"] }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZStack(alignment: .topTrailing) {
                ConceptPhoto(colors: ConceptProjectData.palette(index), symbol: ConceptProjectData.symbol(index), symbolScale: 52)
                    .aspectRatio(index == 1 ? 0.88 : 0.76, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text(verbatim: due[index])
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(due[index] == "Bugün" ? .white : ConceptPalette.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(due[index] == "Bugün" ? ConceptPalette.accent : .white.opacity(0.88), in: Capsule())
                    .padding(9)
            }
            Text(verbatim: titles[index])
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ConceptPalette.ink)
            HStack(spacing: 5) {
                Text(verbatim: counts[index])
                Circle().frame(width: 3, height: 3)
                Text(verbatim: index == 1 ? "Birlikte" : "Her gün")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ConceptPalette.muted)
        }
    }
}

private struct ConceptMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(verbatim: value)
                .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ConceptPalette.ink)
            Text(verbatim: label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ConceptPalette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ConceptFilmRow: View {
    let index: Int

    private var titles: [String] { ["Burcu · Yaz", "Ela büyüyor", "Aç köpek · 90 gün"] }
    private var details: [String] { ["01:28 · 18 Tem", "02:16 · 12 Tem", "00:42 · 4 Tem"] }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ConceptPhoto(colors: ConceptProjectData.palette(index + 1), symbol: ConceptProjectData.symbol(index + 1), symbolScale: 30)
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.32), in: Circle())
            }
            .frame(width: 104, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: titles[index])
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ConceptPalette.ink)
                Text(verbatim: details[index])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConceptPalette.muted)
                Label {
                    Text(verbatim: "Hazır")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ConceptPalette.accent)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(ConceptPalette.muted)
        }
        .padding(11)
        .conceptSurface()
    }
}

private struct ConceptSettingsGroup: View {
    let title: String
    let rows: [(String, String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ConceptPalette.muted)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 13) {
                        Image(systemName: row.0)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ConceptPalette.accent)
                            .frame(width: 32, height: 32)
                            .background(ConceptPalette.accentSoft.opacity(0.58), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(verbatim: row.1)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ConceptPalette.ink)
                        Spacer()
                        if !row.2.isEmpty {
                            Text(verbatim: row.2)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ConceptPalette.muted)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ConceptPalette.muted.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 58)
                    if index < rows.count - 1 {
                        Divider().padding(.leading, 59)
                    }
                }
            }
            .conceptSurface()
        }
    }
}

private enum ConceptProjectData {
    static func palette(_ index: Int) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.93, green: 0.55, blue: 0.34), Color(red: 0.54, green: 0.25, blue: 0.27)],
            [Color(red: 0.46, green: 0.44, blue: 0.72), Color(red: 0.22, green: 0.25, blue: 0.49)],
            [Color(red: 0.28, green: 0.62, blue: 0.53), Color(red: 0.15, green: 0.35, blue: 0.34)],
            [Color(red: 0.95, green: 0.68, blue: 0.49), Color(red: 0.68, green: 0.38, blue: 0.46)]
        ]
        return palettes[index % palettes.count]
    }

    static func symbol(_ index: Int) -> String {
        let symbols = ["figure.and.child.holdinghands", "person.2.fill", "pawprint.fill", "figure.2.and.child.holdinghands"]
        return symbols[index % symbols.count]
    }
}

private extension View {
    func conceptSurface() -> some View {
        background(ConceptPalette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(ConceptPalette.line, lineWidth: 0.7)
            }
    }
}
#endif
