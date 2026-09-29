#!/usr/bin/env python3
"""Create a dependency-free iOS Xcode project. Run on macOS before xcodebuild."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parents[1]
project=root/'GalaGo.xcodeproj'
project.mkdir(exist_ok=True)
def oid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def quoted(s): return json.dumps(str(s))
files=sorted(list((root/'iOS').glob('*.swift'))+list((root/'Sources/GalaCore').glob('*.swift')))
objects=[]
def obj(key,value): objects.append(f'{oid(key)} = {{ {value} }};')
source_refs=[];build_refs=[]
for p in files:
 rel=str(p.relative_to(root));r='file:'+rel;b='build:'+rel
 obj(r,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(rel)}; sourceTree = "<group>";');source_refs.append(oid(r))
 obj(b,f'isa = PBXBuildFile; fileRef = {oid(r)};');build_refs.append(oid(b))
obj('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/Assets.xcassets; sourceTree = "<group>";')
obj('assetsbuild',f'isa = PBXBuildFile; fileRef = {oid("assets")};')
obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = GalaGo.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('products',f'isa = PBXGroup; children = ({oid("product")}); name = Products; sourceTree = "<group>";')
obj('main',f'isa = PBXGroup; children = ({",".join(source_refs+[oid("assets"),oid("products")])}); sourceTree = "<group>";')
obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(build_refs)}); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({oid("assetsbuild")}); runOnlyForDeploymentPostprocessing = 0;')
for cfg in ['Debug','Release']:
 common={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'16.0','CLANG_ENABLE_MODULES':'YES','SWIFT_VERSION':'5.0','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if cfg=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if cfg=='Debug' else 'dwarf-with-dsym'}
 app={'PRODUCT_BUNDLE_IDENTIFIER':'com.rvmendillo.galago','PRODUCT_NAME':'GalaGo','INFOPLIST_FILE':'iOS/Info.plist','GENERATE_INFOPLIST_FILE':'NO','TARGETED_DEVICE_FAMILY':'1,2','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CODE_SIGN_STYLE':'Manual','CODE_SIGNING_ALLOWED':'NO','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','SWIFT_EMIT_LOC_STRINGS':'NO'}
 for kind,settings in [('project',common),('target',app)]:
  obj(kind+cfg,f'isa = XCBuildConfiguration; name = {cfg}; buildSettings = {{'+''.join(f'{k} = {quoted(v)};' for k,v in settings.items())+'};')
for kind in ['project','target']:obj(kind+'configs',f'isa = XCConfigurationList; buildConfigurations = ({oid(kind+"Debug")},{oid(kind+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {oid("targetconfigs")}; buildPhases = ({oid("sources")},{oid("frameworks")},{oid("resources")}); buildRules = (); dependencies = (); name = GalaGo; productName = GalaGo; productReference = {oid("product")}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {oid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {oid("main")}; productRefGroup = {oid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({oid("target")});')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+oid('project')+'; }\n')
schemes=project/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
(schemes/'GalaGo.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid('target')}" BuildableName="GalaGo.app" BlueprintName="GalaGo" ReferencedContainer="container:GalaGo.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid('target')}" BuildableName="GalaGo.app" BlueprintName="GalaGo" ReferencedContainer="container:GalaGo.xcodeproj"/></BuildableProductRunnable></LaunchAction><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(project)
