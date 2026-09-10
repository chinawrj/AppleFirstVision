# Validation record — 2026-09-10

## Environment

- Host: Apple M1 Pro, 32 GB RAM.
- Xcode 26.2 (17C52), iOS Simulator 26.2, iPhone 17 Pro Max simulator.
- Physical device: iPhone 17 Pro Max, iOS 26.6.1, Developer Mode enabled.
- Ultralytics 8.4.146, coremltools 9.0, PyTorch 2.7.0, NumPy 2.3.5, Python 3.11.9. `uv pip check` passes.
- Official YOLO26s/m/x, 640px, FP16, end-to-end `[1,300,6]` outputs; weight SHA-256 in committed manifests.

## Completed simulator checks

Six XCTest cases passed (4 unit/integration + 2 UI), zero failures:

1. Normalized coordinates and confidence filtering.
2. Invalid classes/nonfinite scores/inverted boxes rejected; boxes clipped to image.
3. Unexpected output tensor dimensions rejected.
4. All three actual Core ML models identify bus and people in official fixture.
5. Real local camera stream runs successfully with M → X → S → M model switches.
6. Fixture app startup, inference, pause, and resume.

Evidence: `artifacts/Tests-20260910-181123.xcresult`. Live UI test includes a screenshot attachment; these local camera images are not committed.

Live test log: M at 26 processed frames, X at 41, S at 72. Visual inspection confirmed camera frame and bounding box alignment. M warm inference observed around 117–124 ms on this host; these are simulator CPU measurements, not iPhone/ANE benchmarks or camera FPS.

Fixture cold model load + prediction during final simulator test: S 251 ms, M 377 ms, X 840 ms (each detected 5 objects). These single-run cold measurements include loading and are not a performance ranking.

## Device build and installation

- Generic iOS arm64 build passed.
- Signed iOS app build passed using the existing local Apple Development identity.
- `devicectl` confirmed installation of the app on the attached iPhone.
- Initial device XCTest run was blocked by iOS developer-certificate trust, before tests executed. This is not a model/test assertion failure.
- After the user trusted the certificate, all **6 tests passed on the physical device**, with zero failures and zero skips. The rotation-corrected build also passed all 6 tests.
- Final result bundle: `artifacts/iPhone17ProMax-Rotation-Tests.xcresult`.
- Native rear-camera M → X → S → M live switching passed. Final run observed M at 119 frames, X at 196, S at 297, and M at 379 in the captured screenshot.
- M warm inference samples: 17–22 ms; S sample: 9 ms. X continuous inference passed, but a stable warm-latency number was not captured. These are individual UI samples, not averaged benchmarks or end-to-end FPS.
- All three models detected bus and people on the physical device using the deterministic fixture. First trusted run cold load+prediction: S 990 ms, M 1389 ms, X 2625 ms.
- Visual QA found a sideways image when the phone was held horizontally. Replaced the fixed 90° rotation with `AVCaptureDevice.RotationCoordinator` plus observed horizon-level capture angle. The final native-camera screenshot shows the horizon upright.
- Screenshot: retained locally and excluded from publication. The live outdoor scene had no high-confidence COCO targets; zero detections there is not treated as failure. Actual object detection is additionally asserted on the known fixture.
- Final app relaunched without fixture arguments for normal live camera use.

## Reproducibility and limits

`project.yml`, generated shared Xcode project, locked Python dependencies, export script, run scripts, tests, and CI workflow are committed. Generated model packages, weights, signing profiles, build outputs, and camera screenshots are excluded from Git.

The GitHub Actions workflow is supplied but has not run remotely. Live camera test skips on CI when no localhost bridge is available; deterministic model inference remains required.

Core ML uses `.all` on device, but individual operation placement on the Neural Engine was not profiled.

This implementation performs object detection only (not instance segmentation or pose). Persistent thermal behavior, battery use, camera interruption/recovery under phone calls, and broad device/OS coverage are not yet certified.
