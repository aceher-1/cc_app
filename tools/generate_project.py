"""Regenerate the dependency-free Xcode project and its shared test scheme."""
from pathlib import Path
import hashlib
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
objects = {}


def identity(label):
    return hashlib.sha1(label.encode()).hexdigest()[:24].upper()


def add(label, value):
    key = identity(label)
    objects[key] = value
    return key


def quoted(value):
    return json.dumps(value)


def array(values):
    return "(" + ", ".join(values) + ("," if values else "") + ")"


def reference(path, file_type):
    return add("file:" + path, f"{{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {quoted(path)}; sourceTree = \"<group>\"; }}")


def phase(label, isa, refs):
    build_ids = [add("build:" + label + key, f"{{isa = PBXBuildFile; fileRef = {key}; }}") for key in refs]
    return add(label, f"{{isa = {isa}; buildActionMask = 2147483647; files = {array(build_ids)}; runOnlyForDeploymentPostprocessing = 0; }}")


def group(label, name, children):
    return add(label, f"{{isa = PBXGroup; name = {quoted(name)}; children = {array(children)}; sourceTree = \"<group>\"; }}")


def configurations(label, settings):
    ids = []
    for name in ["Debug", "Release"]:
        values = dict(settings)
        values["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if name == "Debug" else "-O"
        values["DEBUG_INFORMATION_FORMAT"] = "dwarf" if name == "Debug" else "dwarf-with-dsym"
        if name == "Debug":
            values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
            values["ENABLE_TESTABILITY"] = "YES"
        serialized = " ".join(f"{key} = {quoted(value)};" for key, value in values.items())
        ids.append(add(label + name, f"{{isa = XCBuildConfiguration; buildSettings = {{{serialized}}}; name = {name}; }}"))
    return add(label, f"{{isa = XCConfigurationList; buildConfigurations = {array(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}")


def app_icon():
    # Original geometric icon: white plate, fork and spoon on a red/black field.
    size = 1024
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            color = (196, 5, 41) if x + y < 1330 else (20, 20, 23)
            distance = (x - 515) ** 2 + (y - 490) ** 2
            plate = 208 ** 2 < distance < 240 ** 2 or distance < 165 ** 2
            fork = (215 <= x <= 244 and 440 <= y <= 750) or (172 <= x <= 286 and 412 <= y <= 454)
            teeth = 276 <= y <= 420 and any(a <= x <= a + 22 for a in [172, 217, 264])
            spoon = ((x - 802) / 53) ** 2 + ((y - 370) / 90) ** 2 <= 1 or (788 <= x <= 816 and 415 <= y <= 750)
            if plate or fork or teeth or spoon:
                color = (255, 255, 255)
            rows.extend(color)
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    assets = ROOT / "Commons/Assets.xcassets"
    icon = assets / "AppIcon.appiconset"
    icon.mkdir(parents=True, exist_ok=True)
    (assets / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    (icon / "AppIcon.png").write_bytes(png)
    (icon / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


def main():
    app_icon()
    app_files = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "Commons").rglob("*.swift"))
    test_files = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "CommonsTests").glob("*.swift"))
    ui_files = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "CommonsUITests").glob("*.swift"))
    app_refs = [reference(path, "sourcecode.swift") for path in app_files]
    test_refs = [reference(path, "sourcecode.swift") for path in test_files]
    ui_refs = [reference(path, "sourcecode.swift") for path in ui_files]
    assets = reference("Commons/Assets.xcassets", "folder.assetcatalog")
    privacy = reference("Commons/PrivacyInfo.xcprivacy", "text.xml")
    fixture = reference("CommonsTests/Fixtures/menu.json", "text.json")
    app_product = add("product:app", '{isa = PBXFileReference; explicitFileType = wrapper.application; path = Commons.app; sourceTree = BUILT_PRODUCTS_DIR; }')
    test_product = add("product:tests", '{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = CommonsTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }')
    ui_product = add("product:uiTests", '{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = CommonsUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }')
    products = group("products", "Products", [app_product, test_product, ui_product])
    app_group = group("appgroup", "Commons", app_refs + [assets, privacy])
    tests_group = group("testgroup", "CommonsTests", test_refs + [fixture])
    ui_group = group("uiTestGroup", "CommonsUITests", ui_refs)
    root_group = group("rootgroup", "", [app_group, tests_group, ui_group, products])
    app_sources = phase("appSources", "PBXSourcesBuildPhase", app_refs)
    app_resources = phase("appResources", "PBXResourcesBuildPhase", [assets, privacy])
    app_frameworks = phase("appFrameworks", "PBXFrameworksBuildPhase", [])
    test_sources = phase("testSources", "PBXSourcesBuildPhase", test_refs)
    test_resources = phase("testResources", "PBXResourcesBuildPhase", [fixture])
    test_frameworks = phase("testFrameworks", "PBXFrameworksBuildPhase", [])
    ui_sources = phase("uiSources", "PBXSourcesBuildPhase", ui_refs)
    ui_resources = phase("uiResources", "PBXResourcesBuildPhase", [])
    ui_frameworks = phase("uiFrameworks", "PBXFrameworksBuildPhase", [])
    shared = {"SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "TARGETED_DEVICE_FAMILY": "1"}
    project_config = configurations("projectConfig", shared)
    app_config = configurations("appConfig", {**shared, "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.msoecommons", "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_CFBundleDisplayName": "Commons", "INFOPLIST_KEY_UILaunchScreen_Generation": "YES", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES", "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "1.0", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"})
    test_config = configurations("testConfig", {**shared, "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.msoecommons.tests", "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGN_STYLE": "Automatic", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Commons.app/Commons", "BUNDLE_LOADER": "$(TEST_HOST)", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"})
    ui_config = configurations("uiConfig", {**shared, "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.msoecommons.uitests", "GENERATE_INFOPLIST_FILE": "YES", "CODE_SIGN_STYLE": "Automatic", "TEST_TARGET_NAME": "Commons", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"})
    project_id = identity("project")
    app_id = identity("appTarget")
    proxy = add("testProxy", f"{{isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {app_id}; remoteInfo = Commons; }}")
    dependency = add("testDependency", f"{{isa = PBXTargetDependency; target = {app_id}; targetProxy = {proxy}; }}")
    add("appTarget", f"{{isa = PBXNativeTarget; name = Commons; productName = Commons; productReference = {app_product}; productType = \"com.apple.product-type.application\"; buildConfigurationList = {app_config}; buildPhases = {array([app_sources, app_frameworks, app_resources])}; buildRules = (); dependencies = (); }}")
    tests_id = add("testTarget", f"{{isa = PBXNativeTarget; name = CommonsTests; productName = CommonsTests; productReference = {test_product}; productType = \"com.apple.product-type.bundle.unit-test\"; buildConfigurationList = {test_config}; buildPhases = {array([test_sources, test_frameworks, test_resources])}; buildRules = (); dependencies = {array([dependency])}; }}")
    ui_id = add("uiTarget", f"{{isa = PBXNativeTarget; name = CommonsUITests; productName = CommonsUITests; productReference = {ui_product}; productType = \"com.apple.product-type.bundle.ui-testing\"; buildConfigurationList = {ui_config}; buildPhases = {array([ui_sources, ui_frameworks, ui_resources])}; buildRules = (); dependencies = {array([dependency])}; }}")
    add("project", f"{{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{{app_id} = {{CreatedOnToolsVersion = 16.0; }}; {tests_id} = {{CreatedOnToolsVersion = 16.0; TestTargetID = {app_id}; }}; {ui_id} = {{CreatedOnToolsVersion = 16.0; TestTargetID = {app_id}; }}; }}; }}; buildConfigurationList = {project_config}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {root_group}; productRefGroup = {products}; projectDirPath = \"\"; projectRoot = \"\"; targets = {array([app_id, tests_id, ui_id])}; }}")
    project = ROOT / "Commons.xcodeproj"
    project.mkdir(exist_ok=True)
    lines = ["// !$*UTF8*$!", "{", "archiveVersion = 1;", "classes = {};", "objectVersion = 56;", "objects = {"]
    lines += [f"{key} = {value};" for key, value in sorted(objects.items())]
    lines += ["};", f"rootObject = {project_id};", "}"]
    (project / "project.pbxproj").write_text("\n".join(lines) + "\n", encoding="utf-8")
    schemes = project / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    app_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_id}" BuildableName="Commons.app" BlueprintName="Commons" ReferencedContainer="container:Commons.xcodeproj"/>'
    tests_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{tests_id}" BuildableName="CommonsTests.xctest" BlueprintName="CommonsTests" ReferencedContainer="container:Commons.xcodeproj"/>'
    ui_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_id}" BuildableName="CommonsUITests.xctest" BlueprintName="CommonsUITests" ReferencedContainer="container:Commons.xcodeproj"/>'
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
    <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{tests_ref}</BuildActionEntry>
    <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{ui_ref}</BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{tests_ref}</TestableReference><TestableReference skipped="NO">{ui_ref}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugServiceExtension="internal"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (schemes / "Commons.xcscheme").write_text(scheme, encoding="utf-8")
    print(f"Generated Commons.xcodeproj with {len(app_refs)} app files and {len(test_refs)} test files.")


if __name__ == "__main__":
    main()
