import SwiftUI
import UIKit
import Combine
import UniformTypeIdentifiers

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
    var hargaJual: Int // Harga jual bebas sesuai paket garansi
    var durasiHari: Int
    var catatan: String
    var batchNumber: Int // Kloter 5 cert ke berapa

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
        self.kontakBuyer = kontakBuyer
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
}

struct GaransiOption: Identifiable {
    let id: Int
    let name: String
}

// MARK: - Extension Helper
extension View {
    @ViewBuilder
    func applyTextSelection(_ enabled: Bool) -> some View {
        if enabled {
            self.textSelection(.enabled)
        } else {
            self
        }
    }

    func liquidGlass(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.08),
                                Color.cyan.opacity(0.15)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 15, x: 0, y: 8)
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
                .font(.caption)
                .bold()
                .foregroundColor(status.color)
        }
    }
}

// MARK: - Tampilan Utama
struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var items: [SaleItem] = []
    @State private var showAddModal = false
    @State private var showEditBatchModal = false
    @State private var itemToEdit: SaleItem? = nil
    @State private var timerNow = Date()

    @AppStorage("hideFinancials") private var hideFinancials: Bool = false
    @AppStorage("activeBatchNumber") private var activeBatchNumber: Int = 1
    @AppStorage("currentBatchModal") private var currentBatchModal: Int = 200000 // Modal top-up per 5 cert

    @State private var searchText = ""
    @State private var selectedFilter: FilterGaransi = .semua

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Filter Khusus Kloter Aktif
    var activeBatchItems: [SaleItem] {
        items.filter { $0.batchNumber == activeBatchNumber }
    }
    var slotTerjualKloter: Int { activeBatchItems.count }
    var sisaSlotKloter: Int { max(0, 5 - slotTerjualKloter) }

    // Perhitungan Keuangan Kloter 5 Slot
    var omsetKloterIni: Int { activeBatchItems.reduce(0) { $0 + $1.hargaJual } }
    var untungKloterIni: Int { omsetKloterIni - currentBatchModal }

    // Total Seluruh Penjualan
    var totalOmsetSemua: Int { items.reduce(0) { $0 + $1.hargaJual } }

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

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Circle()
                    .fill(Color.cyan.opacity(0.28))
                    .frame(width: 280, height: 280)
                    .blur(radius: 80)
                    .offset(x: -120, y: -240)

                Circle()
                    .fill(Color.purple.opacity(0.22))
                    .frame(width: 260, height: 260)
                    .blur(radius: 90)
                    .offset(x: 140, y: -40)

                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 240, height: 240)
                    .blur(radius: 80)
                    .offset(x: -80, y: 320)

                ScrollView {
                    VStack(spacing: 18) {
                        // Dashboard Rekap Finansial per 5 Cert
                        summaryDashboardView

                        VStack(spacing: 12) {
                            Picker("Filter", selection: $selectedFilter) {
                                ForEach(FilterGaransi.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)

                            HStack {
                                Text("DAFTAR PEMBELI")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("\(filteredItems.count) Terfilter / \(items.count) Total")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.cyan)
                            }
                            .padding(.horizontal)
                        }

                        if filteredItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                                Text(items.isEmpty ? "Belum ada transaksi.\nTekan + untuk menambah." : "Tidak ditemukan transaksi yang cocok.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(filteredItems) { item in
                                buyerCard(item: item)
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
                            showEditBatchModal = true
                        } label: {
                            Label("Atur Modal Top-Up Kloter", systemImage: "dollarsign.circle.fill")
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
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hideFinancials.toggle()
                        }
                    } label: {
                        Image(systemName: hideFinancials ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 18))
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
                    existingItems: items,
                    assignedBatch: activeBatchNumber
                ) { newItem in
                    items.insert(newItem, at: 0)
                    saveData()
                }
            }
            .sheet(item: $itemToEdit) { currentItem in
                SaleFormSheet(
                    itemToEdit: currentItem,
                    existingItems: items,
                    assignedBatch: currentItem.batchNumber
                ) { updatedItem in
                    if let idx = items.firstIndex(where: { $0.id == updatedItem.id }) {
                        items[idx] = updatedItem
                        saveData()
                    }
                } onDelete: { deletedId in
                    if let itemToDelete = items.first(where: { $0.id == deletedId }) {
                        CertStorageManager.shared.deleteFile(fileName: itemToDelete.zipFileName)
                    }
                    items.removeAll { $0.id == deletedId }
                    saveData()
                }
            }
            .sheet(isPresented: $showEditBatchModal) {
                EditBatchModal(
                    batchNumber: activeBatchNumber,
                    currentModal: $currentBatchModal,
                    onStartNewBatch: { newModal in
                        activeBatchNumber += 1
                        currentBatchModal = newModal
                    }
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
            .onAppear(perform: loadData)
            .onReceive(timer) { input in
                timerNow = input
            }
        }
    }

    private var summaryDashboardView: some View {
        VStack(spacing: 14) {
            HStack {
                Text("🚀 REKAP KLOTER #\(activeBatchNumber) (5 CERT)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.cyan)

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

            // Keuntungan Bersih Kloter Ini
            VStack(spacing: 2) {
                Text(hideFinancials ? "Rp ••••••••" : (untungKloterIni >= 0 ? "+\(formatIDR(untungKloterIni))" : formatIDR(untungKloterIni)))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(hideFinancials ? .gray : (untungKloterIni >= 0 ? .green : .red))
                    .shadow(color: hideFinancials ? .clear : (untungKloterIni >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3)), radius: 10)

                Text(untungKloterIni >= 0 ? "Keuntungan Bersih Kloter #\(activeBatchNumber)" : "Belum Balik Modal (Kurang \(formatIDR(abs(untungKloterIni))))")
                    .font(.caption2)
                    .foregroundColor(untungKloterIni >= 0 ? .green.opacity(0.8) : .orange)
            }

            // Modul Slot & Progress Bar 5/5
            VStack(spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.box.fill")
                        Text("\(slotTerjualKloter)/5 Slot Terjual")
                            .bold()
                    }
                    .font(.caption)
                    .foregroundColor(.white)

                    Spacer()

                    Button {
                        showEditBatchModal = true
                    } label: {
                        HStack(spacing: 3) {
                            Text("Modal: \(hideFinancials ? "••••" : formatIDR(currentBatchModal))")
                            Image(systemName: "pencil")
                        }
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    }
                }

                // Progress Bar 5 Slot
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(slotTerjualKloter >= 5 ? Color.green : Color.cyan)
                            .frame(width: min(geo.size.width * CGFloat(slotTerjualKloter) / 5.0, geo.size.width), height: 8)
                    }
                }
                .frame(height: 8)

                // Tombol Buka Kloter Baru jika sudah penuh 5/5
                if slotTerjualKloter >= 5 {
                    Button {
                        showEditBatchModal = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("5/5 Penuh! Mulai Kloter #\(activeBatchNumber + 1) 🚀")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.green.opacity(0.18))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)

            Divider().background(Color.white.opacity(0.15))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Omset Kloter Ini")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : formatIDR(omsetKloterIni))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hideFinancials ? .gray : .white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Semua Omset")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : formatIDR(totalOmsetSemua))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hideFinancials ? .gray : .cyan)
                }
            }
        }
        .padding(18)
        .liquidGlass(cornerRadius: 20)
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
                            .bold()
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

                // Tanda Kloter
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
                        Text(formatIDR(item.hargaJual))
                            .font(.footnote)
                            .bold()
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

            // Tampilan UDID
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

            // Info Garansi Toko & Cert Apple
            VStack(spacing: 6) {
                HStack {
                    StatusGaransiView(now: timerNow, exp: item.expiredGaransiDate, durasi: item.durasiHari)
                    Spacer()
                    Text("Garansi s/d: \(item.durasiHari == 0 ? "Non-Garansi" : formatDate(item.expiredGaransiDate))")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(item.durasiHari == 0 ? .gray : .orange.opacity(0.95))
                }
                HStack {
                    Text("Daftar: \(formatDate(item.tanggalDaftar))")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Cert Apple: \(formatDate(item.expiredCertAppleDate))")
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
            saveData()
            alertMessage = "Sukses! Berhasil memulihkan \(importedItems.count) data transaksi."
            showAlert = true
        } catch {
            alertMessage = "Gagal memulihkan file: Berkas rusak atau format tidak sesuai."
            showAlert = true
        }
    }

    private func formatIDR(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? "Rp 0"
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }

    private func saveData() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "saved_sales")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "saved_sales"),
           let decoded = try? JSONDecoder().decode([SaleItem].self, from: data) {
            items = decoded
        }
    }
}

// MARK: - Lembar Atur Modal Kloter
struct EditBatchModal: View {
    @Environment(\.dismiss) var dismiss
    var batchNumber: Int
    @Binding var currentModal: Int
    var onStartNewBatch: (Int) -> Void

    @State private var modalText = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Modal Kloter #\(batchNumber) (5 Cert)")) {
                    HStack {
                        Text("Modal Top-Up")
                        Spacer()
                        TextField("200000", text: $modalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button("Perbarui Modal Kloter Ini") {
                        if let val = Int(modalText) {
                            currentModal = val
                            dismiss()
                        }
                    }
                    .foregroundColor(.cyan)

                    Button("Mulai Kloter Baru #\(batchNumber + 1) 🚀") {
                        if let val = Int(modalText) {
                            onStartNewBatch(val)
                            dismiss()
                        }
                    }
                    .foregroundColor(.green)
                }
            }
            .navigationTitle("Pengaturan Kloter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tutup") { dismiss() }
                }
            }
            .onAppear {
                modalText = String(currentModal)
            }
        }
    }
}

// MARK: - Formulir Tambah / Edit Penjualan (Cukup Input Harga Jual Saja)
struct SaleFormSheet: View {
    @Environment(\.dismiss) var dismiss

    var itemToEdit: SaleItem? = nil
    var existingItems: [SaleItem] = []
    var assignedBatch: Int = 1
    var onSave: (SaleItem) -> Void
    var onDelete: ((UUID) -> Void)? = nil

    @State private var itemId = UUID()
    @State private var namaBuyer = ""
    @State private var kontakBuyer = ""
    @State private var tanggalDaftar = Date()
    @State private var udid = ""
    @State private var hargaJualText = "60000" // Cukup isi harga jual suka-suka
    @State private var selectedGaransi = 30
    @State private var catatan = ""
    @State private var batchNumber = 1

    @State private var zipFileName: String? = nil
    @State private var certPassword = ""
    @State private var showZipPicker = false

    @State private var showDuplicateAlert = false
    @State private var duplicateDetails = ""
    @State private var pendingItemToSave: SaleItem? = nil

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

                Section(header: Text("Harga Jual Suka-Suka"), footer: Text("Masukkan harga sesuai kesepakatan / durasi garansi yang dipilih pembeli.")) {
                    HStack {
                        Text("Harga Jual")
                            .bold()
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
                                    .bold()
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
                            .bold()
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
                    batchNumber = assignedBatch
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
