# 发布 HiFrame / Releasing HiFrame

## 中文

PR 和 main 分支推送只运行测试及打包检查，**不会发布版本**。合并程序改动后，从最新 main 创建版本标签并推送：

```sh
git switch main
git pull --ff-only origin main
git tag v0.5.1
git push origin v0.5.1
```

标签必须是递增的 `v主版本.次版本.修订号`，并指向已经进入 main 的提交。Actions 会将标签版本写入构建产物，运行测试、构建 Apple Silicon 安装包、验证签名及 ZIP 校验，然后创建草稿 Release、上传并重新下载附件校验，最后发布并设为 Latest。整个过程不需要手动上传附件或再点击发布。

README 的固定下载地址为 `releases/latest/download/HiFrame.zip`，更新检查也使用同一个 Latest 发布入口。安装包保留 `com.local.SteadyFrame` 应用标识；签名仍为临时签名，此流程不执行 Apple 公证。

若发布失败，先查看 Actions 日志。已公开的 Release 不会被覆盖；上传或校验失败时保留草稿，可以修正网络问题后重新运行，或在 Actions 的 **Release HiFrame → Run workflow** 中输入同一个已存在的标签。需要修改代码时应合并修复并推送新的版本标签，不移动旧标签。

本地验证：`bash scripts/ci-package.sh`。验证指定版本的打包结果：`HIFRAME_RELEASE_VERSION=0.5.1 bash scripts/ci-package.sh`。CI 不具备真实 ProMotion 面板，因此不把云端测试当作物理刷新率或实际登录自启动的证明。

## English

Pull requests and pushes to main run tests and packaging checks only; **they do not publish a release**. After merging application changes, create and push a version tag from the latest main using the commands above.

Tags must be increasing `vMAJOR.MINOR.PATCH` versions and point to commits already merged into main. Actions stamps the tag version into the built app, runs tests, builds the Apple Silicon package, verifies its signature and ZIP checksum, creates a draft release, uploads and downloads its assets for verification, then publishes it as Latest. No manual asset upload or additional publish click is needed.

The README uses the fixed `releases/latest/download/HiFrame.zip` URL, and update checks use the same Latest release. The app retains `com.local.SteadyFrame` as its identifier. Packages remain ad-hoc signed; this workflow does not perform Apple notarization.

For failures, inspect the Actions logs. Published releases are never overwritten. Upload or verification failures leave a draft that can be retried after resolving network problems, either by rerunning the job or entering the same existing tag under **Release HiFrame → Run workflow**. Code fixes should be merged and released under a new version tag; do not move old tags.

Local validation: `bash scripts/ci-package.sh`. To validate a specific package version: `HIFRAME_RELEASE_VERSION=0.5.1 bash scripts/ci-package.sh`. Cloud runners do not provide a real ProMotion panel; CI is not evidence of physical refresh rate or actual launch at login.
