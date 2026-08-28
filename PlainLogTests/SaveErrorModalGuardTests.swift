import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.8 — SaveErrorModalGuard is a pure decision model (no
/// I/O), so these are plain input/output assertions.
final class SaveErrorModalGuardTests: XCTestCase {

    func testIsFailureState() {
        XCTAssertTrue(SaveErrorModalGuard.isFailureState(.saveFailed(reason: "x")))
        XCTAssertTrue(SaveErrorModalGuard.isFailureState(.accessLostDuringSave))

        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.idle))
        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.waitingToSave))
        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.saving))
        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.saved))
        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.conflictDetectedDuringSave))
        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.targetFileAlreadyExists))
        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.conflictDetected))
        XCTAssertFalse(SaveErrorModalGuard.isFailureState(.fileDeletedExternally))
    }

    func testFirstFailureShowsAndActivatesEpisode() {
        let outcome = SaveErrorModalGuard.evaluate(state: .saveFailed(reason: "x"), episodeActive: false)
        XCTAssertTrue(outcome.shouldShow)
        XCTAssertTrue(outcome.episodeActive)
    }

    /// The core "no re-trigger loop" guarantee: a second failure while the
    /// episode is already active must not show the modal again.
    func testRepeatedFailureWithinActiveEpisodeDoesNotReShow() {
        let outcome = SaveErrorModalGuard.evaluate(state: .saveFailed(reason: "x"), episodeActive: true)
        XCTAssertFalse(outcome.shouldShow)
        XCTAssertTrue(outcome.episodeActive)
    }

    func testDifferentFailureReasonWithinActiveEpisodeStillDoesNotReShow() {
        let outcome = SaveErrorModalGuard.evaluate(state: .accessLostDuringSave, episodeActive: true)
        XCTAssertFalse(outcome.shouldShow)
        XCTAssertTrue(outcome.episodeActive)
    }

    func testSavedClearsTheEpisode() {
        let outcome = SaveErrorModalGuard.evaluate(state: .saved, episodeActive: true)
        XCTAssertFalse(outcome.shouldShow)
        XCTAssertFalse(outcome.episodeActive)
    }

    func testIdleClearsTheEpisode() {
        let outcome = SaveErrorModalGuard.evaluate(state: .idle, episodeActive: true)
        XCTAssertFalse(outcome.shouldShow)
        XCTAssertFalse(outcome.episodeActive)
    }

    /// A failure AFTER the episode was explicitly reset (e.g. the user
    /// tapped Retry) is treated as a new episode and shows again.
    func testFailureAfterEpisodeResetShowsAgain() {
        let outcome = SaveErrorModalGuard.evaluate(state: .saveFailed(reason: "x"), episodeActive: false)
        XCTAssertTrue(outcome.shouldShow)
        XCTAssertTrue(outcome.episodeActive)
    }

    func testInFlightStateDoesNotResolveTheEpisodeEitherWay() {
        let stillActive = SaveErrorModalGuard.evaluate(state: .saving, episodeActive: true)
        XCTAssertFalse(stillActive.shouldShow)
        XCTAssertTrue(stillActive.episodeActive)

        let stillInactive = SaveErrorModalGuard.evaluate(state: .saving, episodeActive: false)
        XCTAssertFalse(stillInactive.shouldShow)
        XCTAssertFalse(stillInactive.episodeActive)
    }
}
