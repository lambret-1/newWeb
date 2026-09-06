import Foundation
import UIKit

/// 下载管理：URLSession 下载任务（支持暂停 / 续传 / 取消）。
/// 完成文件保存到 Documents/Downloads，事件经回调上抛（由 NativeBridgePlugin 转发给 Dart）。
class DownloadManager: NSObject {
  static let shared = DownloadManager()

  private var session: URLSession!
  private var tasks: [String: URLSessionDownloadTask] = [:]
  private var resumeData: [String: Data] = [:]

  /// 下载事件回调：event 名称 + 参数（taskId / url / received / total / path / name / message）。
  var onEvent: ((String, [String: Any]) -> Void)?

  private override init() {
    super.init()
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 60
    session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }

  /// 下载目录（Documents/Downloads）。
  static var downloadDirectory: URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let dir = docs.appendingPathComponent("Downloads", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  func start(url: String, taskId: String) {
    guard let u = URL(string: url) else {
      onEvent?("error", ["taskId": taskId, "message": "无效链接"])
      return
    }
    let task = session.downloadTask(with: u)
    task.taskDescription = taskId
    tasks[taskId] = task
    task.resume()
    onEvent?("started", ["taskId": taskId, "url": url])
  }

  func pause(taskId: String) {
    guard let task = tasks[taskId] else { return }
    task.cancel { [weak self] data in
      guard let self = self else { return }
      if let data = data {
        self.resumeData[taskId] = data
      }
      self.tasks[taskId] = nil
      self.onEvent?("paused", ["taskId": taskId])
    }
  }

  func resume(taskId: String, url: String) {
    if let data = resumeData[taskId] {
      let task = session.downloadTask(withResumeData: data)
      task.taskDescription = taskId
      tasks[taskId] = task
      task.resume()
      onEvent?("resumed", ["taskId": taskId])
    } else {
      start(url: url, taskId: taskId)
    }
  }

  func cancel(taskId: String) {
    tasks[taskId]?.cancel()
    tasks[taskId] = nil
    resumeData[taskId] = nil
    onEvent?("cancelled", ["taskId": taskId])
  }
}

extension DownloadManager: URLSessionDownloadDelegate {
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard let taskId = downloadTask.taskDescription else { return }
    onEvent?("progress", [
      "taskId": taskId,
      "received": totalBytesWritten,
      "total": totalBytesExpectedToWrite,
    ])
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let taskId = downloadTask.taskDescription else { return }
    let dir = DownloadManager.downloadDirectory
    let originalName =
      downloadTask.response?.suggestedFilename
      ?? "下载文件_\(Int(Date().timeIntervalSince1970)).dat"
    var dest = dir.appendingPathComponent(originalName)
    // 重名去重
    var counter = 1
    while FileManager.default.fileExists(atPath: dest.path) {
      let ext = dest.pathExtension
      let base = dest.deletingPathExtension().lastPathComponent
      let newName = ext.isEmpty ? "\(base)(\(counter))" : "\(base)(\(counter)).\(ext)"
      dest = dir.appendingPathComponent(newName)
      counter += 1
    }
    do {
      try FileManager.default.moveItem(at: location, to: dest)
      tasks[taskId] = nil
      resumeData[taskId] = nil
      onEvent?("completed", [
        "taskId": taskId,
        "path": dest.path,
        "name": dest.lastPathComponent,
      ])
    } catch {
      onEvent?("error", ["taskId": taskId, "message": error.localizedDescription])
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let taskId = task.taskDescription else { return }
    if let error = error {
      if (error as NSError).code == NSURLErrorCancelled { return }
      onEvent?("error", ["taskId": taskId, "message": error.localizedDescription])
    }
  }
}
