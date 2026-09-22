import SwiftUI
import UIKit
import Combine
import UniformTypeIdentifiers

// MARK: - Model Data Penjualan
struct SaleItem: Identifiable, Codable {
    var id: UUID = UUID()
    var tanggalDaftar: Date
    var namaBuyer: String
    var kontakBuyer: String
    var udid: String
    var modal: Int
    var hargaJual: Int
    var durasiHari: Int
    var catatan: String

    var untung: Int {
        hargaJual - modal
    }

    var expiredDate: Date {
        Calendar.current.date(byAdding: .day, value: durasiHari, to: tanggalDaftar) ?? tanggalDaftar
    }

    var isTelegram: Bool {
        let clean = kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clean.hasPrefix("@") || clean.contains("t.me/")
    }

    enum CodingKeys: String, CodingKey {
        case id, tanggalDaftar, namaBuyer, kontakBuyer, udid, modal, hargaJual, durasiHari, catatan
    }

    init(id: UUID = UUID(), tanggalDaftar: Date, namaBuyer: String, kontakBuyer: String, udid: String, modal: Int, hargaJual: Int, durasiHari: Int, catatan: String) {
        self.id = id
        self.tanggalDaftar = tanggalDaftar
        self.namaBuyer = namaBuyer
        self.kontakBuyer = kontakBuyer
        self.udid = udid
        self.modal = modal
        self.hargaJual = hargaJual
        self.durasiHari = durasiHari
        self.catatan = catatan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        tanggalDaftar = try container.decodeIfPresent(Date.self, forKey: .tanggalDaftar) ?? Date()
        let kontak = try container.decodeIfPresent(String.self, forKey: .kontakBuyer) ?? ""
        kontakBuyer = kontak
        namaBuyer = try container.decodeIfPresent(String.self, forKey: .namaBuyer) ?? (kontak.isEmpty ? "Buyer" : kontak)
        udid = try container.decodeIfPresent(String.self, forKey: .udid) ?? "-"
        modal = try container.decodeIfPresent(Int.self, forKey: .modal) ?? 0
        hargaJual = try container.decodeIfPresent(Int.self, forKey: .hargaJual) ?? 0
        durasiHari = try container.decodeIfPresent(Int.self, forKey: .durasiHari) ?? 365
        catatan = try container.decodeIfPresent(String.self, forKey: .catatan) ?? ""
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

// MARK: - Share Sheet Backup
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
        return ("🟢 \(d)h \(h)j \(m)m \(s)d lagi", .green)
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
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
    @State private var itemToEdit: SaleItem? = nil
    @State private var timerNow = Date()

    @AppStorage("hideFinancials") private var hideFinancials: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterGaransi = .semua

    @State private var backupFileURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var totalModal: Int { items.reduce(0) { $0 + $1.modal } }
    var totalOmset: Int { items.reduce(0) { $0 + $1.hargaJual } }
    var totalUntung: Int { items.reduce(0) { $0 + $1.untung } }

    var filteredItems: [SaleItem] {
        items.filter { item in
            let matchSearch: Bool
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                matchSearch = true
            } else {
                let q = searchText.lowercased()
                matchSearch = item.namaBuyer.lowercased().contains(q) ||
                              item.kontakBuyer.lowercased().contains(q) ||
                              item.udid.lowercased().contains(q) ||
                              item.catatan.lowercased().contains(q)
            }

            let matchFilter: Bool
            switch selectedFilter {
            case .semua:
                matchFilter = true
            case .aktif:
                matchFilter = item.durasiHari > 0 && timerNow < item.expiredDate
            case .habis:
                matchFilter = item.durasiHari == 0 || timerNow >= item.expiredDate
            }

            return matchSearch && matchFilter
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        summaryDashboardView

                        VStack(spacing: 10) {
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
                                    .foregroundColor(.gray)
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
                                    .foregroundColor(.gray.opacity(0.5))
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
                            .foregroundColor(.gray)
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
                            .foregroundColor(hideFinancials ? .orange : .gray)
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
            // Sheet Tambah Data Baru
            .sheet(isPresented: $showAddModal) {
                SaleFormSheet(existingItems: items) { newItem in
                    items.insert(newItem, at: 0)
                    saveData()
                }
            }
            // Sheet Edit Data
            .sheet(item: $itemToEdit) { currentItem in
                SaleFormSheet(itemToEdit: currentItem, existingItems: items) { updatedItem in
                    if let idx = items.firstIndex(where: { $0.id == updatedItem.id }) {
                        items[idx] = updatedItem
                        saveData()
                    }
                } onDelete: { deletedId in
                    items.removeAll { $0.id == deletedId }
                    saveData()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = backupFileURL {
                    ShareSheet(activityItems: [url])
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
                Text("🚀 KEUNTUNGAN BERSIH")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.green.opacity(0.8))

                Spacer()

                if hideFinancials {
                    Text("Sensor Aktif (Mode SS)")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(.orange)
                } else {
                    Text("Live Monitor")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(.green)
                }
            }

            Text(hideFinancials ? "Rp ••••••••" : formatIDR(totalUntung))
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(hideFinancials ? .gray : .green)

            Divider().background(Color.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Modal")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : formatIDR(totalModal))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hideFinancials ? .gray : .white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Omset")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : formatIDR(totalOmset))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hideFinancials ? .gray : .cyan)
                }
            }
        }
        .padding()
        .background(Color(red: 0.14, green: 0.14, blue: 0.18))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func buyerCard(item: SaleItem) -> some View {
        let isTele = item.isTelegram
        let badgeColor: Color = isTele ? Color(red: 0.20, green: 0.65, blue: 0.95) : Color(red: 0.15, green: 0.82, blue: 0.45)
        let iconName = isTele ? "paperplane.fill" : "phone.bubble.left.fill"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Button {
                    openChatLink(item.kontakBuyer)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .bold))
                        Text(item.namaBuyer.isEmpty ? "Tanpa Nama" : item.namaBuyer)
                            .bold()
                    }
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(badgeColor.opacity(0.16))
                    .cornerRadius(8)
                }

                Spacer()

                HStack(spacing: 12) {
                    if !hideFinancials {
                        Text("+\(formatIDR(item.untung))")
                            .font(.footnote)
                            .bold()
                            .foregroundColor(.green)
                    }

                    Button {
                        itemToEdit = item
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray.opacity(0.9))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
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
                Text(item.udid)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(Color.black.opacity(0.25))
            .cornerRadius(8)

            if !item.catatan.isEmpty && item.catatan != "-" {
                Text("📱 \(item.catatan)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(spacing: 6) {
                HStack {
                    StatusGaransiView(now: timerNow, exp: item.expiredDate, durasi: item.durasiHari)
                    Spacer()
                    Text("Exp: \(formatDate(item.expiredDate))")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.orange.opacity(0.9))
                }
                HStack {
                    Spacer()
                    Text("Daftar: \(formatDate(item.tanggalDaftar))")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
        .cornerRadius(14)
        .padding(.horizontal)
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
            backupFileURL = tempURL
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

// MARK: - Formulir Tambah / Edit Penjualan dengan Proteksi Anti-Duplikat
struct SaleFormSheet: View {
    @Environment(\.dismiss) var dismiss

    var itemToEdit: SaleItem? = nil
    var existingItems: [SaleItem] = []
    var onSave: (SaleItem) -> Void
    var onDelete: ((UUID) -> Void)? = nil

    @State private var namaBuyer = ""
    @State private var kontakBuyer = ""
    @State private var tanggalDaftar = Date()
    @State private var udid = ""
    @State private var modalText = "75000"
    @State private var hargaJualText = "150000"
    @State private var selectedGaransi = 365
    @State private var catatan = ""

    // State Peringatan Duplikat
    @State private var showDuplicateAlert = false
    @State private var duplicateDetails = ""
    @State private var pendingItemToSave: SaleItem? = nil

    var untungOtomatis: Int {
        let jual = Int(hargaJualText) ?? 0
        let modal = Int(modalText) ?? 0
        return jual - modal
    }

    let opsiGaransi: [GaransiOption] = [
        GaransiOption(id: 365, name: "1 Tahun (365 Hari)"),
        GaransiOption(id: 180, name: "6 Bulan (180 Hari)"),
        GaransiOption(id: 90, name: "3 Bulan (90 Hari)"),
        GaransiOption(id: 30, name: "1 Bulan (30 Hari)"),
        GaransiOption(id: 0, name: "Tanpa Garansi")
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informasi Pembeli")) {
                    TextField("Nama Buyer (misal: Budi)", text: $namaBuyer)
                    TextField("Nomor WA (08xxx) atau Telegram (@username)", text: $kontakBuyer)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section(header: Text("Waktu Transaksi & Garansi")) {
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

                Section(header: Text("Perhitungan Finansial")) {
                    HStack {
                        Text("Modal")
                        Spacer()
                        TextField("Modal", text: $modalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Harga Jual")
                        Spacer()
                        TextField("Jual", text: $hargaJualText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Untung Bersih")
                            .bold()
                        Spacer()
                        Text("Rp \(untungOtomatis)")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.green)
                    }
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
            // Alert Pencegahan Duplikat
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
                    namaBuyer = item.namaBuyer
                    kontakBuyer = item.kontakBuyer
                    tanggalDaftar = item.tanggalDaftar
                    udid = item.udid
                    modalText = String(item.modal)
                    hargaJualText = String(item.hargaJual)
                    selectedGaransi = item.durasiHari
                    catatan = item.catatan
                }
            }
        }
    }

    private func validateAndSave() {
        let cleanUDID = udid.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalItem = SaleItem(
            id: itemToEdit?.id ?? UUID(),
            tanggalDaftar: tanggalDaftar,
            namaBuyer: namaBuyer.isEmpty ? (kontakBuyer.isEmpty ? "Buyer" : kontakBuyer) : namaBuyer,
            kontakBuyer: kontakBuyer,
            udid: cleanUDID.isEmpty ? "-" : cleanUDID,
            modal: Int(modalText) ?? 0,
            hargaJual: Int(hargaJualText) ?? 0,
            durasiHari: selectedGaransi,
            catatan: catatan
        )

        // Cek apakah UDID sudah ada sebelumnya (kecuali jika sedang mengedit item itu sendiri)
        if !cleanUDID.isEmpty && cleanUDID != "-" {
            let lowerUDID = cleanUDID.lowercased()
            if let duplikat = existingItems.first(where: {
                $0.id != finalItem.id &&
                $0.udid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowerUDID
            }) {
                let df = DateFormatter()
                df.dateFormat = "dd/MM/yyyy"
                duplicateDetails = "UDID ini sudah pernah didaftarkan atas nama \"\(duplikat.namaBuyer)\" pada tanggal \(df.string(from: duplikat.tanggalDaftar)).\n\nApakah kamu yakin ingin tetap menyimpannya atau membatalkan?"
                pendingItemToSave = finalItem
                showDuplicateAlert = true
                return
            }
        }

        // Jika tidak ada duplikat, langsung simpan
        onSave(finalItem)
        dismiss()
    }
}
