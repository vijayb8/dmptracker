#!/usr/bin/env python3
"""Rebuild the dependency-free Xcode project deterministically."""
from pathlib import Path
import hashlib
import plistlib
root = Path(__file__).resolve().parents[1]
def ident(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def q(value): return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
objects = []
def obj(key, body): objects.append(f'{ident(key)} = {{ {body} }};')
sources = sorted(root.glob('App/*.swift')) + sorted(root.glob('Sources/DMPCore/*.swift'))
for path in sources:
    rel = path.relative_to(root).as_posix()
    obj('ref'+rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = "<group>";')
    obj('build'+rel, f'isa = PBXBuildFile; fileRef = {ident("ref"+rel)};')
obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DMPBegleiter.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('assetsRef', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = App/Assets.xcassets; sourceTree = "<group>";')
obj('assetsBuild', f'isa = PBXBuildFile; fileRef = {ident("assetsRef")};')
obj('products', f'isa = PBXGroup; children = ({ident("product")},); name = Products; sourceTree = "<group>";')
obj('rootgroup', 'isa = PBXGroup; children = (' + ','.join([ident('ref'+p.relative_to(root).as_posix()) for p in sources] + [ident('assetsRef'), ident('products')]) + ',); sourceTree = "<group>";')
obj('sources', 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(ident('build'+p.relative_to(root).as_posix()) for p in sources) + ',); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({ident("assetsBuild")},); runOnlyForDeploymentPostprocessing = 0;')
for mode in ['Debug', 'Release']:
    project_settings = f'CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = {q("-Onone" if mode == "Debug" else "-O")}; DEBUG_INFORMATION_FORMAT = {q("dwarf" if mode == "Debug" else "dwarf-with-dsym")};'
    if mode == 'Debug': project_settings += ' SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;'
    obj('project'+mode, f'isa = XCBuildConfiguration; buildSettings = {{ {project_settings} }}; name = {mode};')
    target_settings = 'PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.vijayb8.dmptracker; INFOPLIST_FILE = App/Info.plist; GENERATE_INFOPLIST_FILE = NO; CODE_SIGN_STYLE = Automatic; TARGETED_DEVICE_FAMILY = "1,2"; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 0.1.0; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; SWIFT_EMIT_LOC_STRINGS = YES;'
    obj('target'+mode, f'isa = XCBuildConfiguration; buildSettings = {{ {target_settings} }}; name = {mode};')
for key in ['project', 'target']:
    obj(key+'config', f'isa = XCConfigurationList; buildConfigurations = ({ident(key+"Debug")},{ident(key+"Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("targetconfig")}; buildPhases = ({ident("sources")},{ident("frameworks")},{ident("resources")},); buildRules = (); dependencies = (); name = DMPBegleiter; productName = DMPBegleiter; productReference = {ident("product")}; productType = "com.apple.product-type.application";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {ident("projectconfig")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = de; hasScannedForEncodings = 0; knownRegions = (de,en,Base,); mainGroup = {ident("rootgroup")}; productRefGroup = {ident("products")}; projectDirPath = ""; projectRoot = ""; targets = ({ident("target")},);')
(root/'DMPBegleiter.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {ident("project")}; }}\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('target')}" BuildableName="DMPBegleiter.app" BlueprintName="DMPBegleiter" ReferencedContainer="container:DMPBegleiter.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('target')}" BuildableName="DMPBegleiter.app" BlueprintName="DMPBegleiter" ReferencedContainer="container:DMPBegleiter.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root/'DMPBegleiter.xcodeproj/xcshareddata/xcschemes/DMPBegleiter.xcscheme').write_text(scheme)
info = {
 'CFBundleDevelopmentRegion': 'de', 'CFBundleDisplayName': 'DMP Begleiter', 'CFBundleExecutable': '$(EXECUTABLE_NAME)',
 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion':'6.0', 'CFBundleName':'$(PRODUCT_NAME)',
 'CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)',
 'LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},
 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
 'NSCameraUsageDescription':'Scanne deine DMP-Berichte zur lokalen Erfassung.',
 'NSFaceIDUsageDescription':'Schütze den Zugriff auf deine persönlichen Gesundheitsdaten.'
}
with (root/'App/Info.plist').open('wb') as f: plistlib.dump(info,f)
print(f'Generated Xcode project with {len(sources)} Swift sources.')
