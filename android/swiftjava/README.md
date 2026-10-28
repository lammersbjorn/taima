# Generated JNI probe

The free function in `Normalize.swift` calls the same TaimaBridge operation as
handwritten JNI. The generator configuration selects JNI mode and the generated
Java package. Upstream source and runtime are pinned in `Package.resolved`.

```sh
~/.t3/tools/saiko-load-gate/load-gate.sh && PATH="$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin:$PATH" JAVA_HOME=/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home swift build --package-path android/swiftjava -c release --build-system native --product TaimaGenerated --swift-sdk aarch64-unknown-linux-android28 --scratch-path /tmp/taima-trial-generated -j 2
```

Prepending the standalone toolchain avoids helper discovery of Apple's
`/usr/bin/swift`; setting `DEVELOPER_DIR` alone was insufficient. Release builds
compile host SwiftSyntax macro dependencies too. The interrupted checkpoint is
not a successful build or a cold-time observation.

After the handwritten package step, run `scripts/android/package-generated.sh`
to copy and strip `libTaimaGenerated.so` and `libSwiftJava.so`. Then build with
`-PwithSwift=true -PwithGenerated=true` behind the gate. The runtime loader Java
files are unmodified upstream code; the generated Java wrapper omits only unused
wildcard imports. Licence: `runtime/LICENSE.txt`.
