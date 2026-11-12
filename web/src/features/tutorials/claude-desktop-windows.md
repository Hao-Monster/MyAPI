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

## 4. Windows 客户端能选 Gemini 4 Carbon 吗？

在 Windows 版 Claude Desktop **2.19675.1** 的 Gateway 模式下，Code 页无法直接选择 `google/gemini-4-carbon`。实测把这个完整 ID 加到 `inferenceModels`，保留 Opus 和 Fable，然后完全退出并重新启动客户端。展开新会话输入框右下角的模型菜单后，仍然只有 Opus 和 Fable。测试停在选择模型这一步，没有发出 Carbon 对话请求。

如果你遇到同样的情况，先看模型菜单。模型没有出现时，扩大令牌权限不能让它出现在菜单里。如果模型可以选，但发送消息后提示无权调用，再到「API 密钥 → 编辑 → 高级设置 → 模型限制」核对该令牌允许的模型。

要在 Ant-Claude 使用 Carbon，可在支持 OpenAI 兼容接口的客户端中选择自定义服务商，Base URL 填 `https://holliday.win/v1`，模型 ID 填 `google/gemini-4-carbon`，并使用已放行 Carbon 的个人 API 密钥。发送一条短消息后，在[使用日志](https://holliday.win/usage-logs)核对模型名。这套填写方式用于 OpenAI 兼容客户端；Claude Desktop 的 Gateway 地址仍按第 2 节填写。

升级 Claude Desktop 后，可以用同一方法复测。只有在客户端能选中 Carbon、收到回复，且站内同一请求的日志显示 `google/gemini-4-carbon` 时，才算验证了该版本的桌面接入。
