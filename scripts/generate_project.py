from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects={}
def add(key,body):objects[uid(key)]=body;return uid(key)
app=uid('app');test=uid('test');project=uid('project')
appfiles=sorted((root/'Livecript').rglob('*.swift'));testfiles=sorted((root/'LivecriptTests').rglob('*.swift'))
def refs(files,target):
 result=[]; builds=[]
 for f in files:
  path=str(f.relative_to(root));r=add(path,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT;');result.append(r)
  builds.append(add('build'+path,f'isa = PBXBuildFile; fileRef = {r};'))
 add(target+'sources','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(builds)+'); runOnlyForDeploymentPostprocessing = 0;')
 return result
children=refs(appfiles,'app')+refs(testfiles,'test')
prod=add('appProduct','isa = PBXFileReference; explicitFileType = wrapper.application; path = Livecript.app; sourceTree = BUILT_PRODUCTS_DIR;')
tprod=add('testProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = LivecriptTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
asset=add('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Livecript/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
children.append(asset)
assetbuild=add('assetbuild',f'isa = PBXBuildFile; fileRef = {asset};')
add('appresources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assetbuild}); runOnlyForDeploymentPostprocessing = 0;')
group=add('group','isa = PBXGroup; children = ('+','.join(children+[prod,tprod])+'); sourceTree = "<group>";')
for kind in ['project','app','test']:
 configs=[]
 for mode in ['Debug','Release']:
  settings={'IPHONEOS_DEPLOYMENT_TARGET':'26.0','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'complete','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO','SWIFT_OPTIMIZATION_LEVEL':'"-Onone"' if mode=='Debug' else '"-O"','DEBUG_INFORMATION_FORMAT':'dwarf','GCC_PREPROCESSOR_DEFINITIONS':'"$(inherited)"'}
  if kind!='project':settings.update({'PRODUCT_NAME':'"$(TARGET_NAME)"','PRODUCT_BUNDLE_IDENTIFIER':'com.leboxis.livecript'+('.tests' if kind=='test' else ''),'TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0.0'})
  if kind=='app':settings.update({'INFOPLIST_FILE':'Livecript/Resources/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'})
  if kind=='test':settings.update({'TEST_HOST':'"$(BUILT_PRODUCTS_DIR)/Livecript.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Livecript"','BUNDLE_LOADER':'"$(TEST_HOST)"'})
  configs.append(add(kind+mode,'isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {'+' '.join(k+' = '+v+';' for k,v in settings.items())+'};'))
 add(kind+'configs','isa = XCConfigurationList; buildConfigurations = ('+','.join(configs)+'); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
proxy=add('proxy',f'isa = PBXContainerItemProxy; containerPortal = {project}; proxyType = 1; remoteGlobalIDString = {app}; remoteInfo = Livecript;')
dep=add('dep',f'isa = PBXTargetDependency; target = {app}; targetProxy = {proxy};')
for kind,name,product,typ in [('app','Livecript',prod,'application'),('test','LivecriptTests',tprod,'bundle.unit-test')]:
 phases=[uid(kind+'sources')]+([uid('appresources')] if kind=='app' else [])
 add(kind,f'isa = PBXNativeTarget; buildConfigurationList = {uid(kind+"configs")}; buildPhases = ('+','.join(phases)+f'); buildRules = (); dependencies = ({dep if kind=="test" else ""}); name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.{typ}";')
add('project',f'isa = PBXProject; attributes = {{LastUpgradeCheck = 2600;}}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = fr; knownRegions = (fr,en,Base); mainGroup = {group}; projectDirPath = ""; projectRoot = ""; targets = ({app},{test});')
p=root/'Livecript.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = {'+v+'};' for k,v in objects.items())+'\n}; rootObject = '+project+';}\n')
s=p/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
def ref(i,n,b):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{i}" BuildableName="{b}" BlueprintName="{n}" ReferencedContainer="container:Livecript.xcodeproj"/>'
(s/'Livecript.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(app,'Livecript','Livecript.app')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(test,'LivecriptTests','LivecriptTests.xctest')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(app,'Livecript','Livecript.app')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
