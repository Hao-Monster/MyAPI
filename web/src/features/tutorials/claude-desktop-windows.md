# 在 Windows 版 Claude Desktop 中使用 Ant-Claude

配置完成后，在 Claude 桌面客户端里选择 Opus 5.5 或 Fable 5.2 即可对话。使用量计入自己的 Ant-Claude 账户。

## 1. 获取个人 API 密钥

登录 Ant-Claude，进入「API 密钥」，点击「创建 API 密钥」。名称可填 `Claude Desktop Windows`。为这台设备单独设置额度和到期时间，在「高级设置 → 模型限制」勾选下表中的两个模型。保存后复制密钥，留待下一步使用。[打开 API 密钥页](https://holliday.win/keys)

| 桌面端模型 | 在网关中填写的完整模型 ID |
| --- | --- |
| Claude Opus 5.5 | `anthropic/claude-opus-5.5` |
| Claude Fable 5.2 | `anthropic/claude-fable-5.2` |

令牌额度是这台设备最多可以使用的金额。账户本身也需要有可用余额。每位使用者应从自己的 Ant-Claude 账户创建令牌，站长的 OpenRouter 上游密钥只保存在服务器上。

## 2. 配置桌面客户端

1. 打开 Claude Desktop。若菜单栏隐藏，按一次 **Alt**。在 **Help → Troubleshooting → Enable Developer Mode** 开启开发者模式。
2. 打开 **Developer → Configure Third-Party Inference**。在连接设置中按下表填写。
3. 在 **Models** 中添加上表的两个完整模型 ID，各占一项。将常用模型放在第一项。界面如提供自动发现开关，可关闭并使用这份固定列表。
4. 应用本地配置并按提示完整退出、重新启动 Claude。若启动时出现模式选择，选择使用已配置的推理服务。

| 连接设置 | 填写内容 |
| --- | --- |
| Inference provider | `Gateway` |
| Gateway base URL | `https://holliday.win` |
| Credential kind | `Static API key` |
| Gateway API key | 第 1 步创建的个人 API 密钥 |
| Gateway auth scheme | `Bearer` |

客户端会自动在域名后拼接 `/v1/messages`，所以地址填到 `.win` 即可。模型名称中的 `anthropic/` 前缀要保留。[Claude Desktop 官方网关配置](https://claude.com/docs/third-party/claude-desktop/gateway)

若欢迎页显示 **custom inference gateway**，点击 **Continue** 即可进入网关模式。进入后，左下角可看到 **Gateway**。已通过 Windows 用户策略配置的电脑会直接显示这些设置，桌面端的配置窗口可能只读；在这种情况下，更新令牌需同步更新当前用户策略中的 `inferenceGatewayApiKey`。[Windows 配置来源与优先级](https://claude.com/docs/third-party/claude-desktop/mdm)

## 3. 确认对话确实经过 Ant-Claude

新建一段对话，选择 **Opus 5.5**，发送「只回复 OK」。看到回复后，打开站内使用日志，按时间和令牌名称找到刚才的请求，核对模型 ID。也可以切换到 **Fable 5.2** 再验证一次。测试按实际用量计费。[查看使用日志](https://holliday.win/usage-logs)

如果首页提示 **Reinstall the desktop app to access Cowork**，可从左侧切换到 **Code → New → Select folder**，选择专门的空文件夹，再发送测试消息。要使用 Cowork，可从官方页面重新安装支持该功能的版本。[Claude Desktop 官方下载](https://claude.com/download)

| 遇到的情况 | 检查位置 |
| --- | --- |
| 提示密钥无效或 401 | 在站内检查个人令牌是否启用、是否到期，重新复制完整密钥到客户端。 |
| 提示额度不足 | 分别查看账户余额和令牌剩余额度，两项都必须够用。 |
| 提示模型不可用 | 核对客户端中的完整模型 ID，以及令牌「模型限制」中勾选的模型。 |
| 客户端有回复，站内没有对应记录 | 核对启动时选择的部署模式、网关域名和当前登录的 Ant-Claude 账户。 |

停用这台设备时，在站内禁用它的专用令牌即可。更换令牌时，也要在客户端的网关设置中更新密钥并重新启动。

## 4. 在 Claude Desktop 的 Code 页选择 Gemini 4 Carbon

Windows 版 Claude Desktop 2.19675.1 可以通过 CC Switch 4.0.4 把 **Gemini 4 Carbon** 加入模型菜单。直接把 `google/gemini-4-carbon` 填进 Claude Desktop 的模型列表时，本机菜单仍只显示 Opus 和 Fable。使用 CC Switch 时，桌面端识别 Sonnet 角色，由本地路由将请求映射到 Carbon。[CC Switch 桌面端配置说明](https://github.com/farion1231/cc-switch/blob/v4.0.4/docs/user-manual/en/2-providers/2.6-claude-desktop.md)

1. 打开 Ant-Claude 的「API 密钥」，编辑自己的桌面端令牌，在「高级设置 → 模型限制」中勾选 `google/gemini-4-carbon` 并保存。[打开 API 密钥页](https://holliday.win/keys)
2. 在 CC Switch 左侧选择 **Claude Desktop**，点击 **+** 添加自定义服务商，按下表填写。

| CC Switch 设置 | 填写内容 |
| --- | --- |
| 接口格式 | OpenAI Chat Completions |
| 上游地址 | `https://holliday.win/v1` |
| API 密钥 | 已获准调用 Carbon 的 Ant-Claude 个人令牌 |
| 需要模型映射 | 开启 |
| 桌面角色 | Sonnet |
| 菜单显示名 | Gemini 4 Carbon |
| 请求模型 | `google/gemini-4-carbon` |

3. 保存前检查其他角色的请求模型。CC Switch 可能用同一模型补全空白角色。若希望保留 Opus 或 Fable，分别填入第 1 节的完整模型 ID，并确认令牌有对应权限。
4. 启用服务商，开启 **Claude Desktop 本地路由**。如果显示未运行，点击「重试」。保持 CC Switch 运行，完全退出并重开 Claude Desktop。
5. 在 **Code → New** 选择专用空文件夹。在模型菜单选 **Gemini 4 Carbon**，发送「只回复 OK」。打开站内使用日志，按发送时间和令牌名称核对模型 ID `google/gemini-4-carbon`。[查看使用日志](https://holliday.win/usage-logs)

**本次实测**　在专用空文件夹中选择 Gemini 4 Carbon，发送「只回复 OK，不使用任何工具。」后，桌面端回复了 `OK`。站内同一令牌在这次对话中产生两笔 `google/gemini-4-carbon` 记录：主请求为流式，输入 51,650、输出 5 个 Token，费用 $0.103350；另一笔费用 $0.002078，合计 **$0.105428**。Code 页会随短消息发送额外上下文，每次费用取决于实际用量。

**重启后仍只看到 Opus 和 Fable？** 本机的 Windows 管理策略优先于 CC Switch 写入的桌面配置。使用受管电脑时，请让管理员先留存原网关配置，再将生效策略中的网关地址、网关凭据和模型列表与 CC Switch 生成的桌面配置对齐。默认本地地址是 `http://127.0.0.1:15721/claude-desktop`。桌面端使用 CC Switch 生成的本地凭据，站内个人令牌填在 CC Switch 的上游服务商中。恢复直连时还原这三项并重启桌面端。[Windows 配置来源与优先级](https://claude.com/docs/third-party/claude-desktop/mdm)

如果使用普通 OpenAI 兼容客户端，可直接填写上表的上游地址、个人令牌和请求模型。

## 5. 保留 Claude 原模型，同时在菜单中使用 Gemini

CC Switch 4.0.4 的 Claude Desktop 模型映射有四个位置，每个位置只对应一个实际请求模型。如果把 Sonnet 映射到 Carbon，当前菜单就少了 Claude Sonnet；把 Haiku 映射到 Argon，同样会少了 Claude Haiku。要随时能用到本站六款模型，可以保存两份服务商配置，每次启用一份。[CC Switch 4.0.4 角色配置](https://github.com/farion1231/cc-switch/blob/v4.0.4/src/components/providers/forms/ClaudeDesktopProviderForm.tsx#L193-L215)

1. 在 Ant-Claude 编辑桌面端个人令牌。如果两份配置共用一枚令牌，在「高级设置 → 模型限制」中勾选下表涉及的六个模型并保存。[打开 API 密钥页](https://holliday.win/keys)
2. 在 CC Switch 的 **Claude Desktop** 面板分别添加「Ant-Claude · 全部 Claude」和「Ant-Claude · Claude 与 Gemini」。两份都按第 4 节填写接口格式、上游地址和个人令牌，开启「需要模型映射」。在每个角色里，把模型名填入「菜单显示名」，把对应的完整 ID 填入「请求模型」。

| CC Switch 角色 | 全部 Claude（显示名和请求模型） | Claude 与 Gemini（显示名和请求模型） |
| --- | --- | --- |
| Sonnet | Claude Sonnet 5.5 · `anthropic/claude-sonnet-5.5` | Claude Sonnet 5.5 · `anthropic/claude-sonnet-5.5` |
| Opus | Claude Opus 5.5 · `anthropic/claude-opus-5.5` | Gemini 4 Carbon · `google/gemini-4-carbon` |
| Fable | Claude Fable 5.2 · `anthropic/claude-fable-5.2` | Gemini 4 Argon · `google/gemini-4-argon` |
| Haiku | Claude Haiku 5.5 · `anthropic/claude-haiku-5.5` | Claude Haiku 5.5 · `anthropic/claude-haiku-5.5` |

3. 日常使用 Sonnet、Haiku、Carbon 和 Argon 时，启用「Claude 与 Gemini」。需要 Opus 或 Fable 时，切换到「全部 Claude」。每次切换后，保持 CC Switch 本地路由运行，完全退出并重开 Claude Desktop，再到 **Code → New** 查看模型菜单。若电脑使用 Windows 管理策略，按第 4 节同步当前配置的网关凭据和模型列表。
4. 第 4 节实测的是 Sonnet 角色调用 Carbon。上表是保留原版 Sonnet 和 Haiku 的配置示例。要核对某个菜单项，选中它发送一条短消息，再按发送时间和令牌名称核对日志中的实际模型 ID。测试按用量计费。[查看使用日志](https://holliday.win/usage-logs)
