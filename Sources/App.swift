import SwiftUI
import UIKit
import Combine
import UniformTypeIdentifiers

// MARK: - Format Helper Global
struct AppFormatters {
    static func idr(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? "Rp 0"
    }

    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }
}

// MARK: - Manajer Penyimpanan Modal per Kloter (Default: 0)
class BatchModalManager {
    static let shared = BatchModalManager()
    private let key = "saved_batch_modals"
    private let defaultModal = 0 // Default NOL agar aman dan privasi modal terjaga

    func getModal(for batch: Int) -> Int {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return dict[String(batch)] ?? defaultModal
    }

    func setModal(for batch: Int, modal: Int) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        dict[String(batch)] = modal
        UserDefaults.standard.set(dict, forKey: key)
    }
}

// MARK: - Manajer Penyimpanan Berkas ZIP Sertifikat
class CertStorageManager {
    static let shared = CertStorageManager()

    private var certsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Certificates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveZip(from sourceURL: URL, for itemId: UUID) -> String? {
        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: sourceURL)
            let ext = sourceURL.pathExtension.isEmpty ? "zip" : sourceURL.pathExtension
            let fileName = "\(itemId.uuidString)_cert.\(ext)"
            let destURL = certsDirectory.appendingPathComponent(fileName)
            try data.write(to: destURL)
            return fileName
        } catch {
            return nil
        }
    }

    func getFileURL(fileName: String) -> URL? {
        let url = certsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func deleteFile(fileName: String?) {
        guard let fileName = fileName else { return }
        let url = certsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Model Data Penjualan
struct SaleItem: Identifiable, Codable {
    var id: UUID = UUID()
    var tanggalDaftar: Date
    var namaBuyer: String
    var kontakBuyer: String
    var udid: String
    var hargaJual: Int
    var durasiHari: Int
    var catatan: String
    var batchNumber: Int

    var zipFileName: String? = nil
    var certPassword: String? = nil

    var expiredGaransiDate: Date {
        Calendar.current.date(byAdding: .day, value: durasiHari, to: tanggalDaftar) ?? tanggalDaftar
    }

    var expiredCertAppleDate: Date {
        Calendar.current.date(byAdding: .day, value: 365, to: tanggalDaftar) ?? tanggalDaftar
    }

    var isTelegram: Bool {
        let clean = kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clean.hasPrefix("@") || clean.contains("t.me/")
    }

    var hasCertZip: Bool {
        return zipFileName != nil
    }

    var displayName: String {
        let trimNama = namaBuyer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimNama.isEmpty && trimNama != "-" {
            return trimNama
        }

        let trimKontak = kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimKontak.isEmpty { return "Customer" }
        if isTelegram { return trimKontak }

        let digits = trimKontak.filter { $0.isNumber }
        if digits.count >= 8 {
            let start = digits.prefix(4)
            let end = digits.suffix(4)
            return "\(start)••••\(end)"
        }

        return "Customer WA"
    }

    enum CodingKeys: String, CodingKey {
        case id, tanggalDaftar, namaBuyer, kontakBuyer, udid, hargaJual, durasiHari, catatan, batchNumber, zipFileName, certPassword
    }

    init(id: UUID = UUID(), tanggalDaftar: Date, namaBuyer: String, kontakBuyer: String, udid: String, hargaJual: Int, durasiHari: Int, catatan: String, batchNumber: Int = 1, zipFileName: String? = nil, certPassword: String? = nil) {
        self.id = id
        self.tanggalDaftar = tanggalDaftar
        self.namaBuyer = namaBuyer
        self.kontakBuyer = kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines)
        self.udid = udid
        self.hargaJual = hargaJual
        self.durasiHari = durasiHari
        self.catatan = catatan
        self.batchNumber = batchNumber
        self.zipFileName = zipFileName
        self.certPassword = certPassword
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        tanggalDaftar = try container.decodeIfPresent(Date.self, forKey: .tanggalDaftar) ?? Date()
        let kontak = try container.decodeIfPresent(String.self, forKey: .kontakBuyer) ?? ""
        kontakBuyer = kontak
        namaBuyer = try container.decodeIfPresent(String.self, forKey: .namaBuyer) ?? ""
        udid = try container.decodeIfPresent(String.self, forKey: .udid) ?? "-"
        hargaJual = try container.decodeIfPresent(Int.self, forKey: .hargaJual) ?? 60000
        durasiHari = try container.decodeIfPresent(Int.self, forKey: .durasiHari) ?? 30
        catatan = try container.decodeIfPresent(String.self, forKey: .catatan) ?? ""
        batchNumber = try container.decodeIfPresent(Int.self, forKey: .batchNumber) ?? 1
        zipFileName = try container.decodeIfPresent(String.self, forKey: .zipFileName)
        certPassword = try container.decodeIfPresent(String.self, forKey: .certPassword)
    }
}

enum FilterGaransi: String, CaseIterable, Identifiable {
    case semua = "Semua"
    case aktif = "Aktif"
    case habis = "Habis"
    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .semua: return "tray.full.fill"
        case .aktif: return "sparkles"
        case .habis: return "clock.badge.xmark.fill"
        }
    }
}

struct GaransiOption: Identifiable {
    let id: Int
    let name: String
}

// MARK: - Extension Liquid Glass Modern (Kompatibel iOS 15.0+)
extension View {
    @ViewBuilder
    func applyTextSelection(_ enabled: Bool) -> some View {
        if enabled {
            self.textSelection(.enabled)
        } else {
            self
        }
    }

    func liquidGlass(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.38))

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                Gradient.Stop(color: Color.white.opacity(0.48), location: 0.0),
                                Gradient.Stop(color: Color.white.opacity(0.10), location: 0.45),
                                Gradient.Stop(color: Color.cyan.opacity(0.28), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Entry Point
@main
struct iBaalSalesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Share Sheet Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Komponen Status Garansi
struct StatusGaransiView: View {
    let now: Date
    let exp: Date
    let durasi: Int

    var status: (text: String, color: Color) {
        if durasi == 0 {
            return ("⚪ Non-Garansi", .gray)
        }
        if now >= exp {
            return ("🔴 Garansi Habis", .red)
        }
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: exp)
        let d = diff.day ?? 0
        let h = diff.hour ?? 0
        let m = diff.minute ?? 0
        let s = diff.second ?? 0
        return ("🟢 Garansi: \(d)h \(h)j \(m)m lagi", .green)
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .shadow(color: status.color.opacity(0.8), radius: 4)
            Text(status.text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(status.color)
        }
    }
}

// MARK: - Switch Gelembung Prisma Kaca Cair (Liquid Lens Switch)
struct LiquidPrismSwitch: View {
    @Binding var selected: FilterGaransi
    @Namespace private var lensAnimation

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FilterGaransi.allCases) { filter in
                prismTabButton(for: filter)
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.55))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.06),
                            Color.cyan.opacity(0.20)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 18, y: 8)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func prismTabButton(for filter: FilterGaransi) -> some View {
        let isSelected = (selected == filter)

        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                selected = filter
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 15, weight: .semibold))

                Text(filter.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .heavy : .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.48))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.09))

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.35),
                                        Color.clear
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.cyan,
                                        Color.blue,
                                        Color.purple,
                                        Color.pink,
                                        Color.orange,
                                        Color.yellow,
                                        Color.green,
                                        Color.cyan
                                    ]),
                                    center: .center
                                ),
                                lineWidth: 1.6
                            )
                            .blur(radius: 0.4)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 0.6)
                            .matchedGeometryEffect(id: "PRISM_LENS_EFFECT", in: lensAnimation)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tampilan Utama
struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var items: [SaleItem] = []
    @State private var showAddModal = false
    @State private var showHistoryModal = false
    @State private var showEditBatchModal = false
    @State private var itemToEdit: SaleItem? = nil
    @State private var timerNow = Date()

    @AppStorage("hideFinancials") private var hideFinancials: Bool = false
    @State private var expandedBatches: Set<Int> = []

    @State private var searchText = ""
    @State private var selectedFilter: FilterGaransi = .semua

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var activeBatchNumber: Int {
        items.isEmpty ? 1 : ((items.count - 1) / 5 + 1)
    }

    var activeBatchItems: [SaleItem] {
        items.filter { $0.batchNumber == activeBatchNumber }
    }
    var slotTerjualDiBatchAktif: Int { activeBatchItems.count }
    var sisaSlotDiBatchAktif: Int { max(0, 5 - slotTerjualDiBatchAktif) }

    var modalKloterAktif: Int {
        BatchModalManager.shared.getModal(for: activeBatchNumber)
    }
    var omsetKloterAktif: Int {
        activeBatchItems.reduce(0) { $0 + $1.hargaJual }
    }
    var untungKloterAktif: Int {
        omsetKloterAktif - modalKloterAktif
    }

    var completedBatchesCount: Int {
        items.count / 5
    }

    var totalOmsetSemua: Int {
        items.reduce(0) { $0 + $1.hargaJual }
    }

    var filteredItems: [SaleItem] {
        items.filter { item in
            let matchSearch: Bool
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                matchSearch = true
            } else {
                let q = searchText.lowercased()
                matchSearch = item.displayName.lowercased().contains(q) ||
                              item.kontakBuyer.lowercased().contains(q) ||
                              item.udid.lowercased().contains(q) ||
                              item.catatan.lowercased().contains(q)
            }

            let matchFilter: Bool
            switch selectedFilter {
            case .semua:
                matchFilter = true
            case .aktif:
                matchFilter = item.durasiHari > 0 && timerNow < item.expiredGaransiDate
            case .habis:
                matchFilter = item.durasiHari == 0 || timerNow >= item.expiredGaransiDate
            }

            return matchSearch && matchFilter
        }
    }

    var batchesInFiltered: [Int] {
        let unique = Set(filteredItems.map { $0.batchNumber })
        return unique.sorted(by: >)
    }

    func itemsInBatch(_ batch: Int) -> [SaleItem] {
        filteredItems.filter { $0.batchNumber == batch }
    }

    func isBatchExpanded(_ batch: Int) -> Bool {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }
        return expandedBatches.contains(batch)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Circle()
                    .fill(Color.cyan.opacity(0.30))
                    .frame(width: 320, height: 320)
                    .blur(radius: 95)
                    .offset(x: -120, y: -260)

                Circle()
                    .fill(Color.purple.opacity(0.24))
                    .frame(width: 290, height: 290)
                    .blur(radius: 100)
                    .offset(x: 140, y: -30)

                Circle()
                    .fill(Color.blue.opacity(0.20))
                    .frame(width: 260, height: 260)
                    .blur(radius: 85)
                    .offset(x: -70, y: 340)

                ScrollView {
                    VStack(spacing: 18) {
                        summaryDashboardView

                        if completedBatchesCount > 0 {
                            Button {
                                showHistoryModal = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "archivebox.fill")
                                        .foregroundColor(.green)
                                    Text("\(completedBatchesCount) Kloter Selesai Tersimpan")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Buka Arsip ➔")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .padding(14)
                                .liquidGlass(cornerRadius: 16)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }

                        LiquidPrismSwitch(selected: $selectedFilter)

                        HStack {
                            Text("DAFTAR PEMBELI")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                            Spacer()
                            Text("\(filteredItems.count) Terfilter / \(items.count) Total")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal)

                        if filteredItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                                Text(items.isEmpty ? "Belum ada transaksi.\nTekan + di pojok kanan atas." : "Tidak ditemukan transaksi yang cocok.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(batchesInFiltered, id: \.self) { batch in
                                VStack(spacing: 10) {
                                    kloterAccordionHeader(batch: batch, count: itemsInBatch(batch).count)

                                    if isBatchExpanded(batch) {
                                        VStack(spacing: 12) {
                                            ForEach(itemsInBatch(batch)) { item in
                                                buyerCard(item: item)
                                            }
                                        }
                                        .clipped()
                                        .transition(.opacity)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Cert Manager ⚡")
            .searchable(text: $searchText, prompt: "Cari nama, UDID, tipe HP...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showHistoryModal = true
                        } label: {
                            Label("Arsip Kloter Selesai", systemImage: "archivebox.fill")
                        }
                        Button {
                            showEditBatchModal = true
                        } label: {
                            Label("Ubah Modal Kloter #\(activeBatchNumber)", systemImage: "dollarsign.circle.fill")
                        }
                        Divider()
                        Button {
                            exportBackup()
                        } label: {
                            Label("Cadangkan Data (Backup)", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Pulihkan Data (Restore)", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 21))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hideFinancials.toggle()
                        }
                    } label: {
                        Image(systemName: hideFinancials ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 19))
                            .foregroundColor(.cyan)
                    }

                    Button {
                        showAddModal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showAddModal) {
                SaleFormSheet(
                    itemToEdit: nil,
                    existingItems: items,
                    onDelete: nil,
                    onSave: { newItem in
                        items.insert(newItem, at: 0)
                        recalculateAndSave()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            expandedBatches.insert(activeBatchNumber)
                        }
                    }
                )
            }
            .sheet(item: $itemToEdit) { currentItem in
                SaleFormSheet(
                    itemToEdit: currentItem,
                    existingItems: items,
                    onDelete: { deletedId in
                        if let itemToDelete = items.first(where: { $0.id == deletedId }) {
                            CertStorageManager.shared.deleteFile(fileName: itemToDelete.zipFileName)
                        }
                        items.removeAll { $0.id == deletedId }
                        recalculateAndSave()
                    },
                    onSave: { updatedItem in
                        if let idx = items.firstIndex(where: { $0.id == updatedItem.id }) {
                            items[idx] = updatedItem
                            recalculateAndSave()
                        }
                    }
                )
            }
            .sheet(isPresented: $showEditBatchModal) {
                EditBatchModalSheet(
                    batchNumber: activeBatchNumber,
                    currentModal: modalKloterAktif
                ) { updatedModal in
                    BatchModalManager.shared.setModal(for: activeBatchNumber, modal: updatedModal)
                }
            }
            .sheet(isPresented: $showHistoryModal) {
                BatchHistorySheet(
                    allItems: items,
                    hideFinancials: hideFinancials
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if !shareItems.isEmpty {
                    ShareSheet(activityItems: shareItems)
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json, .plainText]) { result in
                handleImportBackup(result: result)
            }
            .alert("Informasi", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadData()
                if expandedBatches.isEmpty {
                    expandedBatches.insert(activeBatchNumber)
                }
            }
            .onReceive(timer) { input in
                timerNow = input
            }
        }
    }

    private func kloterAccordionHeader(batch: Int, count: Int) -> some View {
        let isExpanded = isBatchExpanded(batch)
        let isCurrent = (batch == activeBatchNumber)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                if expandedBatches.contains(batch) {
                    expandedBatches.remove(batch)
                } else {
                    expandedBatches.insert(batch)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isCurrent ? .cyan : .white.opacity(0.6))

                Text("KLOTER #\(batch)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)

                if isCurrent {
                    Text("AKTIF")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.22))
                        .foregroundColor(.cyan)
                        .cornerRadius(6)
                } else {
                    Text("SELESAI")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.22))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }

                Spacer()

                Text("\(count)/5 Cert")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(count >= 5 ? .green : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .liquidGlass(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var summaryDashboardView: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.cyan)
                    Text("KLOTER AKTIF #\(activeBatchNumber)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.cyan)
                }

                Spacer()

                Text("Live Monitor")
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(6)
                    .foregroundColor(.green)
            }

            VStack(spacing: 3) {
                Text(hideFinancials ? "Rp ••••••••" : (untungKloterAktif >= 0 ? "+\(AppFormatters.idr(untungKloterAktif))" : AppFormatters.idr(untungKloterAktif)))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(hideFinancials ? .gray : (untungKloterAktif >= 0 ? .green : .red))
                    .shadow(color: hideFinancials ? .clear : (untungKloterAktif >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3)), radius: 10)

                // Keterangan Aman & Privasi Terjaga
                if hideFinancials {
                    Text("Mode Sensor Finansial Aktif 🔒")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                } else {
                    Text(untungKloterAktif >= 0 ? "Keuntungan Bersih Kloter Ini" : "Belum Balik Modal (Kurang \(AppFormatters.idr(abs(untungKloterAktif))))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(untungKloterAktif >= 0 ? .green.opacity(0.85) : .orange)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.box.fill")
                        Text("\(slotTerjualDiBatchAktif)/5 Slot Terjual")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(slotTerjualDiBatchAktif >= 5 ? .green : .white)

                    Spacer()

                    Button {
                        showEditBatchModal = true
                    } label: {
                        HStack(spacing: 3) {
                            Text("Modal: \(hideFinancials ? "••••" : AppFormatters.idr(modalKloterAktif))")
                            Image(systemName: "pencil")
                        }
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(slotTerjualDiBatchAktif >= 5 ? Color.green : Color.cyan)
                            .frame(width: min(geo.size.width * CGFloat(slotTerjualDiBatchAktif) / 5.0, geo.size.width), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(slotTerjualDiBatchAktif >= 5 ? "5/5 Penuh! Transaksi berikutnya otomatis buka Kloter baru." : "Tersisa \(sisaSlotDiBatchAktif) slot di kloter ini.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(14)

            Divider().background(Color.white.opacity(0.15))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Omset Kloter Ini")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : AppFormatters.idr(omsetKloterAktif))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hideFinancials ? .gray : .white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Semua Omset")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : AppFormatters.idr(totalOmsetSemua))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hideFinancials ? .gray : .cyan)
                }
            }
        }
        .padding(18)
        .liquidGlass(cornerRadius: 22)
        .padding(.horizontal)
    }

    private func buyerCard(item: SaleItem) -> some View {
        let isTele = item.isTelegram
        let badgeColor: Color = isTele ? Color(red: 0.20, green: 0.65, blue: 0.95) : Color(red: 0.15, green: 0.82, blue: 0.45)
        let iconName = isTele ? "paperplane.fill" : "phone.bubble.left.fill"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Button {
                    openChatLink(item.kontakBuyer)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .bold))
                        Text(item.displayName)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(badgeColor.opacity(0.18))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(badgeColor.opacity(0.3), lineWidth: 1)
                    )
                }

                Text("Kloter #\(item.batchNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)

                Spacer()

                HStack(spacing: 12) {
                    if !hideFinancials {
                        Text(AppFormatters.idr(item.hargaJual))
                            .font(.footnote)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.cyan)
                    }

                    Button {
                        itemToEdit = item
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            if item.hasCertZip || (item.certPassword != nil && !item.certPassword!.isEmpty) {
                HStack(spacing: 8) {
                    if item.hasCertZip {
                        Button {
                            shareCertZip(item: item)
                        } label: {
                            Label("Kirim ZIP Cert 📦", systemImage: "doc.zipper")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.cyan.opacity(0.18))
                                .foregroundColor(.cyan)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }

                    if let pass = item.certPassword, !pass.isEmpty {
                        Button {
                            UIPasteboard.general.string = pass
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                Text("Pass: \(hideFinancials ? "••••" : pass)")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.15))
                            .foregroundColor(.yellow)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("UDID:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = item.udid
                    } label: {
                        Label("Salin", systemImage: "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                }
                Text(hideFinancials ? maskUDID(item.udid) : item.udid)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .applyTextSelection(!hideFinancials)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.black.opacity(0.35))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            if !item.catatan.isEmpty && item.catatan != "-" {
                Text("📱 \(item.catatan)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(spacing: 6) {
                HStack {
                    StatusGaransiView(now: timerNow, exp: item.expiredGaransiDate, durasi: item.durasiHari)
                    Spacer()
                    Text("Garansi s/d: \(item.durasiHari == 0 ? "Non-Garansi" : AppFormatters.date(item.expiredGaransiDate))")
                        .font(.caption2)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(item.durasiHari == 0 ? .gray : .orange.opacity(0.95))
                }
                HStack {
                    Text("Daftar: \(AppFormatters.date(item.tanggalDaftar))")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Cert Apple: \(AppFormatters.date(item.expiredCertAppleDate))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.85))
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 18)
        .padding(.horizontal)
    }

    private func maskUDID(_ u: String) -> String {
        let clean = u.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count >= 12 {
            let prefix = clean.prefix(8)
            return "\(prefix)-••••••••••••••••"
        }
        return "••••••••••••••••"
    }

    private func shareCertZip(item: SaleItem) {
        guard let zipName = item.zipFileName,
              let originalURL = CertStorageManager.shared.getFileURL(fileName: zipName) else {
            return
        }

        let pass = (item.certPassword?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? item.certPassword!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "ibaalcert"

        let customFileName = "password - \(pass).zip"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(customFileName)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: originalURL, to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            shareItems = [originalURL]
            showShareSheet = true
        }
    }

    private func openChatLink(_ contact: String) {
        let clean = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        var urlString = ""

        if clean.hasPrefix("@") {
            let user = clean.replacingOccurrences(of: "@", with: "")
            urlString = "https://t.me/\(user)"
        } else if clean.lowercased().contains("t.me/") {
            if clean.hasPrefix("http") {
                urlString = clean
            } else {
                urlString = "https://\(clean)"
            }
        } else {
            let digits = clean.filter { $0.isNumber }
            if digits.hasPrefix("08") {
                urlString = "https://wa.me/62\(digits.dropFirst())"
            } else if digits.hasPrefix("62") {
                urlString = "https://wa.me/\(digits)"
            } else {
                urlString = "https://wa.me/\(digits)"
            }
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private func exportBackup() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(items)

            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd_HHmmss"
            let fileName = "Backup_CertManager_\(df.string(from: Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try data.write(to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            alertMessage = "Gagal mengekspor data: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func handleImportBackup(result: Result<URL, Error>) {
        do {
            let fileURL = try result.get()
            let canAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if canAccess { fileURL.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: fileURL)
            let importedItems = try JSONDecoder().decode([SaleItem].self, from: data)

            items = importedItems
            recalculateAndSave()
            alertMessage = "Sukses! Berhasil memulihkan \(importedItems.count) data transaksi."
            showAlert = true
        } catch {
            alertMessage = "Gagal memulihkan file: Berkas rusak atau format tidak sesuai."
            showAlert = true
        }
    }

    private func recalculateAndSave() {
        let sortedAscending = items.sorted { $0.tanggalDaftar < $1.tanggalDaftar }
        var fixedItems: [SaleItem] = []

        for (index, item) in sortedAscending.enumerated() {
            var updated = item
            updated.batchNumber = (index / 5) + 1
            fixedItems.append(updated)
        }

        items = fixedItems.sorted { $0.tanggalDaftar > $1.tanggalDaftar }

        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "saved_sales")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "saved_sales"),
           let decoded = try? JSONDecoder().decode([SaleItem].self, from: data) {
            items = decoded
            recalculateAndSave()
        }
    }
}

// MARK: - Komponen Kartu Kloter Selesai
struct CompletedBatchCard: View {
    let batchNum: Int
    let batchItems: [SaleItem]
    let hideFinancials: Bool

    var omset: Int {
        batchItems.reduce(0) { $0 + $1.hargaJual }
    }

    var modal: Int {
        BatchModalManager.shared.getModal(for: batchNum)
    }

    var untung: Int {
        omset - modal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Kloter #\(batchNum)")
                        .font(.headline)
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Text("5/5 Selesai ✅")
                    .font(.caption2)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.18))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Modal Paket:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : AppFormatters.idr(modal))
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .center, spacing: 3) {
                    Text("Total Omset:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : AppFormatters.idr(omset))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Untung Bersih:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : "+\(AppFormatters.idr(untung))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                }
            }

            VStack(spacing: 5) {
                ForEach(batchItems) { item in
                    HStack {
                        Text(item.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Text(hideFinancials ? "••••" : AppFormatters.idr(item.hargaJual))
                            .font(.caption)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan.opacity(0.9))
                    }
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.25))
            .cornerRadius(8)
        }
        .padding()
        .liquidGlass(cornerRadius: 16)
        .padding(.horizontal)
    }
}

// MARK: - Lembar Arsip Kloter Selesai
struct BatchHistorySheet: View {
    @Environment(\.dismiss) var dismiss
    var allItems: [SaleItem]
    var hideFinancials: Bool

    var completedBatches: [Int] {
        let total = allItems.count
        let count = total / 5
        guard count > 0 else { return [] }
        return Array((1...count).reversed())
    }

    var totalUntungSemuaKloterSelesai: Int {
        var total = 0
        for batchNum in completedBatches {
            let batchItems = allItems.filter { $0.batchNumber == batchNum }
            let omset = batchItems.reduce(0) { $0 + $1.hargaJual }
            let modal = BatchModalManager.shared.getModal(for: batchNum)
            total += (omset - modal)
        }
        return total
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text("TOTAL KEUNTUNGAN BERSIH ARSIP")
                                .font(.caption)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green.opacity(0.8))

                            Text(hideFinancials ? "Rp ••••••••" : "+\(AppFormatters.idr(totalUntungSemuaKloterSelesai))")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundColor(hideFinancials ? .gray : .green)

                            Text("\(completedBatches.count) Kloter (Total \(completedBatches.count * 5) Cert Terjual)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        ForEach(completedBatches, id: \.self) { batchNum in
                            CompletedBatchCard(
                                batchNum: batchNum,
                                batchItems: allItems.filter { $0.batchNumber == batchNum },
                                hideFinancials: hideFinancials
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Arsip Kloter 📂")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tutup") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
    }
}

// MARK: - Lembar Ubah Modal Kloter
struct EditBatchModalSheet: View {
    @Environment(\.dismiss) var dismiss
    var batchNumber: Int
    var currentModal: Int
    var onSave: (Int) -> Void

    @State private var modalText = ""

    init(batchNumber: Int, currentModal: Int, onSave: @escaping (Int) -> Void) {
        self.batchNumber = batchNumber
        self.currentModal = currentModal
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Modal Kloter #\(batchNumber) (Paket 5 Cert)"), footer: Text("Atur modal kloter ini sesuai biaya yang kamu keluarkan.")) {
                    HStack {
                        Text("Modal Top-Up (Rp)")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        TextField("0", text: $modalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.cyan)
                    }
                }
            }
            .navigationTitle("Modal Kloter #\(batchNumber)")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if let val = Int(modalText) {
                            onSave(val)
                        }
                        dismiss()
                    } label: {
                        Text("Simpan")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .onAppear {
                modalText = String(currentModal)
            }
        }
    }
}

// MARK: - Formulir Tambah / Edit Penjualan
struct SaleFormSheet: View {
    @Environment(\.dismiss) var dismiss

    var itemToEdit: SaleItem?
    var existingItems: [SaleItem]
    var onDelete: ((UUID) -> Void)?
    var onSave: (SaleItem) -> Void

    @State private var itemId = UUID()
    @State private var namaBuyer = ""
    @State private var kontakBuyer = ""
    @State private var tanggalDaftar = Date()
    @State private var udid = ""
    @State private var hargaJualText = "60000"
    @State private var selectedGaransi = 30
    @State private var catatan = ""
    @State private var batchNumber = 1

    @State private var zipFileName: String? = nil
    @State private var certPassword = ""
    @State private var showZipPicker = false

    @State private var showDuplicateAlert = false
    @State private var duplicateDetails = ""
    @State private var pendingItemToSave: SaleItem? = nil

    init(itemToEdit: SaleItem? = nil, existingItems: [SaleItem] = [], onDelete: ((UUID) -> Void)? = nil, onSave: @escaping (SaleItem) -> Void) {
        self.itemToEdit = itemToEdit
        self.existingItems = existingItems
        self.onDelete = onDelete
        self.onSave = onSave
    }

    let opsiGaransi: [GaransiOption] = [
        GaransiOption(id: 30, name: "1 Bulan (Paket Basic)"),
        GaransiOption(id: 90, name: "3 Bulan (Paket Regular)"),
        GaransiOption(id: 180, name: "6 Bulan (Paket VIP)"),
        GaransiOption(id: 365, name: "1 Tahun Full"),
        GaransiOption(id: 0, name: "Tanpa Garansi")
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informasi Pembeli")) {
                    TextField("Nama Buyer (Boleh kosong)", text: $namaBuyer)
                    TextField("Nomor WA (08xxx) atau Telegram (@username)", text: $kontakBuyer)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section(header: Text("Harga Jual Suka-Suka"), footer: Text("Tentukan harga jual sesuai paket garansi yang dipilih pembeli.")) {
                    HStack {
                        Text("Harga Jual (Rp)")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        TextField("60000", text: $hargaJualText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }

                Section(header: Text("File ZIP Sertifikat (Opsional)"), footer: Text("Saat dibagikan, file otomatis bernama 'password - [password].zip'")) {
                    if zipFileName != nil {
                        HStack {
                            Image(systemName: "doc.zipper")
                                .foregroundColor(.cyan)
                            Text("ZIP Terpasang ✅")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Spacer()
                            Button("Hapus") {
                                CertStorageManager.shared.deleteFile(fileName: zipFileName)
                                zipFileName = nil
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Button {
                            showZipPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                    .foregroundColor(.cyan)
                                Text("Pilih Berkas ZIP Cert")
                                    .font(.subheadline)
                                    .foregroundColor(.cyan)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }

                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.yellow)
                        TextField("Password Cert (default: ibaalcert)", text: $certPassword)
                            .autocapitalization(.none)
                    }
                }

                Section(header: Text("Waktu Transaksi & Garansi Toko")) {
                    DatePicker("Tanggal Masuk", selection: $tanggalDaftar, displayedComponents: [.date, .hourAndMinute])
                    Picker("Paket Garansi", selection: $selectedGaransi) {
                        ForEach(opsiGaransi) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                }

                Section(header: Text("Nomor UDID")) {
                    TextEditor(text: $udid)
                        .frame(minHeight: 60)
                        .font(.system(size: 13, design: .monospaced))
                }

                Section(header: Text("Catatan Perangkat")) {
                    TextField("Misal: iPhone 15 Pro Max 256GB", text: $catatan)
                }

                if itemToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            if let id = itemToEdit?.id {
                                onDelete?(id)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Hapus Transaksi Ini")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(itemToEdit == nil ? "Tambah Penjualan" : "Edit Penjualan")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        validateAndSave()
                    } label: {
                        Text("Simpan")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .fileImporter(isPresented: $showZipPicker, allowedContentTypes: [.zip, .archive, .data]) { result in
                if let url = try? result.get() {
                    zipFileName = CertStorageManager.shared.saveZip(from: url, for: itemId)
                }
            }
            .alert("⚠️ UDID Sudah Terdaftar!", isPresented: $showDuplicateAlert) {
                Button("Batal (Cek Ulang)", role: .cancel) {
                    pendingItemToSave = nil
                }
                Button("Tetap Simpan", role: .destructive) {
                    if let item = pendingItemToSave {
                        onSave(item)
                        dismiss()
                    }
                }
            } message: {
                Text(duplicateDetails)
            }
            .onAppear {
                if let item = itemToEdit {
                    itemId = item.id
                    namaBuyer = item.namaBuyer
                    kontakBuyer = item.kontakBuyer
                    tanggalDaftar = item.tanggalDaftar
                    udid = item.udid
                    hargaJualText = String(item.hargaJual)
                    selectedGaransi = item.durasiHari
                    catatan = item.catatan
                    batchNumber = item.batchNumber
                    zipFileName = item.zipFileName
                    certPassword = item.certPassword ?? ""
                } else {
                    hargaJualText = "60000"
                }
            }
        }
    }

    private func validateAndSave() {
        let cleanUDID = udid.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalItem = SaleItem(
            id: itemId,
            tanggalDaftar: tanggalDaftar,
            namaBuyer: namaBuyer.trimmingCharacters(in: .whitespacesAndNewlines),
            kontakBuyer: kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines),
            udid: cleanUDID.isEmpty ? "-" : cleanUDID,
            hargaJual: Int(hargaJualText) ?? 60000,
            durasiHari: selectedGaransi,
            catatan: catatan,
            batchNumber: batchNumber,
            zipFileName: zipFileName,
            certPassword: certPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if !cleanUDID.isEmpty && cleanUDID != "-" {
            let lowerUDID = cleanUDID.lowercased()
            if let duplikat = existingItems.first(where: {
                $0.id != finalItem.id &&
                $0.udid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowerUDID
            }) {
                let df = DateFormatter()
                df.dateFormat = "dd/MM/yyyy"
                duplicateDetails = "UDID ini sudah pernah didaftarkan atas nama \"\(duplikat.displayName)\" pada tanggal \(df.string(from: duplikat.tanggalDaftar)).\n\nApakah kamu yakin ingin tetap menyimpannya atau membatalkan?"
                pendingItemToSave = finalItem
                showDuplicateAlert = true
                return
            }
        }

        onSave(finalItem)
        dismiss()
    }
}
