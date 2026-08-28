# zhitian_app CHANGELOG

## 2026-08-11 文件体积预筛统一放宽到5MB
- `ApiService.maxUploadSizeMb/maxUploadSizeBytes`由1MB同步调整为5MB，聊天附件与工具箱继续共用同一常量，不形成两套客户端限制；后端文档入库仍以2,000切片限制实际处理时长，客户端体积值只负责请求前预筛。
- 新增共享常量断言防止三端再次脱节；`flutter analyze --no-pub`无问题，完整`flutter test --no-pub`为`45 tests passed`。

## 2026-08-09 Windows 3.0.0安装包与v3.0发布标签补齐
- 本机Inno Setup 6.7.3命令行编译器可用，但`iscc`尚未加入当前PATH；通过`C:\Program Files (x86)\Inno Setup 6\ISCC.exe /?`真实确认编译器。标准安装目录未附带脚本所需的`ChineseSimplified.isl`，本轮使用Inno Setup官方`is-6_7_3`源码中的简体中文消息文件，经标准输入编译方式保持既有中文安装流程，未改动安装器源码或应用功能。
- 重新执行`flutter build windows --release --no-pub`成功，包内`zhitian.exe`的`FileVersion`和`ProductVersion`均为`3.0.0+300`；随后由`packaging/windows_installer.iss`成功生成`dist/zhitian-windows-setup-3.0.0.exe`，文件大小`11,506,567`字节，SHA-256=`539D49812A9CF97B954C33D11654DFB855C5027F427AFC70DA53373C438F5481`。安装器自身`ProductVersion`为`3.0.0`，与Inno Setup版本格式一致。
- 已删除会与当前能力产生混淆的旧产物`dist/zhitian-windows-setup-2.6.0.exe`，`dist/`现仅保留3.0.0安装包。
- 注释标签`v3.0`已创建并推送，精确落点为版本统一提交`2fea214c18ea2dd5bc7803b7f18dd1478a56c1d3`；标签说明明确包含核心功能验证完成、F36/F37已合并、上传限制统一为1MB及版本号统一为`3.0.0+300`。本条CHANGELOG记录作为标签发布后的文档提交，不改变标签落点。

## 2026-08-09 v3.0交付缺口④：发布元数据统一为3.0.0+300
- 全仓核对未发现任何用应用版本做API协商、后端兼容判断或功能开关的代码；`pubspec.yaml`版本只进入Flutter构建元数据，Windows Runner通过`FLUTTER_VERSION*`宏写入EXE资源，Inno Setup脚本另行读取自身的`MyAppVersion`常量。
- `pubspec.yaml`由`2.6.0+260`更新为`3.0.0+300`，沿用“主次修订号去点后作为三位构建号”的既有规则；`packaging/windows_installer.iss`的`MyAppVersion`同步为`3.0.0`，输出名同步为`zhitian-windows-setup-3.0.0`。稳定`AppId`、内部`CompanyName`和`ProductName`均未改动，不影响既有SharedPreferences目录或升级保留逻辑。
- 真实验证：Flutter 3.41.6下`flutter analyze --no-pub`无问题、`flutter test --no-pub`为`42 tests passed`，`flutter build windows --release --no-pub`成功；生成的`build/windows/x64/runner/Release/zhitian.exe`真实`FileVersion`和`ProductVersion`均为`3.0.0+300`。
- 本机当前未找到`ISCC.exe`，因此本轮没有伪称生成新的3.0.0安装包；安装器源码已同步，最后一个实际构建的安装包仍是历史`zhitian-windows-setup-2.6.0.exe`。另据真实`git tag`核对，本仓库最新标签仍为`v2.7`，本轮按任务范围不创建或移动标签；若要做到客户端仓库标签也为v3.0，需要单独执行发布标记。

## 2026-08-09 F36/F37上传上限交付归位并重建Windows安装包
- 将此前仅位于本地`master`的F36提交`9ac62f0`推送到远程：聊天附件与工具箱不再各自硬编码20MB，统一读取`ApiService.maxUploadSizeMb/maxUploadSizeBytes`。用三点差异`git diff master...f37-embedding-upgrade-verify`核实F37分支真实贡献仅为`lib/services/api_service.dart`的3增3删，把共享上限由2MB同步为后端当前的1MB并更新原因注释，无其他功能夹带。
- F37以`--no-ff`合并保留独立演进节点，合并提交`949d626`已推送`origin/master`且远程HEAD逐哈希确认一致；本地`f37-embedding-upgrade-verify`已删除，远程原本不存在同名分支，最终仅保留`master`。
- 合并后`flutter analyze --no-pub`无问题，`flutter test --no-pub`为`42 tests passed`；源码常量`maxUploadSizeMb=1`与后端`config.MAX_UPLOAD_SIZE_MB=1`一致。
- 沿用已有发布流程完成`flutter build windows --release --no-pub`，Release共15个文件、30,691,492字节；随后用Inno Setup 7.0.2和`packaging/windows_installer.iss`重新打包成功。新安装包`dist/zhitian-windows-setup-2.6.0.exe`为11,498,128字节，SHA-256=`92C48628A8A456A8D003CE5AAD96E645815FF1748AD056714A8C3D7C37CC0F57`。本轮未擅自变更发布元数据，应用仍为`2.6.0+260`、安装包标识仍为`2.6.0`。

## 2026-07-31 Windows Release、服务地址引导与安装升级闭环
- 后端地址由原有“设置页可修改”补齐为完整首次启动流程：未保存有效地址时先进入“连接企业服务”引导，保存到Windows `SharedPreferences`后再进入登录；设置页继续支持随时修改和不落盘的连接测试。地址统一规范化，远程地址强制HTTPS，HTTP只允许`localhost`、`127.0.0.1`和`::1`，拒绝内嵌账号密码、查询参数及片段。服务地址实际改变时清除旧JWT、角色、用户名和会话并要求重新登录，避免把A服务器令牌发送给B服务器；地址不变时不打断登录，fast/expert偏好继续保留。
- 连接失败不再只返回技术异常或笼统`error`：登录、注册、聊天、附件、文件库、预览、工具箱、首次引导和设置页统一区分网络不可达、超时及TLS证书验证失败，显示中文可操作提示。快速/专家模式新增`chat_mode`本地持久化，重启和后续升级继续使用上次选择。
- Windows发布元数据更新为版本`2.6.0+260`，窗口/文件说明和安装器显示名为“知天”，可执行文件为`zhitian.exe`，发布者显示为`Zhitian / Zheng`，并替换为蓝灰书页图标。为兼容旧版配置，EXE资源中的内部`CompanyName=com.zhitian`、`ProductName=zhitian_app`保持不变：`path_provider_windows`依赖这两个值定位SharedPreferences，改名会造成升级后看似丢失地址、登录态和会话。
- Windows Release真实构建成功：15个随包文件共`30,691,492`字节（约29.27MiB），包含`flutter_windows.dll`、插件DLL、ICU、AOT `app.so`和资源目录；在`PATH`仅保留Windows系统目录、完全不含Flutter SDK时，Release及安装后的程序均可持续启动。`flutter analyze`为0问题，完整`flutter test`为`42 tests passed`（原37项，新增5项覆盖首次引导、地址规则、证书提示和模式持久化）。
- 采用普通Inno Setup安装程序而非MSIX：当前自用/朋友分发不依赖商店证书，脚本使用稳定`AppId`、当前用户目录安装和中文界面。最终产物`dist/zhitian-windows-setup-2.6.0.exe`为`11,497,755`字节，SHA-256=`640E8E58ED1CFAF88F54E798204E2F2AFB795E93B6A544B8A3288FDB4AD2A531`；构建产物目录已加入`.gitignore`，可复现脚本和图标源文件纳入仓库。
- 真实安装链路通过：空验证目录安装AppVersion `2.5.0`模拟旧版后，覆盖升级到`2.6.0`，卸载注册表版本从2.5.0正确更新为2.6.0；已保存后端地址和临时`expert`模式键升级后均保留。卸载返回0并移除程序目录/卸载注册项，但保留用户SharedPreferences；随后重新安装2.6.0并再次卸载同样成功，作为没有第二台干净Windows环境时的卸载后重装等价验收。测试前已有用户配置最终按原始字节恢复，SHA-256一致；最终正式安装包另行安装、启动、卸载后该配置哈希也保持不变。
- 当前EXE和安装包均未做Authenticode签名，Windows可能显示SmartScreen“Windows已保护你的电脑”或“未知发布者”，自用/熟人阶段建议通过可信渠道同时提供SHA-256并提示“更多信息→仍要运行”；面向公开或商业分发前应购买受信任代码签名证书。此次使用的Inno Setup 7.0.2编译器标明仅限非商业使用，Phase C外售前还必须购买对应商业许可或迁移到NSIS/WiX，不能直接沿用当前编译器授权。

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

## 2026-08-09 明确Flutter Windows调试启动脚本的Compose边界
- `启动前端.bat`重命名为`启动Flutter Windows调试客户端.bat`，实际命令仍为`flutter run -d windows`，功能未改变。
- 脚本新增醒目说明：它只启动Flutter客户端、不负责启动Compose；配合Compose测试时后端地址必须使用`http://localhost`（不带`:8000`），`http://localhost:8000`仅用于明确启动本机非容器后端的纯调试场景，避免客户端静默连入错误数据环境。

## 2026-08-09 修复 Flutter 调试脚本 CMD 编码并完成四仓批处理审计
- **问题修复**：`启动Flutter Windows调试客户端.bat` 原为 UTF-8 无 BOM + LF，Windows CMD 按 CP936 读取时会把中文 `rem` 注释解码为乱码，并可能吞并相邻命令；现已转换为 CP936（GBK）无 BOM + CRLF。
- **核心命令保护**：转换前后逻辑文本逐字一致，`flutter run -d windows` 保持且仅出现 1 次。
- **真实运行验证**：修复后的脚本成功完成依赖解析、Windows Debug 构建并进入 `Flutter run key commands` 状态，未出现中文注释被当作命令或相邻行被吞并。
- **全仓排查**：同步检查 `zhitian`、`zhitian_admin`、`zhitian_app`、`zhitian-deploy`；共发现 8 个项目维护的 `.bat` 和后端 `.venv/Scripts` 自动生成的 2 个。后端 2 个项目脚本和本脚本完成转换，部署仓库 5 个及虚拟环境 2 个原本已符合 CP936 兼容编码 + CRLF，管理后台无批处理文件。此次为此前部署脚本编码修复遗漏范围的完整收口。

## 2026-08-09 修复 Compose 地址自救入口与 Windows 原生标题乱码
- **连接根因与契约修正**：真实Compose四服务均healthy且`/api/ready`为200，但客户端持久化的旧值为`http://localhost:8000`，宿主机8000未暴露；进一步实测`http://localhost/health`为404、`http://localhost/api/health`为200，确认Flutter的Compose API基址必须是`http://localhost/api`。默认值、首次引导、客户端README、调试批处理和部署脚本/README已统一；不带协议的`localhost/api`规范化也修正为HTTP而非误补HTTPS。
- **认证前可恢复**：登录与注册页现在始终显示当前服务器地址并提供“服务器设置”，无需登录即可修改和测试；检测到旧`:8000`配置时明确提示Compose迁移地址。地址变化仍复用既有安全行为清除旧JWT、角色、用户名和会话，避免跨服务器复用凭据。
- **标题乱码根治**：`main.cpp`为UTF-8无BOM，而Runner原先没有MSVC `/utf-8`，导致`L"知天"`按CP936编译成`鐭ゅぉ`；`windows/runner/CMakeLists.txt`现对Runner启用`/utf-8`。新Debug/Release EXE内正确“知天”各2处、错误字符串0处，隐藏启动后的Win32真实窗口标题为“知天”，版本资源仍为`3.0.0+300`。
- **安装器可复现**：Inno Setup 6.7.3默认不含`ChineseSimplified.isl`，旧脚本依赖构建机额外文件；现固定引入其官方`is-6_7_3`标签翻译到`packaging/`并改用项目内路径。新`dist/zhitian-windows-setup-3.0.0.exe`为11,508,985字节，SHA-256=`896D2013AE956970D806C69A201D4384309414CE6C2FE0DFE9FCB34C01AC4065`。
- **回归**：`flutter analyze --no-pub`无问题，完整`flutter test --no-pub`为`44 tests passed`（原42项）；Debug与Release构建、Inno安装包编译均成功。验证过程没有改写用户SharedPreferences，旧地址仍由用户在新入口中自行确认修改。

## 2026-08-15 Flutter版本源对齐v3.2
- `pubspec.yaml`由`3.0.0+300`更新为`3.2.0+320`；Inno Setup默认`AppVersion`同步为`3.2.0+320`，新输出基名为`zhitian-windows-setup-3.2.0`。安装器暂仍独立维护版本常量，已留下后续从pubspec自动读取的明确任务注释。
- `flutter analyze --no-pub`返回0且无问题。本轮只统一源码版本源，没有重新构建或覆盖已验证的3.0.0安装包；下次正式发布安装包时再以新版本生成产物并记录哈希。

## 2026-08-18 补 `.gitignore` 的 env 衍生文件规则

- 原第 27 行只有 `.env`，`.env.bak-1`、`.env.local` 这类衍生名**不被忽略**。在其紧下方补 `.env.*` 与 `!.env.example` 两行，与 `zhitian-deploy` 写法统一；Flutter 分组内其余规则未改动。
- 不做路径锚定，规则在任意子目录同样生效；防的正是「在仓库目录里建 `.env` 备份」这一真实场景（2026-08-16 曾在服务器上产生 4 个含真实密钥的 `.env` 备份，已移出仓库）。
- 实测以 `git check-ignore` 为准：`.env`、`.env.bak-1`、`.env.local` 均被忽略；临时落盘 `.env.example` 后 `git status` 显示为 `??` 未跟踪、未被忽略，测试文件已删除。

## 2026-08-18 放宽 `.gitignore` 的模板否定规则为 `!.env*.example`

- 上一轮加入的 `!.env.example` 只放行恰好同名的文件，`.env.local.example`、`.env.production.example` 这类模板会命中 `.env.*` 被静默忽略——提交时无声排除、diff 与 CI 都不报异常。本仓库改为 `!.env*.example`，只动这一行（1 增 1 删），Flutter 分组其余规则未动。
- 缺陷由知了hub 执行者在本机 Compose 验证时真实撞上（新建的 `.env.local.example` 差点消失），按「两个项目共同遵守的规则必须同时写进两份」四个仓库同批跟上。
- 落盘探针实测 7 项全过：`.env`、`.env.local`、`.env.bak-1`、`.env.production`、`lib/.env` 归 `!!`；`.env.example` 与 `.env.local.example` 均归 `??` 可被跟踪。实测口径按手册第十一章：不看退出码、用未跟踪探针文件加 `git status --ignored` 落盘判定。 探针已全部清理，仓库只剩 `.gitignore` 一处改动。

## 2026-08-28 存档：v3.2.1 覆盖 v3.2 之后的文档与忽略规则整理

- **本条为存档条目**。标签 `v3.2.1` 打在本条目所在的提交上，因此覆盖 `v3.2..v3.2.1` 共**五条**提交：`e0792d5` 版本号统一为3.2.0+320（含 Inno Setup 安装器脚本同步）、`33a0df8` 系统性文档审计与整理、`895da28` 补 `.gitignore` 的 `.env` 衍生文件规则、`1a3a805` 放宽模板否定规则为 `!.env*.example`，以及本条存档记录本身。四条业务提交自 2026-08-18 起即已推送到 `origin/master`。
- **三段式补丁号的依据**：五条提交里没有任何 Dart 代码、界面或用户可见行为变化——两条改 `.gitignore`、一条改 `README.md`、一条改版本源。按手册 8.1 第 2 条属「只有文档或协作流程整理」，按 8.1「什么时候才打标签」属累积后合并打一个补丁号。
- **⚠️ 如实标注一处记录缺口**：`33a0df8 docs: 系统性文档审计与整理`（只改 `README.md`，21 增 10 删）**当时没有留下 CHANGELOG 工作条目**。本次不追补成「当时记过」，缺口照实记，标签注释里同样写明。
- **版本源本轮不动**：`pubspec.yaml` 保持 `3.2.0+320`、`packaging/windows_installer.iss` 保持 `MyAppVersion "3.2.0+320"`，**不重新构建安装包**。三段式补丁号只标注非功能性整理，不上抬版本源；本仓库没有 `VERSION` 文件。
- **CI 结论（打标前实查，非转述）**：四条提交上唯一的 `CI` workflow **全部 success**，无红灯。HEAD `1a3a805` 为 runs/32321413873。存档前例行核对：IPv4 字面量 0 处、密钥凭据形态 0 处、服务器绝对路径 0 处、主机名 0 处、未跟踪文件 0 个、二进制改动 0 处。本仓库是独立标签线，与后端标签无对应关系。
