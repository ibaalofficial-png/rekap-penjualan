import SwiftUI
import UIKit
import Combine

// MARK: - Model Data
struct SaleItem: Identifiable, Codable {
    var id: UUID = UUID()
    var tanggalDaftar: Date
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
                .fontWeight(.bold)
                .foregroundColor(status.color)
        }
    }
}

// MARK: - Tampilan Utama
struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var items: [SaleItem] = []
    @State private var showAddModal = false
    @State private var timerNow = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var totalModal: Int { items.reduce(0) { $0 + $1.modal } }
    var totalOmset: Int { items.reduce(0) { $0 + $1.hargaJual } }
    var totalUntung: Int { items.reduce(0) { $0 + $1.untung } }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        summaryDashboardView

                        HStack {
                            Text("DAFTAR PEMBELI & GARANSI")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(items.count) Unit")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal)

                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("Belum ada data transaksi.\nTekan tombol + di atas untuk mencatat.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(items) { item in
                                buyerCard(item: item)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Cert Manager ⚡")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                AddSaleView { newItem in
                    items.insert(newItem, at: 0)
                    saveData()
                }
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
                    .fontWeight(.bold)
                    .foregroundColor(.green.opacity(0.8))
                Spacer()
                Text("Live Monitor")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(6)
                    .foregroundColor(.green)
            }

            Text(formatIDR(totalUntung))
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.green)

            Divider().background(Color.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Modal")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(formatIDR(totalModal))
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Omset")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(formatIDR(totalOmset))
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding()
        .background(Color(red: 0.14, green: 0.14, blue: 0.18))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func buyerCard(item: SaleItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    openChatLink(item.kontakBuyer)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.kontakBuyer.contains("@") ? "paperplane.fill" : "phone.bubble.left.fill")
                        Text(item.kontakBuyer)
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(8)
                }

                Spacer()

                Text("+\(formatIDR(item.untung))")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            HStack {
                Text("UDID: \(formatUDID(item.udid))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    UIPasteboard.general.string = item.udid
                } label: {
                    Label("Salin", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                StatusGaransiView(now: timerNow, exp: item.expiredDate, durasi: item.durasiHari)
                Spacer()
                Text("Exp: \(formatDate(item.expiredDate))")
                    .font(.caption2)
                    .foregroundColor(.gray)
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

    private func formatIDR(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? "Rp 0"
    }

    private func formatUDID(_ u: String) -> String {
        if u.count > 16 { return "\(u.prefix(8))...\(u.suffix(6))" }
        return u
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

// MARK: - Form Tambah Penjualan
struct AddSaleView: View {
    @Environment(\.dismiss) var dismiss
    var onSave: (SaleItem) -> Void

    @State private var kontakBuyer = ""
    @State private var udid = ""
    @State private var modalText = "75000"
    @State private var hargaJualText = "150000"
    @State private var selectedGaransi = 365
    @State private var catatan = ""

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
                    TextField("Kontak (@tele atau 08xxx WA)", text: $kontakBuyer)
                    TextField("Nomor UDID", text: $udid)
                }

                Section(header: Text("Paket Garansi")) {
                    Picker("Pilih Durasi", selection: $selectedGaransi) {
                        ForEach(opsiGaransi) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
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
                            .fontWeight(.bold)
                        Spacer()
                        Text("Rp \(untungOtomatis)")
                            .fontWeight(.heavy)
                            .foregroundColor(.green)
                    }
                }

                Section(header: Text("Catatan")) {
                    TextField("Tipe Device / Keterangan", text: $catatan)
                }
            }
            .navigationTitle("Catat Penjualan")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") {
                        let item = SaleItem(
                            tanggalDaftar: Date(),
                            kontakBuyer: kontakBuyer.isEmpty ? "@buyer" : kontakBuyer,
                            udid: udid.isEmpty ? "-" : udid,
                            modal: Int(modalText) ?? 0,
                            hargaJual: Int(hargaJualText) ?? 0,
                            durasiHari: selectedGaransi,
                            catatan: catatan
                        )
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}
