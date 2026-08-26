import Foundation

/// Every error FileIOService can surface.
/// Local-first rule (CLAUDE.md): never crash — callers map these to
/// user-facing states (Save states / File states, PLAN.md §9).
/// Associated values are Strings (not Error) so the enum is Equatable for tests.
enum FileIOError: Error, Equatable {
    /// The target is an iCloud item that is not downloaded locally.
    /// Callers must run the download flow (Feature 07). Never read or
    /// overwrite cloud-only files blindly (PLAN.md §4).
    case cloudOnlyFileNotDownloaded

    /// The file does not exist (read path).
    case fileNotFound

    /// The file could not be decoded as UTF-8 (PLAN.md §11: UTF-8 only).
    case encodingFailed

    /// NSFileCoordinator reported an error.
    case coordinationFailed(String)

    /// The coordination block never ran and no coordinator error was reported.
    case coordinationDidNotRun

    /// Underlying filesystem failure.
    case underlying(String)
}
