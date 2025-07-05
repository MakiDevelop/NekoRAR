//
//  ContentView.swift
//  NekoRAR
//
//  Created by 千葉牧人 on 2025/5/20.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

import SwiftUI

struct ContentView: View {
    @AppStorage("selectedAppearance") private var selectedAppearance: String = "system"
    @State private var archiveURL: URL?
    @State private var password: String = ""
    @State private var destinationURL: URL?
    @State private var extractionStatus: String = ""
    @State private var isExtracting: Bool = false
    @State private var showingAbout: Bool = false
    @State private var progressValue: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("目前語系：\(Bundle.main.preferredLocalizations.first ?? "未知")")
                .font(.footnote)
                .foregroundColor(.gray)
            Picker(NSLocalizedString("appearance", comment: "" ), selection: $selectedAppearance) {
                Text(NSLocalizedString("appearance_system", comment: "")).tag("system")
                Text(NSLocalizedString("appearance_light", comment: "")).tag("light")
                Text(NSLocalizedString("appearance_dark", comment: "")).tag("dark")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            Text(NSLocalizedString("title_main", comment: ""))
                .font(.title)
                .bold()
            
            // 拖曳區
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(height: 120)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                
                Text(archiveURL?.lastPathComponent ?? NSLocalizedString("drop_zone_hint", comment: ""))
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
                
                if panel.runModal() == .OK, let selectedURL = panel.url {
                    checkMultipartArchiveAndAssign(url: selectedURL)
                }
            }
            
            // 密碼欄位
            HStack {
                Text(NSLocalizedString("password_label", comment: ""))
                SecureField(NSLocalizedString("password_placeholder", comment: ""), text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // 目的地選擇按鈕
            HStack {
                Text(NSLocalizedString("destination_label", comment: ""))
                if let dest = destinationURL {
                    Text(dest.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                }
                Button(NSLocalizedString("choose_folder", comment: "")) {
                    selectDestinationFolder()
                }
            }
            .padding(.horizontal)
            
            // 開始解壓按鈕
            Button(action: {
                if isExtracting {
                    return
                }
                guard let archiveURL = archiveURL else { return }
                let ext = archiveURL.pathExtension.lowercased()
                isExtracting = true
                extractionStatus = NSLocalizedString("status_extracting", comment: "")
                
                if ext == "rar" {
                    extractRAR()
                } else if ext == "7z" || ext == "zip" {
                    extract7zOrZIP()
                } else if ext == "tar.gz" || ext == "tgz" || archiveURL.lastPathComponent.lowercased().hasSuffix(".tar.gz") {
                    extractTAR()
                } else if ext == "tar" {
                    extractTAR()
                } else if ext == "tar.bz2" || ext == "tbz" || archiveURL.lastPathComponent.lowercased().hasSuffix(".tar.bz2") {
                    extractTARBZ2()
                } else {
                    extractionStatus = NSLocalizedString("unsupported_format", comment: "")
                    isExtracting = false
                }
            }) {
                Text(NSLocalizedString("start_extract", comment: ""))
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
                    ProgressView(value: progressValue)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding(.horizontal)
                } else if extractionStatus.localizedCaseInsensitiveContains("failed") || extractionStatus.localizedCaseInsensitiveContains("錯誤") {
                    ScrollView {
                        Text(extractionStatus)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .frame(height: 120)
                }
            }
            
            Spacer()
            
            // 關於我按鈕
            Button(NSLocalizedString("about", comment: "")) {
                showingAbout = true
            }
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
            // 讀取由 Extension 傳入的壓縮檔路徑
            else if let launchPath = UserDefaults.standard.string(forKey: "launchFilePath"),
                    FileManager.default.fileExists(atPath: launchPath) {
                archiveURL = URL(fileURLWithPath: launchPath)
                UserDefaults.standard.removeObject(forKey: "launchFilePath")
            }
        }
        .preferredColorScheme({
            switch selectedAppearance {
            case "light": return .light
            case "dark": return .dark
            default: return nil
            }
        }())
        .sheet(isPresented: $showingAbout) {
            VStack(spacing: 20) {
                Text(NSLocalizedString("about_title", comment: ""))
                    .font(.title)
                    .bold()
                Text(NSLocalizedString("about_description", comment: ""))
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("about_author", comment: ""))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Button(NSLocalizedString("close", comment: "")) {
                    showingAbout = false
                }
                .padding(.top)
            }
            .padding(40)
            .frame(minWidth: 300)
        }
    }
    
    private func extract7zOrZIP() {
        DispatchQueue.main.async {
            self.extractionStatus = ""
            self.progressValue = 0.0
            self.isExtracting = true
        }
        guard let archiveURL = archiveURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_file", comment: "")
                isExtracting = false
            }
            return
        }
        guard let destinationURL = destinationURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_destination", comment: "")
                isExtracting = false
            }
            return
        }
        // 目的地檢查：資料夾存在且可寫入
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 目的地資料夾不存在：\(destinationURL.path)"
                isExtracting = false
            }
            return
        }
        if !FileManager.default.isWritableFile(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 無法寫入目的地：\(destinationURL.path)\n請重新選擇資料夾或授權權限。"
                isExtracting = false
            }
            return
        }
        // Security scoped resource access
        guard destinationURL.startAccessingSecurityScopedResource() else {
            DispatchQueue.main.async {
                extractionStatus = "❌ 資料夾授權已失效，請重新選擇輸出資料夾"
                isExtracting = false
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                progressValue = 0.2
            }
            // 不在這裡 stopAccessingSecurityScopedResource，等 terminationHandler
            
            guard let bundle7zPath = Bundle.main.resourceURL?.appendingPathComponent("7za") else {
                DispatchQueue.main.async {
                    extractionStatus = NSLocalizedString("not_found_7za", comment: "")
                    isExtracting = false
                }
                return
            }
            
            guard FileManager.default.fileExists(atPath: bundle7zPath.path) else {
                DispatchQueue.main.async {
                    extractionStatus = NSLocalizedString("not_found_7za_bundle", comment: "")
                    isExtracting = false
                }
                return
            }
            
            try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            
            let process = Process()
            process.executableURL = bundle7zPath
            
            let passwordArg = password.isEmpty ? nil : "-p\(password)"
            var arguments = ["x", "-y", archiveURL.path, "-o\(destinationURL.path)"]
            if let pwd = passwordArg {
                arguments.insert(pwd, at: 2)
            }
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            var output = ""
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                    output += chunk
                }
            }
            
            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                pipe.fileHandleForReading.closeFile()
                destinationURL.stopAccessingSecurityScopedResource()
                DispatchQueue.main.async {
                    print("🧃 7z/ZIP 解壓輸出：\n\(output)")
                    print("🧃 程式退出碼：\(proc.terminationStatus)")
                    if proc.terminationStatus == 0 {
                        extractionStatus = NSLocalizedString("status_7z_zip_success", comment: "")
                        progressValue = 1.0
                    } else {
                        extractionStatus = String(format: NSLocalizedString("status_7z_zip_failed", comment: ""), output)
                        progressValue = 0.0
                    }
                    isExtracting = false
                }
            }
            
            do {
                try process.run()
                DispatchQueue.main.async {
                    progressValue = 0.5
                }
            } catch {
                DispatchQueue.main.async {
                    extractionStatus = String(format: NSLocalizedString("status_7z_zip_error", comment: ""), error.localizedDescription)
                    isExtracting = false
                    progressValue = 0.0
                }
                destinationURL.stopAccessingSecurityScopedResource()
            }
        }
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
        DispatchQueue.main.async {
            self.extractionStatus = ""
            self.progressValue = 0.0
            self.isExtracting = true
        }
        guard let archiveURL = archiveURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_file", comment: "")
                isExtracting = false
            }
            return
        }
        // 強制要求使用者選擇目的地
        guard let destinationURL = destinationURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_destination", comment: "")
                isExtracting = false
            }
            return
        }
        // 目的地檢查：資料夾存在且可寫入
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 目的地資料夾不存在：\(destinationURL.path)"
                isExtracting = false
            }
            return
        }
        if !FileManager.default.isWritableFile(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 無法寫入目的地：\(destinationURL.path)\n請重新選擇資料夾或授權權限。"
                isExtracting = false
            }
            return
        }
        // Security scoped resource access
        guard destinationURL.startAccessingSecurityScopedResource() else {
            DispatchQueue.main.async {
                extractionStatus = "❌ 資料夾授權已失效，請重新選擇輸出資料夾"
                isExtracting = false
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                progressValue = 0.2
            }
            // defer 不在這裡 stopAccessingSecurityScopedResource，等 terminationHandler
            
            // 使用 App Bundle 內建的 unrar binary
            guard let bundleUnrarPath = Bundle.main.resourceURL?.appendingPathComponent("unrar") else {
                DispatchQueue.main.async {
                    extractionStatus = NSLocalizedString("not_found_unrar", comment: "")
                    isExtracting = false
                }
                return
            }
            
            // Debug: 輸出 unrar 路徑
            print("🧭 嘗試執行路徑：\(bundleUnrarPath.path)")
            
            // 檢查 unrar 是否存在於 bundle
            guard FileManager.default.fileExists(atPath: bundleUnrarPath.path) else {
                DispatchQueue.main.async {
                    extractionStatus = NSLocalizedString("not_found_unrar_bundle", comment: "")
                    isExtracting = false
                }
                return
            }
            
            let passwordArg = password.isEmpty ? "-p-" : "-p\(password)"
            
            // 確保目的地資料夾存在
            try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            
            let process = Process()
            process.executableURL = bundleUnrarPath
            process.arguments = ["x", "-y", passwordArg, archiveURL.path, destinationURL.path]
            
            // 分開 stdout/stderr
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            var output = ""
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                    output += chunk
                }
            }
            var errorOutput = ""
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                    errorOutput += chunk
                }
            }
            
            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()
                destinationURL.stopAccessingSecurityScopedResource()
                DispatchQueue.main.async {
                    print("🔧 解壓輸出：\n\(output)")
                    print("🧨 stderr：\n\(errorOutput)")
                    print("🔧 程式退出碼：\(proc.terminationStatus)")
                    if proc.terminationStatus == 0 {
                        extractionStatus = NSLocalizedString("status_rar_success", comment: "")
                        progressValue = 1.0
                        isExtracting = false
                    } else {
                        // 新增檢查 checksum error/CRC failed
                        let combinedOutput = output + "\n" + errorOutput
                        if combinedOutput.localizedCaseInsensitiveContains("checksum error") ||
                            combinedOutput.localizedCaseInsensitiveContains("crc failed") {
                            extractionStatus = NSLocalizedString("status_rar_corrupt_or_missing", comment: "")
                        } else {
                            let errorDetail = """
\(NSLocalizedString("status_rar_failed", comment: ""))
\n\(errorOutput.isEmpty ? output : errorOutput)
"""
                            extractionStatus = errorDetail
                        }
                        progressValue = 0.0
                        isExtracting = false
                    }
                }
            }
            
            do {
                try process.run()
                DispatchQueue.main.async {
                    progressValue = 0.5
                }
            } catch {
                DispatchQueue.main.async {
                    extractionStatus = String(format: NSLocalizedString("status_rar_error", comment: ""), error.localizedDescription)
                    isExtracting = false
                    progressValue = 0.0
                }
                destinationURL.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    private func extractTAR() {
        DispatchQueue.main.async {
            self.extractionStatus = ""
            self.progressValue = 0.0
            self.isExtracting = true
        }
        guard let archiveURL = archiveURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_file", comment: "")
                isExtracting = false
            }
            return
        }
        guard let destinationURL = destinationURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_destination", comment: "")
                isExtracting = false
            }
            return
        }
        // 目的地檢查：資料夾存在且可寫入
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 目的地資料夾不存在：\(destinationURL.path)"
                isExtracting = false
            }
            return
        }
        if !FileManager.default.isWritableFile(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 無法寫入目的地：\(destinationURL.path)\n請重新選擇資料夾或授權權限。"
                isExtracting = false
            }
            return
        }
        // Security scoped resource access
        guard destinationURL.startAccessingSecurityScopedResource() else {
            DispatchQueue.main.async {
                extractionStatus = "❌ 資料夾授權已失效，請重新選擇輸出資料夾"
                isExtracting = false
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                progressValue = 0.2
            }
            // defer 不在這裡 stopAccessingSecurityScopedResource，等 terminationHandler
            
            let tarPath = "/usr/bin/tar"
            guard FileManager.default.fileExists(atPath: tarPath) else {
                DispatchQueue.main.async {
                    extractionStatus = NSLocalizedString("not_found_tar", comment: "")
                    isExtracting = false
                }
                return
            }
            
            try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tarPath)
            // tar -xzf archive -C destination
            process.arguments = ["-xzf", archiveURL.path, "-C", destinationURL.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            var output = ""
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                    output += chunk
                }
            }
            
            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                pipe.fileHandleForReading.closeFile()
                destinationURL.stopAccessingSecurityScopedResource()
                DispatchQueue.main.async {
                    print("📦 tar 解壓輸出：\n\(output)")
                    print("📦 程式退出碼：\(proc.terminationStatus)")
                    if proc.terminationStatus == 0 {
                        extractionStatus = NSLocalizedString("status_tar_success", comment: "")
                        progressValue = 1.0
                    } else {
                        extractionStatus = String(format: NSLocalizedString("status_tar_failed", comment: ""), output)
                        progressValue = 0.0
                    }
                    isExtracting = false
                }
            }
            
            do {
                try process.run()
                DispatchQueue.main.async {
                    progressValue = 0.5
                }
            } catch {
                DispatchQueue.main.async {
                    extractionStatus = String(format: NSLocalizedString("status_tar_error", comment: ""), error.localizedDescription)
                    isExtracting = false
                    progressValue = 0.0
                }
                destinationURL.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    private func extractTARBZ2() {
        DispatchQueue.main.async {
            self.extractionStatus = ""
            self.progressValue = 0.0
            self.isExtracting = true
        }
        guard let archiveURL = archiveURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_file", comment: "")
                isExtracting = false
            }
            return
        }
        guard let destinationURL = destinationURL else {
            DispatchQueue.main.async {
                extractionStatus = NSLocalizedString("please_choose_destination", comment: "")
                isExtracting = false
            }
            return
        }
        // 目的地檢查：資料夾存在且可寫入
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 目的地資料夾不存在：\(destinationURL.path)"
                isExtracting = false
            }
            return
        }
        if !FileManager.default.isWritableFile(atPath: destinationURL.path) {
            DispatchQueue.main.async {
                extractionStatus = "❌ 無法寫入目的地：\(destinationURL.path)\n請重新選擇資料夾或授權權限。"
                isExtracting = false
            }
            return
        }
        // Security scoped resource access
        guard destinationURL.startAccessingSecurityScopedResource() else {
            DispatchQueue.main.async {
                extractionStatus = "❌ 資料夾授權已失效，請重新選擇輸出資料夾"
                isExtracting = false
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                progressValue = 0.2
            }
            // defer 不在這裡 stopAccessingSecurityScopedResource，等 terminationHandler
            
            let tarPath = "/usr/bin/tar"
            guard FileManager.default.fileExists(atPath: tarPath) else {
                DispatchQueue.main.async {
                    extractionStatus = NSLocalizedString("not_found_tar", comment: "")
                    isExtracting = false
                }
                return
            }
            
            try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tarPath)
            // tar -xjf archive -C destination
            process.arguments = ["-xjf", archiveURL.path, "-C", destinationURL.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            var output = ""
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                    output += chunk
                }
            }
            
            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                pipe.fileHandleForReading.closeFile()
                destinationURL.stopAccessingSecurityScopedResource()
                DispatchQueue.main.async {
                    print("📦 tar.bz2 解壓輸出：\n\(output)")
                    print("📦 程式退出碼：\(proc.terminationStatus)")
                    if proc.terminationStatus == 0 {
                        extractionStatus = NSLocalizedString("status_tarbz2_success", comment: "")
                        progressValue = 1.0
                    } else {
                        extractionStatus = String(format: NSLocalizedString("status_tarbz2_failed", comment: ""), output)
                        progressValue = 0.0
                    }
                    isExtracting = false
                }
            }
            
            do {
                try process.run()
                DispatchQueue.main.async {
                    progressValue = 0.5
                }
            } catch {
                DispatchQueue.main.async {
                    extractionStatus = String(format: NSLocalizedString("status_tarbz2_error", comment: ""), error.localizedDescription)
                    isExtracting = false
                    progressValue = 0.0
                }
                destinationURL.stopAccessingSecurityScopedResource()
            }
        }
    }
    // 檢查是否為分片壓縮檔（multi-part RAR），並指派 archiveURL 或顯示錯誤
    private func checkMultipartArchiveAndAssign(url: URL) {
        let filename = url.lastPathComponent.lowercased()
        let folder = url.deletingLastPathComponent()
        
        if filename.range(of: #"part0*\d+\.rar$"#, options: .regularExpression) != nil {
            // 是分片壓縮檔，找出所有相關分片
            let basePrefix = filename.replacingOccurrences(of: #"(?i)part\d+\.rar$"#, with: "", options: .regularExpression)
            
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
                    .filter { $0.lowercased().hasPrefix(basePrefix) && $0.lowercased().hasSuffix(".rar") }
                    .sorted()
                
                // 檢查是否包含 part01
                let partNumbers = files.compactMap {
                    let pattern = #"(?i)part(\d+)\.rar"#
                    if let match = $0.range(of: pattern, options: .regularExpression) {
                        let matched = String($0[match])
                        let numStr = matched
                            .replacingOccurrences(of: "part", with: "", options: [.caseInsensitive])
                            .replacingOccurrences(of: ".rar", with: "", options: [.caseInsensitive])
                        return Int(numStr)
                    }
                    return nil
                }
                
                guard partNumbers.contains(1) else {
                    extractionStatus = "❌ 無法找到起始的 .part01.rar，請確認檔案是否完整。"
                    return
                }
                
                archiveURL = url // OK，指派
            } catch {
                extractionStatus = "❌ 檢查分片檔案時發生錯誤：\(error.localizedDescription)"
            }
        } else {
            // 非分片檔，直接指定
            archiveURL = url
        }
    }
}
