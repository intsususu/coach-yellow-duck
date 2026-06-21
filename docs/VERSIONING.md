# 版本号管理规范

两个版本号，职责不同：

- **version**（`MARKETING_VERSION` / CFBundleShortVersionString）：对外语义化版本 `MAJOR.MINOR.PATCH`，起始 `1.0.0`。
- **version code**（`CURRENT_PROJECT_VERSION` / CFBundleVersion，即构建号）：纯数字、单调自增、上架不可重复。等价于 Android 的 versionCode。起始 `1`。

| 位 | 含义 | 何时变 | 怎么变 |
|----|------|--------|--------|
| `MAJOR`（`1`） | 大版本 | 你主动决定大改版时 | `./scripts/bump-major.sh` |
| `MINOR`（第一位小数） | 独立功能加入 | create PR 时询问是否升级，确认后升 | `./scripts/bump-minor.sh` |
| `PATCH`（第二位小数） | 每次提交计数 | 每次 `git commit` | 自动（`.githooks/pre-commit`） |
| **version code** | 构建号 | 每次 `git commit` / 每次 bump | 自动 +1（hook 与 bump 脚本都会 +1） |

> version code 在每次 commit 与每次 bump 时都 +1，保证全局严格递增、永不重复。

## 一次性启用（新克隆后需执行一次）

```sh
git config core.hooksPath .githooks
```

hook 脚本已随仓库提交，但 `core.hooksPath` 是本地 git 配置，换机器/重新 clone 后需再执行一次。

## 流程

- **日常**：正常 `git commit`，pre-commit 自动把 PATCH +1 并把 pbxproj 一并纳入本次提交。
- **加了独立功能、要开 PR**：先问要不要升小版本；要就 `./scripts/bump-minor.sh`（MINOR+1、PATCH 归零，用 `--no-verify` 提交避免 PATCH 又自增），再开 PR。
- **大改版**：`./scripts/bump-major.sh`（MAJOR+1、其余归零）。

## 注意事项

- **合并冲突**：因为每次 commit 都改 pbxproj 的 `MARKETING_VERSION` 行，feature 分支合回 main 时这一行常冲突。解决时取「较大」的 PATCH 即可，不影响逻辑。
- **version code 已自动维护**：hook 与 bump 脚本都会把 `CURRENT_PROJECT_VERSION` +1，上架 App Store / TestFlight 时无需再手动改。冲突解决时同样取较大值即可。
