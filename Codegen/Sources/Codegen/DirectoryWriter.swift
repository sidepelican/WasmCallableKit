import Foundation

struct DirectoryWriter {
    var dstDirectory: URL
    var fileManager = FileManager()
    var isOutputFileName: ((_ filename: String) -> Bool)?

    struct OutputFile {
        var relativeURL: URL
        var content: String
    }

    class OutputSink {
        init(dstDirectory: URL, fileManager: FileManager) {
            self.dstDirectory = dstDirectory
            self.fileManager = fileManager
        }

        var files: Set<String> = []
        var dstDirectory: URL
        var fileManager: FileManager

        func callAsFunction(file: OutputFile) throws {
            let dst = dstDirectory.appendingPathComponent(file.relativeURL.relativePath)
            try fileManager.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.content.data(using: .utf8)!
                .write(to: dst, options: .atomic)
            print("generated...", file.relativeURL.relativePath)
            files.insert(file.relativeURL.relativePath)
        }
    }

    func run(_ perform: (_ write: OutputSink) throws -> ()) throws {
        let sink = OutputSink(dstDirectory: dstDirectory, fileManager: fileManager)
        try fileManager.createDirectory(at: dstDirectory, withIntermediateDirectories: true)
        try perform(sink)

        // リネームなどによって不要になった生成物を出力ディレクトリから削除
        for dstFile in try fileManager.subpathsOfDirectory(atPath: dstDirectory.path) {
            if let isOutputFileName = isOutputFileName, !isOutputFileName(URL(fileURLWithPath: dstFile).lastPathComponent) {
                continue
            }
            if !sink.files.contains(dstFile) {
                try fileManager.removeItem(at: dstDirectory.appendingPathComponent(dstFile))
            }
        }
    }

    private func findFiles(in directory: URL) -> [String] {
        (fileManager.subpaths(atPath: directory.path) ?? [])
            .filter {
                !fileManager.isDirectory(at: directory.appendingPathComponent($0))
            }
    }
}

extension FileManager {
    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        if fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return false
    }
}
