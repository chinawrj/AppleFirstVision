# Apple First Vision

原生 SwiftUI + Vision + Core ML 的 YOLO26 实时目标检测项目。支持 **YOLO26s / YOLO26m / YOLO26x** FP16、640×640、COCO 80 类；默认 m，最大检测版本 x 可在界面切换。

## 启动

本机已安装 Xcode 26.2、iOS 26.2 模拟器、XcodeGen，模型已导出在 `AppleFirstVision/Models/`。

```bash
scripts/start_bridge.sh
scripts/run_simulator.sh
```

首次打开桥接应用需允许摄像头。保持桥接窗口运行，模拟器即接收 Mac 摄像头实时画面。界面显示检测框、类别、置信度、推理耗时和已处理帧数；支持置信度调整、模型切换和暂停恢复。

其他模拟器可通过 `SIMULATOR_ID=<UDID> scripts/run_simulator.sh` 指定。模型首次加载会比后续推理慢。

## 从干净检出重建

```bash
brew install xcodegen
uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python -r scripts/requirements-lock.txt
.venv/bin/python scripts/export_models.py
scripts/start_bridge.sh
scripts/run_simulator.sh
```

权重和 Core ML 包是生成产物，不提交到 Git。导出脚本下载官方固定发布版、核验记录的 SHA-256；依赖版本锁定。需要重新转换时使用 `--force`。Xcode 工程由 `project.yml` 生成。

## 摄像头和推理链路

- **模拟器**：macOS AVFoundation → 内存 JPEG → 仅 `127.0.0.1:8765/frame` → iOS Vision / Core ML CPU 推理。桥接只提供图像，不执行检测，不保存或上传摄像头画面。超过 3 秒无新帧返回 503。
- **iPhone**：后置广角 AVFoundation → Vision / Core ML `.all`，由系统调度 CPU、GPU、Neural Engine。不需要桥接程序或网络。
- 推理在串行后台队列运行，繁忙时丢弃输入帧，避免任务积压。绘制的画面和检测结果来自同一帧；后台暂停，前台恢复。
- YOLO26 end-to-end 输出为 `[1,300,6]`，每行为像素 `x1,y1,x2,y2,score,class`。Vision `.scaleFill` 拉伸输入到 640²，结果按原图比例映射，使用 aspect-fit 显示。该预处理选择简化了坐标一致性，但与训练常用 letterbox 不同，极端宽高比可能影响精度。

## iPhone 17 Pro Max

最低 iOS 18，已按 arm64 iPhone 目标设计，支持 iPhone 17 Pro Max / iOS 26。界面采用竖屏布局，后置广角捕获通过 Apple RotationCoordinator 根据重力自动校正方向，不依赖特定镜头数量。

打开 `AppleFirstVision.xcodeproj`，在 Signing & Capabilities 选择自己的 Team，连接并解锁 iPhone、启用 Developer Mode，选中设备运行。允许摄像头后直接开始检测。个人开发证书首次安装可能需要在「设置 → 通用 → VPN 与设备管理」信任开发者。

也可使用 `DEVICE_ID=<iPhone UDID> DEVELOPMENT_TEAM=<Team ID> scripts/run_device.sh` 自动构建、安装并启动。

已在接入的 iPhone 17 Pro Max（iOS 26.6.1）上完成安装、三档模型推理、实时摄像头切档和暂停恢复测试。详细结果见 `docs/VALIDATION.md`。持续发热和耗电仍需长时间真机测量。X 精度优先，持续实时使用可按实际耗时选择 M 或 S。

## 自动化验证

```bash
scripts/test.sh
# 其他机型：SIMULATOR_NAME='iPhone 17' scripts/test.sh
xcodebuild -project AppleFirstVision.xcodeproj -scheme AppleFirstVision \
  -destination 'generic/platform=iOS' -derivedDataPath build/DeviceData \
  build CODE_SIGNING_ALLOWED=NO
```

测试包括输出契约检查、坐标映射、非法数值与类别过滤、边界裁剪、三档真实模型识别公交车／行人、UI 启动与暂停恢复。确定性 UI 测试使用明确标注的 `--fixture` 输入；另一个 UI 用例使用真实摄像头，模拟器无桥接时跳过，真机使用本机摄像头。`artifacts/*.xcresult` 包含完整测试结果。

GitHub Actions 已配置，在推送和拉取请求时运行。模型导出需要 macOS 和网络，CI 模拟器按 runner 实际可用机型选择。

## 来源

- [Ultralytics YOLO26](https://docs.ultralytics.com/models/yolo26/)
- [Core ML 导出](https://docs.ultralytics.com/integrations/coreml/)
- [官方权重 v8.4.0](https://github.com/ultralytics/assets/releases/tag/v8.4.0)
- [Apple 摄像头示例与模拟器限制](https://developer.apple.com/documentation/uikit/customizing-an-image-picker-controller)

第三方模型与测试图片的来源及许可见 `THIRD_PARTY_NOTICES.md`。

## 公开版本与隐私

提交身份使用 GitHub noreply 邮箱。启动脚本自动选择可用模拟器，也可通过环境变量指定设备。示例 Bundle ID 使用 `com.example`；真机开发时可改成自己的唯一标识，并选择自己的签名 Team。此前安装到手机的开发版本不受仓库公开影响。

摄像头画面、测试截图、签名材料和本机诊断文件只保存在本地，不应提交或上传。公开 CI 使用 GitHub 托管 runner 与标准测试图片。
