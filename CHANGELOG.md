# zhitian_app CHANGELOG

## 2026-07-29 参考图驱动的舒缓办公视觉系统
- 全局颜色令牌与管理后台统一：暖灰白背景、蓝灰主色、鼠尾草绿成功态、柔和琥珀提醒态和砖红错误态；卡片、输入框、按钮、分段控件、标签与弹窗统一采用8-9px圆角和轻量边框层级。
- 认证页左侧由纯黑安全说明栏改为低饱和蓝灰信息区，白色表单卡片增加克制阴影；聊天侧栏当前项改为浅色底、主色色条和主色文字，品牌副标题统一为“企业知识助手”，主导航文案统一为“知识问答”。
- 消息气泡、引用区与输入器同步使用新的圆角、边框与轻阴影；保留快速/专家模式、附件、文件、历史、工具箱和设置全部现有交互及后端请求契约。导航组件测试同步按新中文文案定位。
- 验证：`dart format`完成，`flutter analyze`无问题，完整`flutter test`为`37 tests passed`。

## 2026-07-28 全中文黑白灰桌面工作台重构
- 全局设计令牌改为纯黑、白与中性灰，收紧圆角、阴影和装饰色；认证页改为黑色安全说明栏与白色表单区，登录、注册及密码提示继续使用中文。
- 对话工作区移除右侧能力堆叠栏，模式选择收回顶部，常用入口统一放在左侧导航；消息、输入框、引用、空态、文件预览与设置页同步使用简约黑白灰样式。
- 增加“核对引用与关键事实”“仅连接可信企业服务地址”等安全提示；错误、成功与处理中状态同时使用图标、文字和边框表达，不依赖颜色辨识。
- 修复高 DPI 紧凑导航下账号头像 1 像素溢出；`flutter analyze` 无告警，完整 `flutter test` 37 项全部通过。

## 2026-07-19 工作区内导航与最近会话快捷管理
- 对话、历史记录、我的文件、工具箱和设置改为保留同一侧栏框架，仅替换中心工作区内容，不再为栏目切换创建新路由页面。
- 最近会话名称支持双击重命名；消息数悬停时切换为删除图标，删除前提供确定/取消确认，当前会话删除后自动进入新会话。

## 2026-07-12
- 聊天页AppBar新增“快速/专家”分段切换控件，默认快速；模式由ChatProvider在应用运行期间保持，新建会话不重置，应用重启后恢复快速。
- ChatStreamingService和ApiService.chatStream新增mode参数，请求体按选择发送`fast`或`expert`，移除原有硬编码`mode: chat`；登录、历史记录和citations流程保持不变。
- ApiService支持注入HTTP client factory用于请求序列化测试，生产环境仍默认创建标准http.Client。
- 验证通过：dart format完成，flutter analyze无问题，flutter test共8项全部通过；测试覆盖UI默认fast、切换expert、会话内保持，以及真实JSON请求体的fast/expert字段。
- 本地真实后端SSE验证：fast与expert均返回HTTP 200及`[DONE]`，耗时分别约11.98秒和7.34秒；临时测试用户和会话已清理。

## 2026-07-02
- 完成客户端简约风格美化，不新增依赖，仅调整现有页面和组件样式。
- 统一主色为#1A73E8，页面背景白色或浅灰，气泡圆角、输入框、按钮和字体尺寸按规范收敛。
- MessageBubble改为用户蓝色气泡、assistant浅灰气泡，移除多余视觉信息。
- ChatComposer改为白色底栏、顶部1px分隔线、浅灰输入框和圆形蓝色发送按钮。
- ThinkingBubble改为assistant同款浅灰气泡，跳动点使用主蓝色。
- ChatPage、LoginPage、SettingsPage、HistoryPage完成简约化样式调整。
- 验证flutter analyze通过。
- 新增google_fonts依赖，全局启用Noto Sans SC中文字体，改善Windows中文渲染一致性。
- 修复空状态“开始对话”文字样式，固定为16px、FontWeight.w400、#666666。
- 验证flutter pub get和flutter analyze通过。

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

## 2026-07-05
- 新增 `启动前端.bat`，支持在前端根目录双击启动 Flutter Windows 客户端；原统一启动脚本已拆分为前后端独立入口。

- 接入后端RAG citations结构化引用来源展示。
- Message模型新增Citation字段，ApiService支持解析/chat/stream中的citations SSE事件，ChatProvider将引用绑定到当前assistant消息。
- MessageBubble新增可展开“引用来源”区域，仅assistant消息存在citations时显示，展开后展示文件名和片段编号，不展示内部score。
- 验证flutter analyze和flutter test通过；测试覆盖流式结束后出现引用来源且展开可见。

## 2026-07-15
- expert聊天新增classify决策理由展示：ApiService识别正文前的reasoning SSE事件，ChatProvider只在当前assistant消息内存中保存，MessageBubble以浅色小字展示。
- fast模式或空reasoning不显示理由；现有正文chunk、citations和`[DONE]`处理保持不变，不新增本地持久化字段。
- `flutter analyze`无问题，完整客户端测试`10 tests passed`，覆盖reasoning解析、正文拼接、结束事件和气泡展示。
- 新增独立工具箱页面和聊天页工具箱入口，支持选择`.doc/.xls/.xlsx/.ppt/.pptx`、显示转换状态并下载个人转换产物。
- ApiService新增带JWT的`/tools/convert` multipart上传和`/tools/convert/{file_id}`下载封装，不复用聊天SSE逻辑；新增`file_picker`用于选择输入文件和保存转换结果。
- `flutter analyze`无问题，完整客户端测试增至`12 tests passed`，覆盖上传/下载请求封装、认证头、结构化响应解析和工具箱导航。
- 新增“我的文件”页面和聊天页文件夹入口，展示当前用户的聊天附件、生成文件和转换产物，支持刷新、认证下载及二次确认删除。
- 工具箱下载由旧`/tools/convert/{file_id}`迁移到统一`/files/{file_id}`；ApiService新增`GET /files`与`DELETE /files/{file_id}`封装。`flutter analyze`无问题，完整客户端测试增至`14 tests passed`。

## 2026-07-15 工具箱拖拽与聊天附件入口
- 工具箱文件区改为整区可点击，并新增`desktop_drop`桌面拖拽；点击与拖拽统一执行格式、20MB大小校验和转换上传，取消选择不触发请求，上传中禁止重复操作。
- 聊天输入区新增多附件选择按钮和内存态附件chip，支持TXT/Markdown/PDF/Word/Excel/PowerPoint；展示上传中、成功和失败状态，上传未完成时禁用发送。
- `ApiService`新增认证附件multipart上传，`ChatProvider`在SSE请求中发送成功附件的`attachment_ids`；收到`[DONE]`后清空附件，发送失败时保留，新建会话时清空。
- `flutter pub get`成功，`flutter analyze`无问题，完整客户端测试增至`18 tests passed`；关闭占用旧构建的客户端后Windows Debug构建成功，并已重新启动新版应用，系统文件对话框与拖拽操作仍需在原生窗口中人工点击复核。

## 2026-07-16 SSE长任务超时调整
- `/chat/stream`建立连接和相邻SSE事件的等待阈值由30秒提高到90秒，并配合后端15秒SSE心跳，避免文件生成已完成但客户端提前显示请求超时。
- 心跳采用SSE注释，不进入现有JSON解析、聊天正文或历史消息；`flutter analyze`无问题，完整客户端测试`18 tests passed`。

## 2026-07-16 纯附件发送与历史会话恢复
- 当前`session_id`写入SharedPreferences，历史页从后端加载当前用户全部会话并可恢复消息；新建对话追加到列表，不再覆盖既有会话状态。
- 发送校验改为文字或成功附件至少存在一项；用户消息保存附件ID和文件名，当前及历史消息气泡均展示只读附件chip。
- 快速/专家切换旁新增轻量能力说明，明确快速模式最多2次模型调用且不支持联网、生成和转换，专家模式保留完整能力。
- `flutter analyze`无问题，完整客户端测试增至`21 tests passed`。

## 2026-07-16 纯附件消息气泡显示修复
- 根因确认请求体已正确发送`attachment_ids`；空白来自气泡只按`attachment_filenames`渲染，历史或实时消息缺文件名映射时没有可见内容。
- 聊天列表改为文字或附件ID任一存在即保留消息；附件文件名缺失时显示稳定的“附件 N”chip，实时消息和历史回显使用同一逻辑。
- 新增纯附件无文件名的组件测试，并保持已有附件文件名chip行为不变。
- `flutter analyze`无问题，完整客户端回归`22 tests passed`。

## 2026-07-17 历史会话快捷管理
- 历史列表每项新增重命名和删除入口；重命名支持1-50字符及恢复默认标题，删除前二次确认。
- 列表优先显示后端`display_name`，为空时继续使用原首条消息标题；删除当前会话后自动创建新会话，避免停留在已删除状态。
- ApiService新增认证PATCH/DELETE会话管理调用及对应组件/API测试；`flutter analyze`无问题，完整回归`24 tests passed`。

## 2026-07-17 我的文件快速预览
- TXT/Markdown/PDF/DOCX文件新增预览入口，其他格式不显示；预览使用独立页面，不影响现有下载和删除操作。
- 预览页展示加载、明确错误、可选择纯文本和“内容较长，已截断显示”提示；项目无Markdown渲染依赖，因此本轮不新增依赖并统一按纯文本展示。
- ApiService新增认证预览请求和结构化响应模型；`flutter analyze`无问题，完整回归`25 tests passed`。

## 2026-07-17 PDF合并与拆分工具
- 工具箱新增“PDF合并”和“PDF拆分”模式；合并支持2-10个PDF多选或拖入，拆分支持单文件，均复用现有20MB前置校验与处理状态。
- ApiService新增认证multipart合并/拆分请求，成功产物继续通过统一`/files/{file_id}`下载；拆分结果按页展示并支持逐项保存。
- 新增请求体字段与工具箱入口测试；`flutter analyze`无问题，完整客户端回归`26 tests passed`。

## 2026-07-17 PDF工具箱选择回归修复
- 格式转换扩展名集中为单一共享常量，明确包含DOC/XLS/XLSX/PPT/PPTX；后端真实五格式转换均成功，未发现服务端白名单缩减。
- PDF合并选择改为待提交列表：多次打开选择器或拖拽会继续追加，按编号展示合并顺序，每项可独立移除；不再因首次只选1项而报错或自动提交。
- 格式转换和PDF拆分继续使用单文件流程，模式切换清空选择状态；`flutter analyze`无问题，完整客户端回归`27 tests passed`。

## 2026-07-17 工具箱六向格式转换
- 修复Word选择器遗漏`.docx`的问题，格式转换新增PDF转Word/Excel/PPT及Word/Excel/PPT转PDF六个明确选项，各选项只显示对应可选扩展名。
- 六个方向共享结构化转换配置，客户端随上传发送目标格式，避免界面标签、文件过滤器和请求参数各自硬编码后再次分叉。
- `flutter analyze`无问题，完整客户端回归`27 tests passed`；PDF反向转换为后端尽力重建，不承诺扫描件OCR或复杂版式无损恢复。

## 2026-07-17 Bronze Intelligence界面升级
- 依据`app模板`建立统一Flutter设计令牌：暖铜主色、暖灰分层表面、低阴影边框、8/12/16px圆角和900-960px内容宽度，替换原先分散的蓝灰色硬编码。
- 重做聊天工作区、消息与引用卡片、附件输入器、空状态、登录页和工具箱；历史、我的文件、文件预览及设置页同步使用统一主题和阅读宽度，原有功能与导航入口保持不变。
- 保留新建对话图标和“开始对话”语义契约以兼容既有组件测试；`flutter analyze`无问题、完整回归`27 tests passed`，Windows Release构建成功。

## 2026-07-17 模板驱动三栏工作台重构
- 聊天首页按`app模板`的固定-流式-固定结构重建：左栏集中品牌、新建会话、全局导航、最近会话与底部账号，中栏专注对话和输入，右栏集中模式选择、已接入工具及知识上下文状态。
- 现有历史、文件库、格式/PDF工具箱、附件阅读、快速/专家模式与设置均接入新工作台；模板中的团队协作、工作流、通知、分享等尚无业务实现的模块未保留。
- 窄窗口自动收缩左栏并将模式切换移入中栏标题，宽窗口展示完整三栏；`flutter analyze`无问题、完整回归`27 tests passed`，Windows Release构建成功。

## 2026-07-23 验收仓库归拢迁移
- Flutter客户端仓库迁移至`D:\zhiliao\zhitian\zhitian_app\`，独立`.git`历史与当前工作区状态均保持完整；Dart源码与配置未发现旧项目绝对路径引用。

## 2026-07-26 注册页接入邮箱验证码与180秒冷却
- 配合后端customer自助注册新增验证码机制：注册页新增邮箱验证码输入框与"发送验证码"按钮（Key分别为`register_verification_code`、`register_send_code`），交互模式与管理后台企业角色申请页一致——先发送、等待、输入、随注册请求一起提交；页面说明文案同步改为"使用邮箱注册，需通过邮箱验证码验证，注册后即可登录"。
- 冷却倒计时按后端`customer_register`用途的180秒配置显示剩余秒数并禁用按钮，`dispose()`中取消Timer避免页面卸载后继续回调；发送成功显示"验证码已发送，请查收邮箱"，失败沿用既有连接/超时/后端detail三类错误提示。
- `ApiService`新增`sendCustomerRegisterCode({email})`，请求体只含`email`与`purpose=customer_register`，**不携带企业密码**（企业密码仅企业角色场景需要）；`registerCustomer()`新增必填`verificationCode`参数并透传`verification_code`字段。提交前新增验证码非空预检，后端仍为唯一权威判断。
- 新增4项测试：`registerCustomer`与`sendCustomerRegisterCode`的请求体序列化断言（后者断言请求体不含企业密码字段）、空验证码提交时提示"请输入邮箱验证码"、发送后按钮进入180s倒计时且不可点击（邮箱无效时不发起请求）。
- `flutter analyze`无问题；完整回归`35 tests passed`（原31项）。

## 2026-07-26 登录与注册页按企业设计规范重做
- 问题：两页视觉规范各自漂移——登录页有白卡片、注册页表单直接裸露在背景上；440px卡片孤零零居中在1580px桌面窗口里，右侧大片留白；输入框用`surfaceLow`填充且边框几乎不可见，看起来是一排灰色色块；主按钮带`Icons.login`图标，与`DESIGN.md`"主按钮为纯色铜金+文字"不符。
- 新增`lib/widgets/auth_shell.dart`统一认证外壳，登录与注册共用，杜绝两页再次分头演化：宽窗口（>=960px）按设计规范的Fixed-Fluid结构展开为左侧420px品牌栏 + 右侧400px表单卡片，填满桌面画布；窄窗口退化为居中单卡片并在卡片内补精简品牌头。品牌栏用`surfaceLow`做tonal layering（规范要求用色阶而非阴影分层），展示产品定位与三条能力要点。
- 表单规范统一：字段标签独立成行（13px/w500，label-md）替代浮动label；输入框改为白底+1px可见边框、8px圆角、聚焦转主色描边（对应规范Level 1与"标准UI 8px"）；卡片16px圆角（规范"容器1rem"）；间距按4px基线整理为16/24/28/32。
- 新增`AuthMessage`行内提示条替代裸红字：错误用error色、发送成功用主色，均为浅底+描边+图标；注册页发送验证码成功提示与错误提示不再互相顶掉版面。
- 登录页主按钮去掉图标只保留"登录"，底部改为"还没有个人账号？立即注册"并加分隔线；注册页卡片内新增"返回登录"入口，密码框新增可见性切换（原先只有登录页有）。
- 修复渲染验证中发现的真实缺陷：窄窗口下品牌图标被`CrossAxisAlignment.stretch`拉成整行宽的长条，已用`Align`包住固定尺寸块。该缺陷靠实际渲染截图才发现，纯代码审查不易察觉。
- 新增`test/auth_layout_test.dart`共2项：登录页与注册页在真实桌面尺寸（1580x939）和窄窗口（720x900）下均无溢出异常，且宽窗口显示品牌栏、窄窗口收起品牌栏、全部字段Key齐全。既有3项注册页交互测试改为在1280x900桌面视口下运行——认证表单是桌面端表单，默认800x600测试窗口装不下会让按钮落在视口外。
- `flutter analyze`无问题；完整回归`37 tests passed`（原35项）。后端接口与请求体零改动，仅表现层调整。
