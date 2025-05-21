//
//  ContentView.swift
//  NekoRAR
//
//  Created by 千葉牧人 on 2025/5/20.
//

import SwiftUI
import UniformTypeIdentifiers

import SwiftUI

struct ContentView: View {
    @AppStorage("selectedAppearance") private var selectedAppearance: String = "system"
    @State private var archiveURL: URL?
    @State private var password: String = ""
    @State private var destinationURL: URL?
    @State private var extractionStatus: String = ""
    @State private var isExtracting: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Picker("外觀", selection: $selectedAppearance) {
                Text("跟隨系統").tag("system")
                Text("白天模式").tag("light")
                Text("黑夜模式").tag("dark")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            Text("🐱 NekoRAR 解壓工具")
                .font(.title)
                .bold()

            // 拖曳區
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(height: 120)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)

                Text(archiveURL?.lastPathComponent ?? "拖曳 ZIP / RAR / 7z 檔案到這裡")
                    .foregroundColor(.gray)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                if let provider = providers.first {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        DispatchQueue.main.async {
                            self.archiveURL = url
                        }
                    }
                    return true
                }
                return false
            }
            .onTapGesture {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [
                    UTType(filenameExtension: "rar")!,
                    .zip,
                    UTType(filenameExtension: "7z")!
                ]

                if panel.runModal() == .OK {
                    archiveURL = panel.url
                }
            }

            // 密碼欄位
            HStack {
                Text("密碼：")
                SecureField("如無密碼可留空", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)

            // 目的地選擇按鈕
            HStack {
                Text("解壓目的地：")
                if let dest = destinationURL {
                    Text(dest.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                }
                Button("選擇資料夾") {
                    selectDestinationFolder()
                }
            }
            .padding(.horizontal)

            // 開始解壓按鈕
            Button(action: {
                guard let archiveURL = archiveURL else { return }
                if archiveURL.pathExtension.lowercased() == "rar" {
                    isExtracting = true
                    extractionStatus = "正在解壓..."
                    extractRAR()
                } else {
                    extractionStatus = "目前僅支援 RAR 檔案解壓（ZIP / 7z 尚未實作）"
                }
            }) {
                Text("開始解壓")
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(archiveURL == nil)

            // 狀態訊息
            if !extractionStatus.isEmpty {
                Text(extractionStatus)
                    .foregroundColor(.secondary)
                    .font(.footnote)
                if isExtracting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if let bookmarkData = UserDefaults.standard.data(forKey: "lastDestinationBookmark") {
                var isStale = false
                do {
                    let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                    if resolvedURL.startAccessingSecurityScopedResource() {
                        destinationURL = resolvedURL
                    } else {
                        print("⚠️ 無法存取 bookmark 的 security scope")
                    }
                } catch {
                    print("⚠️ 無法還原 bookmark：\(error)")
                }
            } else if let savedPath = UserDefaults.standard.string(forKey: "lastDestinationPath"),
                      FileManager.default.fileExists(atPath: savedPath) {
                destinationURL = URL(fileURLWithPath: savedPath)
            }
        }
        .preferredColorScheme({
            switch selectedAppearance {
            case "light": return .light
            case "dark": return .dark
            default: return nil
            }
        }())
    }

    // 目的地選擇對話框
    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            destinationURL = panel.url
            do {
                let bookmark = try destinationURL!.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "lastDestinationBookmark")
            } catch {
                print("⚠️ 無法建立 bookmark：\(error)")
            }
        }
    }
    
    private func extractRAR() {
        guard let archiveURL = archiveURL else {
            extractionStatus = "請選擇檔案"
            isExtracting = false
            return
        }
        // 強制要求使用者選擇目的地
        guard let destinationURL = destinationURL else {
            extractionStatus = "請選擇目的地"
            isExtracting = false
            return
        }

        defer {
            destinationURL.stopAccessingSecurityScopedResource()
        }

        // 使用 App Bundle 內建的 unrar binary
        guard let bundleUnrarPath = Bundle.main.resourceURL?.appendingPathComponent("unrar") else {
            extractionStatus = "找不到內建的 unrar 執行檔"
            isExtracting = false
            return
        }

        // Debug: 輸出 unrar 路徑
        print("🧭 嘗試執行路徑：\(bundleUnrarPath.path)")

        // 檢查 unrar 是否存在於 bundle
        guard FileManager.default.fileExists(atPath: bundleUnrarPath.path) else {
            extractionStatus = "❌ 未找到 bundle 中的 unrar，可檢查 Build Phase 設定"
            isExtracting = false
            return
        }

        let passwordArg = password.isEmpty ? "-p-" : "-p\(password)"

        // 確保目的地資料夾存在
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)

        let process = Process()
        process.executableURL = bundleUnrarPath
        process.arguments = ["x", "-y", passwordArg, archiveURL.path, destinationURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            print("🔧 解壓輸出：\n\(output)")
            print("🔧 程式退出碼：\(process.terminationStatus)")

            if process.terminationStatus == 0 {
                extractionStatus = "解壓完成 ✅"
                isExtracting = false
            } else {
                extractionStatus = "解壓失敗 ❌\n\(output)"
                isExtracting = false
            }
        } catch {
            extractionStatus = "執行解壓時發生錯誤：\(error.localizedDescription)"
            isExtracting = false
        }
    }
}
