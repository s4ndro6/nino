#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TEST_BUILD="${NINO_TEST_BUILD_DIR:-$ROOT/Build/Tests}"
python3 "$ROOT/Tests/ReleasePackagingTests.py"
mkdir -p "$TEST_BUILD/Cache"
SWIFT_FLAGS=(-parse-as-library -swift-version 5 -module-cache-path "$TEST_BUILD/Cache")
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/TerminationGate.swift" "$ROOT/Tests/TerminationGateTests.swift" -o "$TEST_BUILD/termination-tests"
"$TEST_BUILD/termination-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/NativeUpdatePolicy.swift" "$ROOT/Tests/NativeUpdatePolicyTests.swift" -o "$TEST_BUILD/native-update-tests"
"$TEST_BUILD/native-update-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/AppUpdates.swift" "$ROOT/Tests/AppUpdatesTests.swift" -o "$TEST_BUILD/update-tests"
"$TEST_BUILD/update-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Delivery.swift" "$ROOT/Tests/DeliveryTests.swift" -o "$TEST_BUILD/delivery-tests"
"$TEST_BUILD/delivery-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Workspace.swift" "$ROOT/Tests/WorkspaceTests.swift" -o "$TEST_BUILD/workspace-tests"
"$TEST_BUILD/workspace-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/RepositoryConnector.swift" "$ROOT/Tests/RepositoryTests.swift" -o "$TEST_BUILD/repository-tests"
"$TEST_BUILD/repository-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/MCP/Server.swift" -o "$TEST_BUILD/nino-mcp"
python3 "$ROOT/Tests/test_mcp.py" --binary "$TEST_BUILD/nino-mcp"

xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Workspace.swift" "$ROOT/Source/Profile.swift" "$ROOT/Source/Workflows.swift" "$ROOT/Tests/ProfileWorkspaceTests.swift" -o "$TEST_BUILD/profile-tests"
"$TEST_BUILD/profile-tests"
# This offline suite does not import the SDK; SDK-linked checks are documented separately.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Domain.swift" "$ROOT/Source/GoogleDesktopAuth.swift" "$ROOT/Source/GoogleAccount.swift" "$ROOT/Tests/GoogleConnectorTests.swift" -o "$TEST_BUILD/google-tests"
"$TEST_BUILD/google-tests"

xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/CallQuestions.swift" "$ROOT/Tests/CallQuestionTests.swift" -o "$TEST_BUILD/call-question-tests"
"$TEST_BUILD/call-question-tests"

# Deterministic answer-state regressions: no recording, local model, account or network.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Domain.swift" "$ROOT/Source/Permissions.swift" "$ROOT/Source/LiveSpeech.swift" "$ROOT/Source/CallQuestions.swift" "$ROOT/Source/CallMemory.swift" "$ROOT/Source/IntelligenceAPI.swift" "$ROOT/Source/CallCloud.swift" "$ROOT/Source/CallAssistant.swift" "$ROOT/Tests/CallAnswerSnapshotTests.swift" -o "$TEST_BUILD/call-answer-snapshots"
"$TEST_BUILD/call-answer-snapshots"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Domain.swift" "$ROOT/Source/Permissions.swift" "$ROOT/Source/LiveSpeech.swift" "$ROOT/Source/CallQuestions.swift" "$ROOT/Source/CallMemory.swift" "$ROOT/Source/IntelligenceAPI.swift" "$ROOT/Source/CallCloud.swift" "$ROOT/Source/CallAssistant.swift" "$ROOT/Tests/CallContextTests.swift" -o "$TEST_BUILD/call-context-tests"
"$TEST_BUILD/call-context-tests"

# Permission state machinery: no OS prompt or microphone opened.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Permissions.swift" "$ROOT/Tests/PermissionTests.swift" -o "$TEST_BUILD/permission-tests"
"$TEST_BUILD/permission-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/StickyNotes.swift" "$ROOT/Tests/StickyNotesTests.swift" -o "$TEST_BUILD/sticky-tests"
"$TEST_BUILD/sticky-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/WorkEvidence.swift" "$ROOT/Tests/WorkEvidenceTests.swift" -o "$TEST_BUILD/evidence-tests"
"$TEST_BUILD/evidence-tests"
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Workspace.swift" "$ROOT/Source/AgentAttention.swift" "$ROOT/Tests/AgentAttentionTests.swift" -o "$TEST_BUILD/attention-tests"
"$TEST_BUILD/attention-tests"
# AAC writer recovery with synthetic buffers only; never captures real audio.
xcrun swiftc "${SWIFT_FLAGS[@]}" -D NINO_TESTING -target arm64-apple-macosx15.0 "$ROOT/Source/Domain.swift" "$ROOT/Source/Permissions.swift" "$ROOT/Source/Capture.swift" "$ROOT/Tests/CaptureRecoveryTests.swift" -o "$TEST_BUILD/capture-recovery"
"$TEST_BUILD/capture-recovery" "$TEST_BUILD/synthetic-recovery-$(date +%s).m4a"

# Optional usage counters, fake transport only: never sends real application data.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/UsageAnalytics.swift" "$ROOT/Tests/UsageAnalyticsTests.swift" -o "$TEST_BUILD/usage-analytics-tests"
"$TEST_BUILD/usage-analytics-tests"
# Reference SQLite collector; only synthetic localhost requests.
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$ROOT/Analytics" -p 'test_*.py'

# Decorative choreography: no screen capture or UI control.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/CompanionWalk.swift" "$ROOT/Tests/CompanionWalkTests.swift" -o "$TEST_BUILD/walk-tests"
"$TEST_BUILD/walk-tests"

# Installed storage must not follow the app bundle or recreate a missing portable volume.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/NinoPaths.swift" "$ROOT/Tests/NinoPathsTests.swift" -o "$TEST_BUILD/path-tests"
"$TEST_BUILD/path-tests"

# No microphone/network: verified models, native audio conversion and playback recovery.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Domain.swift" "$ROOT/Source/NinoPaths.swift" "$ROOT/Source/TranscriptionModel.swift" "$ROOT/Source/AudioPreparation.swift" "$ROOT/Source/AudioPlayback.swift" "$ROOT/Tests/VoicePipelineTests.swift" -o "$TEST_BUILD/voice-tests"
"$TEST_BUILD/voice-tests"

# Pure API contracts: synthetic credentials, no external request or Keychain mutation by default.
xcrun swiftc "${SWIFT_FLAGS[@]}" "$ROOT/Source/Domain.swift" "$ROOT/Source/IntelligenceAPI.swift" "$ROOT/Tests/IntelligenceAPITests.swift" -o "$TEST_BUILD/intelligence-tests"
"$TEST_BUILD/intelligence-tests"
