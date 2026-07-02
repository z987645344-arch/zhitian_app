# zhitian_app CHANGELOG

## 2026-07-02
- 完成客户端简约风格美化，不新增依赖，仅调整现有页面和组件样式。
- 统一主色为#1A73E8，页面背景白色或浅灰，气泡圆角、输入框、按钮和字体尺寸按规范收敛。
- MessageBubble改为用户蓝色气泡、assistant浅灰气泡，移除多余视觉信息。
- ChatComposer改为白色底栏、顶部1px分隔线、浅灰输入框和圆形蓝色发送按钮。
- ThinkingBubble改为assistant同款浅灰气泡，跳动点使用主蓝色。
- ChatPage、LoginPage、SettingsPage、HistoryPage完成简约化样式调整。
- 验证flutter analyze通过。

## 2026-07-01
- 拆分ChatPage内部组件，新增lib/widgets/chat_composer.dart、message_bubble.dart、streaming_cursor.dart、thinking_bubble.dart。
- chat_page.dart保留页面编排逻辑，降低单文件复杂度。
- 删除临时证明文件kskblzdjd.md。
- 验证dart format、flutter analyze、flutter test均通过。
- 新增lib/pages/login_page.dart，支持用户名/密码登录POST /auth/login，成功后保存auth_token和user_role。
- main.dart启动时读取SharedPreferences中的auth_token，有token进入ChatPage，无token进入LoginPage。
- ApiService统一为chatStream、getHistory、clearHistory、checkHealth请求添加Authorization: Bearer token。
- SettingsPage新增退出登录按钮，清除auth_token和user_role后回到登录页。
- 验证dart format、flutter analyze、flutter test均通过。

## 2026-06-30
- Step 3完成：接入真实SSE后端，ApiService.chatStream改为POST /chat/stream并解析data: JSON事件。
- 后端地址从SharedPreferences读取，key为backend_url，默认值为http://localhost:8000。
- SettingsPage改为真实设置页，支持编辑/保存后端地址，并通过GET /health测试连接状态ok/degraded/error。
- 为项目补充Windows桌面平台目录：flutter create --platforms=windows .。
- 验证flutter pub get、dart format、flutter analyze、flutter test均通过。
- 启动本地知天后端后，使用Flutter测试环境验证“你好”收到真实GLM回复，“今天北京天气”收到真实搜索链路回复，/health返回ok。
- 当前本机flutter run -d windows被Visual Studio toolchain配置阻塞：Unable to find suitable Visual Studio toolchain。
- 删除android目录，项目目标平台统一为Windows桌面端。
- 清理pubspec.yaml中Android/iOS模板版本说明注释，保留Windows桌面端配置。
- 验证flutter pub get通过，flutter analyze无报错。
- 完成流式逐字显示和加载动画优化。
- ChatProvider新增isThinking状态：发送后立即进入思考中，收到首个chunk后关闭，流式结束后确认关闭。
- ChatPage新增assistant样式的“思考中”气泡和三个点跳动动画，避免搜索链路长时间空白等待。
- assistant流式输出保留闪烁光标，周期调整为0.6秒，输出完成后自动消失。
- 验证flutter analyze和flutter test通过，临时SSE测试确认真实后端会逐chunk yield。
- 完成新建对话按钮和错误提示。
- ChatProvider新增newChat()，清空消息、重置发送/思考状态，并重新生成sessionId。
- ChatPage标题栏左侧新增Icons.add_comment新建对话按钮，点击后立即回到空会话。
- ApiService按错误类型返回提示：SocketException为后端未启动，TimeoutException为请求超时，其他异常显示简述。
- 验证flutter analyze和flutter test通过；测试覆盖新建对话换session、错误消息显示、isThinking/isSending错误后复位。
- 使用无服务端口验证后端不可达时显示“⚠️ 无法连接到后端，请检查服务是否启动”。
- 完成历史记录页。
- 新增lib/pages/history_page.dart，支持读取当前session历史、角色图标/内容/时间戳展示、下拉刷新。
- ApiService新增getHistory(sessionId)和clearHistory(sessionId)，分别调用GET/DELETE /memory/{session_id}。
- ChatPage右上角新增Icons.history历史记录入口。
- 历史页清空成功后同步调用provider.newChat()，返回聊天页即为新会话。
- 验证flutter analyze和flutter test通过；真实后端/memory接口读取和清空验证通过。
