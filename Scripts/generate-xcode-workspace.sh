#!/bin/bash
# Generates .swiftpm/xcode/package.xcworkspace, shared scheme, and test plan.
# Needed by CI so xcodebuild can resolve the SwiftPM package and run UI tests.
# Xcode creates these files automatically when opening Package.swift locally.

set -euo pipefail

SRCROOT="${SRCROOT:-$(pwd)}"
cd "$SRCROOT"

WORKSPACE_DIR=".swiftpm/xcode/package.xcworkspace"
SCHEME_DIR=".swiftpm/xcode/xcshareddata/xcschemes"

mkdir -p "$WORKSPACE_DIR" "$SCHEME_DIR"

cat > "$WORKSPACE_DIR/contents.xcworkspacedata" <<- EOF
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
EOF

PANORA_APP_PATH="${SRCROOT}/.build/debug/Panora.app"

cat > "$SCHEME_DIR/Panora.xcscheme" <<- EOF
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2650"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "Panora"
               BuildableName = "Panora"
               BlueprintName = "Panora"
               ReferencedContainer = "container:">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
       shouldUseLaunchSchemeArgsEnv = "YES">
       <TestPlanReference
          reference = "container:PanoraUITests.xctestplan"
          default = "YES">
       </TestPlanReference>
       <Testables>
          <TestableReference
             skipped = "NO">
             <BuildableReference
                BuildableIdentifier = "primary"
                BlueprintIdentifier = "PanoraUITests"
                BuildableName = "PanoraUITests"
                BlueprintName = "PanoraUITests"
                ReferencedContainer = "container:">
             </BuildableReference>
          </TestableReference>
       </Testables>
    </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "Panora"
            BuildableName = "Panora"
            BlueprintName = "Panora"
            ReferencedContainer = "container:">
         </BuildableReference>
      </BuildableProductRunnable>
      <EnvironmentVariables>
         <EnvironmentVariable
            key = "PANORA_RUN_UI_TESTS"
            value = "1"
            isEnabled = "YES">
         </EnvironmentVariable>
      </EnvironmentVariables>
    </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "Panora"
            BuildableName = "Panora"
            BlueprintName = "Panora"
            ReferencedContainer = "container:">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOF

cat > "$WORKSPACE_DIR/PanoraUITests.xctestplan" <<- PLANEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>testTargets</key>
    <array>
        <dict>
            <key>targetIdentifier</key>
            <string>PanoraUITests</string>
            <key>targetName</key>
            <string>PanoraUITests</string>
            <key>testBundleType</key>
            <string>XCTestBundleTypeUI</string>
            <key>isEnabled</key>
            <true/>
            <key>environmentVariableEntries</key>
            <array>
                <dict>
                    <key>key</key>
                    <string>PANORA_RUN_UI_TESTS</string>
                    <key>value</key>
                    <string>1</string>
                    <key>enabled</key>
                    <true/>
                </dict>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLANEOF

echo "✅ Generated $WORKSPACE_DIR/PanoraUITests.xctestplan"
echo "✅ Generated $SCHEME_DIR/Panora.xcscheme"
