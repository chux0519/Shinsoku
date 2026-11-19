// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get commonBack => '返回';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonCopy => '复制';

  @override
  String get commonDone => '完成';

  @override
  String get commonClear => '清除';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonOpenSettings => '打开设置';

  @override
  String get tabRecord => '录音';

  @override
  String get tabDrafts => '草稿';

  @override
  String get tabDesktop => '电脑';

  @override
  String get tabSettings => '设置';

  @override
  String get paneSwitcherLabel => '面板';

  @override
  String get recordPlaceholder => '轻点麦克风，开始说话。';

  @override
  String get recordListeningPlaceholder => '正在聆听…';

  @override
  String get recordProcessing => '正在处理…';

  @override
  String get recordTranscriptLabel => '文本';

  @override
  String get recordCopied => '已复制。可从键盘插入，或直接粘贴。';

  @override
  String get recordSavedInsert => '已保存。可从键盘插入。';

  @override
  String get recordResultCopied => '已复制。可粘贴到任何地方，或从键盘插入。';

  @override
  String get recordStopped => '录音已停止';

  @override
  String get recordHeardTextKept => '已识别的内容保留在这里和草稿中。';

  @override
  String get recordTryAgain => '重新录音';

  @override
  String get recordStatusReady => '可以录音';

  @override
  String get recordStatusListening => '正在聆听';

  @override
  String get recordStatusListeningDetail => '说完后轻点停止。';

  @override
  String get recordStatusTranscribing => '正在转写';

  @override
  String get recordTranscribed => '录音已转写';

  @override
  String get recordTranscribingDetail => '正在把录音上传到所选的服务。';

  @override
  String get recordFailed => '录音失败';

  @override
  String get recordMicOffLabel => '麦克风访问已关闭';

  @override
  String get recordMicOffDetail => '请在 iOS 设置中允许访问麦克风，然后再试一次。';

  @override
  String get recordRecorderNotReady => '已允许使用麦克风，但录音器尚未就绪。请再试一次。';

  @override
  String get recordKeyRequiredLabel => '需要设置服务';

  @override
  String get recordKeyRequiredDetail => '录音前请先保存 Bailian 或 Soniox 的 API 密钥。';

  @override
  String get recordProfileLabel => '模式';

  @override
  String get recordButtonStart => '开始录音';

  @override
  String get recordButtonStop => '停止录音';

  @override
  String get recordButtonUnavailable => '无法录音';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => '由你选择';

  @override
  String get profileReasonAutomation => '由自动化设置';

  @override
  String get profileReasonDefault => '默认';

  @override
  String get draftsTitle => '草稿';

  @override
  String get draftsEmpty => '录音后，文本会显示在这里。';

  @override
  String get draftsToday => '今天';

  @override
  String get draftsYesterday => '昨天';

  @override
  String get draftsCopyDraft => '复制草稿';

  @override
  String get draftsDeleted => '草稿已删除';

  @override
  String get draftsCopied => '草稿已复制到剪贴板。';

  @override
  String get draftEditorTitle => '草稿';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionRecognition => '语音识别';

  @override
  String get settingsMicrophoneTitle => '麦克风访问';

  @override
  String get settingsMicrophoneAllowed => '已允许用于语音输入';

  @override
  String get settingsMicrophoneTapToAllow => '轻点以允许访问麦克风';

  @override
  String get settingsSpeechProvider => '语音识别服务';

  @override
  String get settingsPostProcessingTitle => '文本后处理';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return '使用 $model 整理或翻译文本';
  }

  @override
  String get settingsCloudTitle => '云端处理';

  @override
  String get settingsCloudSaved => '服务凭证已保存';

  @override
  String get settingsCloudNotSaved => '正式转写前请先保存服务凭证';

  @override
  String get settingsLoading => '正在载入已保存的设置';

  @override
  String get settingsRealtimeModel => '实时模型';

  @override
  String get settingsRecognitionMode => '识别方式';

  @override
  String get settingsModeStreaming => '流式';

  @override
  String get settingsStreamingModel => '流式 ASR 模型';

  @override
  String get settingsBatchModel => 'Qwen-ASR 批量模型';

  @override
  String get settingsPostProcessingModel => '后处理 OpenAI 模型';

  @override
  String get settingsPostProcessingModelHelper => '仅在开启文本后处理时使用';

  @override
  String get settingsBaseUrl => 'OpenAI 兼容的 Base URL';

  @override
  String get settingsRealtimeUrl => '实时 WebSocket URL';

  @override
  String get settingsSave => '保存设置';

  @override
  String get settingsSaving => '正在保存';

  @override
  String get settingsSaved => '服务设置已保存';

  @override
  String settingsSaveFailed(String reason) {
    return '设置未保存。$reason';
  }

  @override
  String get settingsSectionProfiles => '模式';

  @override
  String get settingsAddProfile => '添加模式';

  @override
  String get settingsUseInApps => '在 App 中使用';

  @override
  String get settingsUseInAppsSubtitle => '打开 App 时切换模式';

  @override
  String get settingsFieldRules => '输入框规则';

  @override
  String get settingsFieldRulesSubtitle => '搜索、网址、电子邮件、消息';

  @override
  String get settingsSectionKeyboard => '键盘';

  @override
  String get settingsKeyboardSetup => '键盘设置';

  @override
  String get settingsKeyboardSetupSubtitle => '添加 Shinsoku 并允许完全访问';

  @override
  String get settingsApiKey => 'API 密钥';

  @override
  String get settingsShowKey => '显示密钥';

  @override
  String get settingsHideKey => '隐藏密钥';

  @override
  String get keyboardSetupTitle => '键盘';

  @override
  String get keyboardSetupIntro => '在任何输入框中使用 Shinsoku。';

  @override
  String get keyboardStep1 => '打开“设置”›“通用”›“键盘”›“键盘”。';

  @override
  String get keyboardStep2 => '轻点“添加新键盘”，然后选择 Shinsoku。';

  @override
  String get keyboardStep3 => '轻点 Shinsoku，打开“允许完全访问”，键盘才能插入你最新的文本。';

  @override
  String get useInAppsSummary =>
      '打开某个 App 时，Shinsoku 可以自动切换模式：“快捷指令”负责检测 App，Shinsoku 负责设置模式。';

  @override
  String get useInAppsWhenOpened => '打开 App 时';

  @override
  String get useInAppsWhenClosed => '关闭 App 时';

  @override
  String get useInAppsOpenStep1 => '在“快捷指令”中打开“自动化”，轻点“新建自动化”。';

  @override
  String get useInAppsOpenStep2 => '选择“App”，选取该 App，再选择“已打开”。打开“立即运行”。';

  @override
  String get useInAppsOpenStep3 => '添加操作“设置 Shinsoku 模式”，并选择该 App 要用的模式。';

  @override
  String get useInAppsCloseStep1 => '为同一个 App 再添加一个自动化，选择“已关闭”。打开“立即运行”。';

  @override
  String get useInAppsCloseStep2 =>
      '添加“设置 Shinsoku 模式”并选择你的默认模式，这样其他 App 会回到默认模式。';

  @override
  String get useInAppsKeyboardNote => '你也可以在键盘上轻点模式名称来切换。切换后会一直保持，直到自动化再次运行。';

  @override
  String get useInAppsReadyMade =>
      '每个模式在“快捷指令”App 中还有一个现成的操作，例如“将Shinsoku切换为聊天”。无需设置。';

  @override
  String get useInAppsIosNote => '“快捷指令”操作需要 iOS 16 或更高版本。';

  @override
  String get useInAppsOpenShortcuts => '打开“快捷指令”';

  @override
  String get fieldRulesTitle => '输入框规则';

  @override
  String get fieldRulesSummary =>
      '在特定类型的输入框中自动使用某个模式。仅在你没有在键盘上选择模式、也没有自动化设置模式时生效。';

  @override
  String get fieldRulesNone => '无';

  @override
  String get fieldKindSearch => '搜索';

  @override
  String get fieldKindUrl => '网址';

  @override
  String get fieldKindEmail => '电子邮件';

  @override
  String get fieldKindMessage => '消息';

  @override
  String get profileNewTitle => '新建模式';

  @override
  String get profileEditTitle => '编辑模式';

  @override
  String get profileNameLabel => '名称';

  @override
  String get profilePromptLabel => '后处理提示词';

  @override
  String get profilePromptHelper => '例如：把中文语音翻译成自然的英文。';

  @override
  String get profileAfterText => '文本之后';

  @override
  String get profileSuffixNothing => '无';

  @override
  String get profileSuffixSpace => '空格';

  @override
  String get profileSuffixNewLine => '换行';

  @override
  String get profileAutoCommit => '自动提交';

  @override
  String get profileAutoCommitSubtitle => '直接插入，不再确认';

  @override
  String get profileDelete => '删除模式';

  @override
  String profileDeleteConfirm(String name) {
    return '删除“$name”？';
  }

  @override
  String get profileKeepOne => '至少要保留一个模式';

  @override
  String get profileUntitled => '未命名';

  @override
  String get profileDefaultIntent => '整理这段转写文本，只返回最终文本。';

  @override
  String get profileDictationName => '听写';

  @override
  String get profileDictationIntent => '把口语整理成通顺的书面文字';

  @override
  String get profileChatName => '聊天';

  @override
  String get profileChatIntent => '让文字简洁、口语化';

  @override
  String get profileReviewName => '检查';

  @override
  String get profileReviewIntent => '保留文本，供手动检查';

  @override
  String get profileZhToEnName => '中→英';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => '翻译→英';

  @override
  String get profileTranslateToEnIntent =>
      'Translate the speech into natural English, whatever language it is in. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileJaToEnName => '日→英';

  @override
  String get profileJaToEnIntent =>
      'Translate Japanese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileKoToEnName => '韩→英';

  @override
  String get profileKoToEnIntent =>
      'Translate Korean speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileDeToEnName => '德→英';

  @override
  String get profileDeToEnIntent =>
      'Translate German speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileEsToEnName => '西→英';

  @override
  String get profileEsToEnIntent =>
      'Translate Spanish speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileFrToEnName => '法→英';

  @override
  String get profileFrToEnIntent =>
      'Translate French speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profilePtToEnName => '葡→英';

  @override
  String get profilePtToEnIntent =>
      'Translate Portuguese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileItToEnName => '意→英';

  @override
  String get profileItToEnIntent =>
      'Translate Italian speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get shellAlreadyRecording => 'Shinsoku 已在录音。';

  @override
  String shellPostProcessingEnabled(String profile) {
    return '已为“$profile”开启文本后处理。';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return '后处理设置未保存。$reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return '无法复制文本。$reason';
  }

  @override
  String get failureTimeout => '服务响应超时。请检查网络连接后再试一次。';

  @override
  String get failureNetwork => '无法连接到服务。请检查网络后再试一次。';

  @override
  String get failureConnectionLost => '连接已断开。请再试一次。';

  @override
  String get failureKeyMissing => '尚未保存 API 密钥。请在设置中添加。';

  @override
  String get failureKeyInvalid => '服务未接受你的 API 密钥。请在设置中检查。';

  @override
  String get failureQuota => '服务提示额度已用完或请求过多。请检查你的账户。';

  @override
  String get failureNothingHeard => '没有识别到语音。请再试一次。';

  @override
  String get failureRecording => '录音未能完成。请再试一次。';

  @override
  String get failureMicrophone => '麦克风不可用。请在设置中检查麦克风访问权限。';

  @override
  String get failureGeneric => '出了点问题。请再试一次。';

  @override
  String get nearbyTitle => '电脑麦克风';

  @override
  String get nearbySubtitle => '私密的本地连接';

  @override
  String get nearbySectionDesktop => '电脑';

  @override
  String get nearbyFindDesktops => '查找电脑';

  @override
  String get nearbyAddManually => '手动添加电脑';

  @override
  String get nearbyEndpointLabel => 'WSS 地址';

  @override
  String get nearbyCertificateLabel => '证书 SHA-256';

  @override
  String get nearbyAdd => '添加';

  @override
  String get nearbySectionTrust => '信任';

  @override
  String get nearbyTrustedDesktop => '已信任的电脑';

  @override
  String get nearbyCertificateFingerprint => '证书指纹';

  @override
  String get nearbyMatchesTitle => '与电脑设置中的一致';

  @override
  String get nearbyMatchesSubtitle => '请与电脑上“设置”中的指纹对照';

  @override
  String get nearbyPairingCodeLabel => '电脑上显示的配对码';

  @override
  String get nearbyDisconnect => '断开连接';

  @override
  String get nearbyConnect => '连接';

  @override
  String get nearbyPairAndConnect => '配对并连接';

  @override
  String get nearbyForget => '忘记此电脑';

  @override
  String get nearbySectionRemoteInput => '远程输入';

  @override
  String get nearbyProfileRow => '模式';

  @override
  String get nearbyProfileAutomatic => '由电脑自动选择';

  @override
  String get nearbyProfileSheetTitle => '电脑模式';

  @override
  String get nearbyStopAndTranscribe => '停止并转写';

  @override
  String get nearbyStartRemote => '开始远程听写';

  @override
  String get nearbyConnectToDictate => '连接电脑后即可向电脑听写';

  @override
  String nearbyConnectingTo(String name) {
    return '正在连接 $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return '已连接 $name';
  }

  @override
  String get nearbyStreaming => '正在传送麦克风音频';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在传送，丢失 $countString 帧',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => '录音已发送到电脑';

  @override
  String get nearbyNotConnected => '未连接';

  @override
  String get nearbyDisconnected => '电脑已断开连接';

  @override
  String get nearbySearching => '正在搜索本地网络';

  @override
  String get nearbyNoneFound => '未找到 Shinsoku 电脑';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '找到 $countString 台电脑',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => '已选择信任的电脑';

  @override
  String get nearbyVerifyFingerprint => '请核对电脑的指纹';

  @override
  String get nearbyTrustRemoved => '已移除本机的信任';

  @override
  String get nearbyErrorPairingCodeRequired => '请输入电脑上显示的两位数配对码。';

  @override
  String get nearbyErrorFingerprintInvalid => '证书指纹无效。请输入全部 64 个十六进制字符。';

  @override
  String get nearbyErrorEndpointInvalid => '请输入有效的 wss:// 主机和端口。';

  @override
  String get nearbyErrorCertificateChanged => '电脑的证书已更改。请忘记此电脑后重新配对。';

  @override
  String get nearbyErrorCredentialMissing =>
      '电脑仍记得这台设备，但本机的凭证已丢失。请在电脑上撤销后重新配对。';

  @override
  String get nearbyErrorPairingUnavailable => '请先在电脑的设置中生成配对码，然后再连接。';

  @override
  String get nearbyErrorPairingExpired => '电脑上的配对码已过期。请生成一个新的。';

  @override
  String get nearbyErrorWrongCode => '配对码不正确。';

  @override
  String get nearbyErrorAttemptsExhausted => '配对尝试次数已用完。请在电脑上生成新的配对码。';

  @override
  String get nearbyErrorDesktopBusy => '电脑正在录音或处理音频。';

  @override
  String get nearbyErrorConnectFirst => '录音前请先连接电脑。';

  @override
  String get nearbyErrorTimeout => '电脑没有及时响应。';

  @override
  String get nearbyErrorConnectionLost => '与电脑的连接已断开。';

  @override
  String get nearbyErrorMicDenied => '需要麦克风访问权限。请在设置中允许。';

  @override
  String get nearbyErrorRecorderNotReady => '麦克风尚未就绪。请再试一次。';

  @override
  String get nearbyErrorMicStream => '麦克风意外停止。';

  @override
  String get nearbyErrorDiscovery => '无法搜索本地网络。请检查 Wi-Fi 后再试一次。';

  @override
  String get nearbyErrorUnexpectedResponse =>
      '电脑返回了意外的响应。请在两台设备上更新 Shinsoku 后再试一次。';

  @override
  String get nearbyErrorGeneric => '电脑连接出了点问题。';

  @override
  String get proName => 'Shinsoku Pro';

  @override
  String get proBadge => 'Pro';

  @override
  String get proFeatureProfilesTitle => '自定模式';

  @override
  String get proFeatureProfilesBody => '创建自己的模式，并编辑任何模式的提示词和设置。';

  @override
  String get proFeatureAutoTitle => '按 App 自动切换';

  @override
  String get proFeatureAutoBody => '输入框规则和“快捷指令”会为你正在输入的 App 选择模式。';

  @override
  String get proFeatureDesktopTitle => '电脑';

  @override
  String get proFeatureDesktopBody => '把这部 iPhone 用作电脑上 Shinsoku 的麦克风。';

  @override
  String get proNote => '一次性购买，支持家人共享。';

  @override
  String proBuyWithPrice(String price) {
    return '以 $price 解锁';
  }

  @override
  String get proBuy => '解锁 Shinsoku Pro';

  @override
  String get proPriceLoading => '正在载入价格…';

  @override
  String get proRestore => '恢复购买';

  @override
  String get proOwned => 'Shinsoku Pro 已解锁。谢谢你！';

  @override
  String get proStatusUnlocked => '已解锁';

  @override
  String get proSettingsSubtitle => '自定模式、按 App 切换、电脑';

  @override
  String get proNoticePending => '正在等待批准。购买获批后，Pro 会立即解锁。';

  @override
  String get proNoticeCancelled => '已取消购买，不会收取任何费用。';

  @override
  String get proNoticeFailed => '购买未完成。请再试一次。';

  @override
  String get proNoticeUnavailable => '目前无法使用 App Store。请稍后再试。';

  @override
  String get proNoticeRestored => '已恢复购买。Shinsoku Pro 已解锁。';

  @override
  String get proNoticeNothingToRestore => '此 Apple 账户没有 Shinsoku Pro 的购买记录。';

  @override
  String get proLockedProfileEditor =>
      '编辑模式需要 Shinsoku Pro。你仍可以在录音界面和键盘中选择这个模式。';

  @override
  String get proLockedFieldRules =>
      '输入框规则需要 Shinsoku Pro。你设置的规则会保留，解锁 Pro 后会再次生效。';

  @override
  String get proLockedUseInApps => '通过“快捷指令”切换模式需要 Shinsoku Pro。';

  @override
  String get proLockedDesktop =>
      '把这部 iPhone 用作 Mac 或 PC 上 Shinsoku 的无线麦克风：在这里说话，文字就会出现在电脑上。电脑功能属于 Shinsoku Pro。';

  @override
  String get proUnlockShort => '获取 Pro';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get commonBack => '返回';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonCopy => '复制';

  @override
  String get commonDone => '完成';

  @override
  String get commonClear => '清除';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonOpenSettings => '打开设置';

  @override
  String get tabRecord => '录音';

  @override
  String get tabDrafts => '草稿';

  @override
  String get tabDesktop => '电脑';

  @override
  String get tabSettings => '设置';

  @override
  String get paneSwitcherLabel => '面板';

  @override
  String get recordPlaceholder => '轻点麦克风，开始说话。';

  @override
  String get recordListeningPlaceholder => '正在聆听…';

  @override
  String get recordProcessing => '正在处理…';

  @override
  String get recordTranscriptLabel => '文本';

  @override
  String get recordCopied => '已复制。可从键盘插入，或直接粘贴。';

  @override
  String get recordSavedInsert => '已保存。可从键盘插入。';

  @override
  String get recordResultCopied => '已复制。可粘贴到任何地方，或从键盘插入。';

  @override
  String get recordStopped => '录音已停止';

  @override
  String get recordHeardTextKept => '已识别的内容保留在这里和草稿中。';

  @override
  String get recordTryAgain => '重新录音';

  @override
  String get recordStatusReady => '可以录音';

  @override
  String get recordStatusListening => '正在聆听';

  @override
  String get recordStatusListeningDetail => '说完后轻点停止。';

  @override
  String get recordStatusTranscribing => '正在转写';

  @override
  String get recordTranscribed => '录音已转写';

  @override
  String get recordTranscribingDetail => '正在把录音上传到所选的服务。';

  @override
  String get recordFailed => '录音失败';

  @override
  String get recordMicOffLabel => '麦克风访问已关闭';

  @override
  String get recordMicOffDetail => '请在 iOS 设置中允许访问麦克风，然后再试一次。';

  @override
  String get recordRecorderNotReady => '已允许使用麦克风，但录音器尚未就绪。请再试一次。';

  @override
  String get recordKeyRequiredLabel => '需要设置服务';

  @override
  String get recordKeyRequiredDetail => '录音前请先保存 Bailian 或 Soniox 的 API 密钥。';

  @override
  String get recordProfileLabel => '模式';

  @override
  String get recordButtonStart => '开始录音';

  @override
  String get recordButtonStop => '停止录音';

  @override
  String get recordButtonUnavailable => '无法录音';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => '由你选择';

  @override
  String get profileReasonAutomation => '由自动化设置';

  @override
  String get profileReasonDefault => '默认';

  @override
  String get draftsTitle => '草稿';

  @override
  String get draftsEmpty => '录音后，文本会显示在这里。';

  @override
  String get draftsToday => '今天';

  @override
  String get draftsYesterday => '昨天';

  @override
  String get draftsCopyDraft => '复制草稿';

  @override
  String get draftsDeleted => '草稿已删除';

  @override
  String get draftsCopied => '草稿已复制到剪贴板。';

  @override
  String get draftEditorTitle => '草稿';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionRecognition => '语音识别';

  @override
  String get settingsMicrophoneTitle => '麦克风访问';

  @override
  String get settingsMicrophoneAllowed => '已允许用于语音输入';

  @override
  String get settingsMicrophoneTapToAllow => '轻点以允许访问麦克风';

  @override
  String get settingsSpeechProvider => '语音识别服务';

  @override
  String get settingsPostProcessingTitle => '文本后处理';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return '使用 $model 整理或翻译文本';
  }

  @override
  String get settingsCloudTitle => '云端处理';

  @override
  String get settingsCloudSaved => '服务凭证已保存';

  @override
  String get settingsCloudNotSaved => '正式转写前请先保存服务凭证';

  @override
  String get settingsLoading => '正在载入已保存的设置';

  @override
  String get settingsRealtimeModel => '实时模型';

  @override
  String get settingsRecognitionMode => '识别方式';

  @override
  String get settingsModeStreaming => '流式';

  @override
  String get settingsStreamingModel => '流式 ASR 模型';

  @override
  String get settingsBatchModel => 'Qwen-ASR 批量模型';

  @override
  String get settingsPostProcessingModel => '后处理 OpenAI 模型';

  @override
  String get settingsPostProcessingModelHelper => '仅在开启文本后处理时使用';

  @override
  String get settingsBaseUrl => 'OpenAI 兼容的 Base URL';

  @override
  String get settingsRealtimeUrl => '实时 WebSocket URL';

  @override
  String get settingsSave => '保存设置';

  @override
  String get settingsSaving => '正在保存';

  @override
  String get settingsSaved => '服务设置已保存';

  @override
  String settingsSaveFailed(String reason) {
    return '设置未保存。$reason';
  }

  @override
  String get settingsSectionProfiles => '模式';

  @override
  String get settingsAddProfile => '添加模式';

  @override
  String get settingsUseInApps => '在 App 中使用';

  @override
  String get settingsUseInAppsSubtitle => '打开 App 时切换模式';

  @override
  String get settingsFieldRules => '输入框规则';

  @override
  String get settingsFieldRulesSubtitle => '搜索、网址、电子邮件、消息';

  @override
  String get settingsSectionKeyboard => '键盘';

  @override
  String get settingsKeyboardSetup => '键盘设置';

  @override
  String get settingsKeyboardSetupSubtitle => '添加 Shinsoku 并允许完全访问';

  @override
  String get settingsApiKey => 'API 密钥';

  @override
  String get settingsShowKey => '显示密钥';

  @override
  String get settingsHideKey => '隐藏密钥';

  @override
  String get keyboardSetupTitle => '键盘';

  @override
  String get keyboardSetupIntro => '在任何输入框中使用 Shinsoku。';

  @override
  String get keyboardStep1 => '打开“设置”›“通用”›“键盘”›“键盘”。';

  @override
  String get keyboardStep2 => '轻点“添加新键盘”，然后选择 Shinsoku。';

  @override
  String get keyboardStep3 => '轻点 Shinsoku，打开“允许完全访问”，键盘才能插入你最新的文本。';

  @override
  String get useInAppsSummary =>
      '打开某个 App 时，Shinsoku 可以自动切换模式：“快捷指令”负责检测 App，Shinsoku 负责设置模式。';

  @override
  String get useInAppsWhenOpened => '打开 App 时';

  @override
  String get useInAppsWhenClosed => '关闭 App 时';

  @override
  String get useInAppsOpenStep1 => '在“快捷指令”中打开“自动化”，轻点“新建自动化”。';

  @override
  String get useInAppsOpenStep2 => '选择“App”，选取该 App，再选择“已打开”。打开“立即运行”。';

  @override
  String get useInAppsOpenStep3 => '添加操作“设置 Shinsoku 模式”，并选择该 App 要用的模式。';

  @override
  String get useInAppsCloseStep1 => '为同一个 App 再添加一个自动化，选择“已关闭”。打开“立即运行”。';

  @override
  String get useInAppsCloseStep2 =>
      '添加“设置 Shinsoku 模式”并选择你的默认模式，这样其他 App 会回到默认模式。';

  @override
  String get useInAppsKeyboardNote => '你也可以在键盘上轻点模式名称来切换。切换后会一直保持，直到自动化再次运行。';

  @override
  String get useInAppsReadyMade =>
      '每个模式在“快捷指令”App 中还有一个现成的操作，例如“将Shinsoku切换为聊天”。无需设置。';

  @override
  String get useInAppsIosNote => '“快捷指令”操作需要 iOS 16 或更高版本。';

  @override
  String get useInAppsOpenShortcuts => '打开“快捷指令”';

  @override
  String get fieldRulesTitle => '输入框规则';

  @override
  String get fieldRulesSummary =>
      '在特定类型的输入框中自动使用某个模式。仅在你没有在键盘上选择模式、也没有自动化设置模式时生效。';

  @override
  String get fieldRulesNone => '无';

  @override
  String get fieldKindSearch => '搜索';

  @override
  String get fieldKindUrl => '网址';

  @override
  String get fieldKindEmail => '电子邮件';

  @override
  String get fieldKindMessage => '消息';

  @override
  String get profileNewTitle => '新建模式';

  @override
  String get profileEditTitle => '编辑模式';

  @override
  String get profileNameLabel => '名称';

  @override
  String get profilePromptLabel => '后处理提示词';

  @override
  String get profilePromptHelper => '例如：把中文语音翻译成自然的英文。';

  @override
  String get profileAfterText => '文本之后';

  @override
  String get profileSuffixNothing => '无';

  @override
  String get profileSuffixSpace => '空格';

  @override
  String get profileSuffixNewLine => '换行';

  @override
  String get profileAutoCommit => '自动提交';

  @override
  String get profileAutoCommitSubtitle => '直接插入，不再确认';

  @override
  String get profileDelete => '删除模式';

  @override
  String profileDeleteConfirm(String name) {
    return '删除“$name”？';
  }

  @override
  String get profileKeepOne => '至少要保留一个模式';

  @override
  String get profileUntitled => '未命名';

  @override
  String get profileDefaultIntent => '整理这段转写文本，只返回最终文本。';

  @override
  String get profileDictationName => '听写';

  @override
  String get profileDictationIntent => '把口语整理成通顺的书面文字';

  @override
  String get profileChatName => '聊天';

  @override
  String get profileChatIntent => '让文字简洁、口语化';

  @override
  String get profileReviewName => '检查';

  @override
  String get profileReviewIntent => '保留文本，供手动检查';

  @override
  String get profileZhToEnName => '中→英';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => '翻译→英';

  @override
  String get profileTranslateToEnIntent =>
      'Translate the speech into natural English, whatever language it is in. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileJaToEnName => '日→英';

  @override
  String get profileJaToEnIntent =>
      'Translate Japanese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileKoToEnName => '韩→英';

  @override
  String get profileKoToEnIntent =>
      'Translate Korean speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileDeToEnName => '德→英';

  @override
  String get profileDeToEnIntent =>
      'Translate German speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileEsToEnName => '西→英';

  @override
  String get profileEsToEnIntent =>
      'Translate Spanish speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileFrToEnName => '法→英';

  @override
  String get profileFrToEnIntent =>
      'Translate French speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profilePtToEnName => '葡→英';

  @override
  String get profilePtToEnIntent =>
      'Translate Portuguese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileItToEnName => '意→英';

  @override
  String get profileItToEnIntent =>
      'Translate Italian speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get shellAlreadyRecording => 'Shinsoku 已在录音。';

  @override
  String shellPostProcessingEnabled(String profile) {
    return '已为“$profile”开启文本后处理。';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return '后处理设置未保存。$reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return '无法复制文本。$reason';
  }

  @override
  String get failureTimeout => '服务响应超时。请检查网络连接后再试一次。';

  @override
  String get failureNetwork => '无法连接到服务。请检查网络后再试一次。';

  @override
  String get failureConnectionLost => '连接已断开。请再试一次。';

  @override
  String get failureKeyMissing => '尚未保存 API 密钥。请在设置中添加。';

  @override
  String get failureKeyInvalid => '服务未接受你的 API 密钥。请在设置中检查。';

  @override
  String get failureQuota => '服务提示额度已用完或请求过多。请检查你的账户。';

  @override
  String get failureNothingHeard => '没有识别到语音。请再试一次。';

  @override
  String get failureRecording => '录音未能完成。请再试一次。';

  @override
  String get failureMicrophone => '麦克风不可用。请在设置中检查麦克风访问权限。';

  @override
  String get failureGeneric => '出了点问题。请再试一次。';

  @override
  String get nearbyTitle => '电脑麦克风';

  @override
  String get nearbySubtitle => '私密的本地连接';

  @override
  String get nearbySectionDesktop => '电脑';

  @override
  String get nearbyFindDesktops => '查找电脑';

  @override
  String get nearbyAddManually => '手动添加电脑';

  @override
  String get nearbyEndpointLabel => 'WSS 地址';

  @override
  String get nearbyCertificateLabel => '证书 SHA-256';

  @override
  String get nearbyAdd => '添加';

  @override
  String get nearbySectionTrust => '信任';

  @override
  String get nearbyTrustedDesktop => '已信任的电脑';

  @override
  String get nearbyCertificateFingerprint => '证书指纹';

  @override
  String get nearbyMatchesTitle => '与电脑设置中的一致';

  @override
  String get nearbyMatchesSubtitle => '请与电脑上“设置”中的指纹对照';

  @override
  String get nearbyPairingCodeLabel => '电脑上显示的配对码';

  @override
  String get nearbyDisconnect => '断开连接';

  @override
  String get nearbyConnect => '连接';

  @override
  String get nearbyPairAndConnect => '配对并连接';

  @override
  String get nearbyForget => '忘记此电脑';

  @override
  String get nearbySectionRemoteInput => '远程输入';

  @override
  String get nearbyProfileRow => '模式';

  @override
  String get nearbyProfileAutomatic => '由电脑自动选择';

  @override
  String get nearbyProfileSheetTitle => '电脑模式';

  @override
  String get nearbyStopAndTranscribe => '停止并转写';

  @override
  String get nearbyStartRemote => '开始远程听写';

  @override
  String get nearbyConnectToDictate => '连接电脑后即可向电脑听写';

  @override
  String nearbyConnectingTo(String name) {
    return '正在连接 $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return '已连接 $name';
  }

  @override
  String get nearbyStreaming => '正在传送麦克风音频';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在传送，丢失 $countString 帧',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => '录音已发送到电脑';

  @override
  String get nearbyNotConnected => '未连接';

  @override
  String get nearbyDisconnected => '电脑已断开连接';

  @override
  String get nearbySearching => '正在搜索本地网络';

  @override
  String get nearbyNoneFound => '未找到 Shinsoku 电脑';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '找到 $countString 台电脑',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => '已选择信任的电脑';

  @override
  String get nearbyVerifyFingerprint => '请核对电脑的指纹';

  @override
  String get nearbyTrustRemoved => '已移除本机的信任';

  @override
  String get nearbyErrorPairingCodeRequired => '请输入电脑上显示的两位数配对码。';

  @override
  String get nearbyErrorFingerprintInvalid => '证书指纹无效。请输入全部 64 个十六进制字符。';

  @override
  String get nearbyErrorEndpointInvalid => '请输入有效的 wss:// 主机和端口。';

  @override
  String get nearbyErrorCertificateChanged => '电脑的证书已更改。请忘记此电脑后重新配对。';

  @override
  String get nearbyErrorCredentialMissing =>
      '电脑仍记得这台设备，但本机的凭证已丢失。请在电脑上撤销后重新配对。';

  @override
  String get nearbyErrorPairingUnavailable => '请先在电脑的设置中生成配对码，然后再连接。';

  @override
  String get nearbyErrorPairingExpired => '电脑上的配对码已过期。请生成一个新的。';

  @override
  String get nearbyErrorWrongCode => '配对码不正确。';

  @override
  String get nearbyErrorAttemptsExhausted => '配对尝试次数已用完。请在电脑上生成新的配对码。';

  @override
  String get nearbyErrorDesktopBusy => '电脑正在录音或处理音频。';

  @override
  String get nearbyErrorConnectFirst => '录音前请先连接电脑。';

  @override
  String get nearbyErrorTimeout => '电脑没有及时响应。';

  @override
  String get nearbyErrorConnectionLost => '与电脑的连接已断开。';

  @override
  String get nearbyErrorMicDenied => '需要麦克风访问权限。请在设置中允许。';

  @override
  String get nearbyErrorRecorderNotReady => '麦克风尚未就绪。请再试一次。';

  @override
  String get nearbyErrorMicStream => '麦克风意外停止。';

  @override
  String get nearbyErrorDiscovery => '无法搜索本地网络。请检查 Wi-Fi 后再试一次。';

  @override
  String get nearbyErrorUnexpectedResponse =>
      '电脑返回了意外的响应。请在两台设备上更新 Shinsoku 后再试一次。';

  @override
  String get nearbyErrorGeneric => '电脑连接出了点问题。';

  @override
  String get proName => 'Shinsoku Pro';

  @override
  String get proBadge => 'Pro';

  @override
  String get proFeatureProfilesTitle => '自定模式';

  @override
  String get proFeatureProfilesBody => '创建自己的模式，并编辑任何模式的提示词和设置。';

  @override
  String get proFeatureAutoTitle => '按 App 自动切换';

  @override
  String get proFeatureAutoBody => '输入框规则和“快捷指令”会为你正在输入的 App 选择模式。';

  @override
  String get proFeatureDesktopTitle => '电脑';

  @override
  String get proFeatureDesktopBody => '把这部 iPhone 用作电脑上 Shinsoku 的麦克风。';

  @override
  String get proNote => '一次性购买，支持家人共享。';

  @override
  String proBuyWithPrice(String price) {
    return '以 $price 解锁';
  }

  @override
  String get proBuy => '解锁 Shinsoku Pro';

  @override
  String get proPriceLoading => '正在载入价格…';

  @override
  String get proRestore => '恢复购买';

  @override
  String get proOwned => 'Shinsoku Pro 已解锁。谢谢你！';

  @override
  String get proStatusUnlocked => '已解锁';

  @override
  String get proSettingsSubtitle => '自定模式、按 App 切换、电脑';

  @override
  String get proNoticePending => '正在等待批准。购买获批后，Pro 会立即解锁。';

  @override
  String get proNoticeCancelled => '已取消购买，不会收取任何费用。';

  @override
  String get proNoticeFailed => '购买未完成。请再试一次。';

  @override
  String get proNoticeUnavailable => '目前无法使用 App Store。请稍后再试。';

  @override
  String get proNoticeRestored => '已恢复购买。Shinsoku Pro 已解锁。';

  @override
  String get proNoticeNothingToRestore => '此 Apple 账户没有 Shinsoku Pro 的购买记录。';

  @override
  String get proLockedProfileEditor =>
      '编辑模式需要 Shinsoku Pro。你仍可以在录音界面和键盘中选择这个模式。';

  @override
  String get proLockedFieldRules =>
      '输入框规则需要 Shinsoku Pro。你设置的规则会保留，解锁 Pro 后会再次生效。';

  @override
  String get proLockedUseInApps => '通过“快捷指令”切换模式需要 Shinsoku Pro。';

  @override
  String get proLockedDesktop =>
      '把这部 iPhone 用作 Mac 或 PC 上 Shinsoku 的无线麦克风：在这里说话，文字就会出现在电脑上。电脑功能属于 Shinsoku Pro。';

  @override
  String get proUnlockShort => '获取 Pro';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get commonBack => '返回';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '儲存';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonCopy => '拷貝';

  @override
  String get commonDone => '完成';

  @override
  String get commonClear => '清除';

  @override
  String get commonUndo => '還原';

  @override
  String get commonOpenSettings => '打開設定';

  @override
  String get tabRecord => '錄音';

  @override
  String get tabDrafts => '草稿';

  @override
  String get tabDesktop => '電腦';

  @override
  String get tabSettings => '設定';

  @override
  String get paneSwitcherLabel => '面板';

  @override
  String get recordPlaceholder => '點一下麥克風，開始說話。';

  @override
  String get recordListeningPlaceholder => '正在聆聽…';

  @override
  String get recordProcessing => '正在處理…';

  @override
  String get recordTranscriptLabel => '文字';

  @override
  String get recordCopied => '已拷貝。可從鍵盤插入，或直接貼上。';

  @override
  String get recordSavedInsert => '已儲存。可從鍵盤插入。';

  @override
  String get recordResultCopied => '已拷貝。可貼到任何地方，或從鍵盤插入。';

  @override
  String get recordStopped => '錄音已停止';

  @override
  String get recordHeardTextKept => '已辨識的內容會保留在這裡和草稿中。';

  @override
  String get recordTryAgain => '重新錄音';

  @override
  String get recordStatusReady => '可以錄音';

  @override
  String get recordStatusListening => '正在聆聽';

  @override
  String get recordStatusListeningDetail => '說完後點一下停止。';

  @override
  String get recordStatusTranscribing => '正在轉成文字';

  @override
  String get recordTranscribed => '錄音已轉成文字';

  @override
  String get recordTranscribingDetail => '正在將錄音上傳到所選的服務。';

  @override
  String get recordFailed => '錄音失敗';

  @override
  String get recordMicOffLabel => '麥克風取用已關閉';

  @override
  String get recordMicOffDetail => '請在 iOS 設定中允許取用麥克風，然後再試一次。';

  @override
  String get recordRecorderNotReady => '已允許使用麥克風，但錄音器尚未就緒。請再試一次。';

  @override
  String get recordKeyRequiredLabel => '需要設定服務';

  @override
  String get recordKeyRequiredDetail => '錄音前請先儲存 Bailian 或 Soniox 的 API 金鑰。';

  @override
  String get recordProfileLabel => '模式';

  @override
  String get recordButtonStart => '開始錄音';

  @override
  String get recordButtonStop => '停止錄音';

  @override
  String get recordButtonUnavailable => '無法錄音';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => '由你選擇';

  @override
  String get profileReasonAutomation => '由自動化操作設定';

  @override
  String get profileReasonDefault => '預設';

  @override
  String get draftsTitle => '草稿';

  @override
  String get draftsEmpty => '錄音後，文字會顯示在這裡。';

  @override
  String get draftsToday => '今天';

  @override
  String get draftsYesterday => '昨天';

  @override
  String get draftsCopyDraft => '拷貝草稿';

  @override
  String get draftsDeleted => '草稿已刪除';

  @override
  String get draftsCopied => '草稿已拷貝到剪貼板。';

  @override
  String get draftEditorTitle => '草稿';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionRecognition => '語音辨識';

  @override
  String get settingsMicrophoneTitle => '麥克風取用';

  @override
  String get settingsMicrophoneAllowed => '已允許用於語音輸入';

  @override
  String get settingsMicrophoneTapToAllow => '點一下以允許取用麥克風';

  @override
  String get settingsSpeechProvider => '語音辨識服務';

  @override
  String get settingsPostProcessingTitle => '文字後處理';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return '使用 $model 整理或翻譯文字';
  }

  @override
  String get settingsCloudTitle => '雲端處理';

  @override
  String get settingsCloudSaved => '服務憑證已儲存';

  @override
  String get settingsCloudNotSaved => '正式轉成文字前請先儲存服務憑證';

  @override
  String get settingsLoading => '正在載入已儲存的設定';

  @override
  String get settingsRealtimeModel => '即時模型';

  @override
  String get settingsRecognitionMode => '辨識方式';

  @override
  String get settingsModeStreaming => '串流';

  @override
  String get settingsStreamingModel => '串流 ASR 模型';

  @override
  String get settingsBatchModel => 'Qwen-ASR 批次模型';

  @override
  String get settingsPostProcessingModel => '後處理 OpenAI 模型';

  @override
  String get settingsPostProcessingModelHelper => '僅在開啟文字後處理時使用';

  @override
  String get settingsBaseUrl => 'OpenAI 相容的 Base URL';

  @override
  String get settingsRealtimeUrl => '即時 WebSocket URL';

  @override
  String get settingsSave => '儲存設定';

  @override
  String get settingsSaving => '正在儲存';

  @override
  String get settingsSaved => '服務設定已儲存';

  @override
  String settingsSaveFailed(String reason) {
    return '設定未儲存。$reason';
  }

  @override
  String get settingsSectionProfiles => '模式';

  @override
  String get settingsAddProfile => '新增模式';

  @override
  String get settingsUseInApps => '在 App 中使用';

  @override
  String get settingsUseInAppsSubtitle => '打開 App 時切換模式';

  @override
  String get settingsFieldRules => '欄位規則';

  @override
  String get settingsFieldRulesSubtitle => '搜尋、網址、電子郵件、訊息';

  @override
  String get settingsSectionKeyboard => '鍵盤';

  @override
  String get settingsKeyboardSetup => '鍵盤設定';

  @override
  String get settingsKeyboardSetupSubtitle => '加入 Shinsoku 並允許完整取用';

  @override
  String get settingsApiKey => 'API 金鑰';

  @override
  String get settingsShowKey => '顯示金鑰';

  @override
  String get settingsHideKey => '隱藏金鑰';

  @override
  String get keyboardSetupTitle => '鍵盤';

  @override
  String get keyboardSetupIntro => '在任何文字欄位中使用 Shinsoku。';

  @override
  String get keyboardStep1 => '打開「設定」›「一般」›「鍵盤」›「鍵盤」。';

  @override
  String get keyboardStep2 => '點一下「新增鍵盤」，然後選擇 Shinsoku。';

  @override
  String get keyboardStep3 => '點一下 Shinsoku，開啟「允許完整取用」，鍵盤才能插入你最新的文字。';

  @override
  String get useInAppsSummary =>
      '打開某個 App 時，Shinsoku 可以自動切換模式：「捷徑」負責偵測 App，Shinsoku 負責設定模式。';

  @override
  String get useInAppsWhenOpened => '打開 App 時';

  @override
  String get useInAppsWhenClosed => '關閉 App 時';

  @override
  String get useInAppsOpenStep1 => '在「捷徑」中打開「自動化操作」，點一下「新增自動化操作」。';

  @override
  String get useInAppsOpenStep2 => '選擇「App」，選取該 App，再選擇「已打開」。開啟「立即執行」。';

  @override
  String get useInAppsOpenStep3 => '加入動作「設定 Shinsoku 模式」，並選擇該 App 要用的模式。';

  @override
  String get useInAppsCloseStep1 => '為同一個 App 再加入一個自動化操作，選擇「已關閉」。開啟「立即執行」。';

  @override
  String get useInAppsCloseStep2 =>
      '加入「設定 Shinsoku 模式」並選擇你的預設模式，這樣其他 App 會回到預設模式。';

  @override
  String get useInAppsKeyboardNote =>
      '你也可以在鍵盤上點一下模式名稱來切換。切換後會一直保持，直到自動化操作再次執行。';

  @override
  String get useInAppsReadyMade =>
      '每個模式在「捷徑」App 中還有一個現成的動作，例如「將Shinsoku切換為聊天」。不需要設定。';

  @override
  String get useInAppsIosNote => '「捷徑」動作需要 iOS 16 或以上版本。';

  @override
  String get useInAppsOpenShortcuts => '打開「捷徑」';

  @override
  String get fieldRulesTitle => '欄位規則';

  @override
  String get fieldRulesSummary =>
      '在特定類型的欄位中自動使用某個模式。只在你沒有從鍵盤選擇模式、也沒有自動化操作設定模式時生效。';

  @override
  String get fieldRulesNone => '無';

  @override
  String get fieldKindSearch => '搜尋';

  @override
  String get fieldKindUrl => '網址';

  @override
  String get fieldKindEmail => '電子郵件';

  @override
  String get fieldKindMessage => '訊息';

  @override
  String get profileNewTitle => '新增模式';

  @override
  String get profileEditTitle => '編輯模式';

  @override
  String get profileNameLabel => '名稱';

  @override
  String get profilePromptLabel => '後處理提示詞';

  @override
  String get profilePromptHelper => '例如：將中文語音翻譯成自然的英文。';

  @override
  String get profileAfterText => '文字之後';

  @override
  String get profileSuffixNothing => '無';

  @override
  String get profileSuffixSpace => '空格';

  @override
  String get profileSuffixNewLine => '換行';

  @override
  String get profileAutoCommit => '自動送出';

  @override
  String get profileAutoCommitSubtitle => '直接插入，不再確認';

  @override
  String get profileDelete => '刪除模式';

  @override
  String profileDeleteConfirm(String name) {
    return '要刪除「$name」嗎？';
  }

  @override
  String get profileKeepOne => '至少要保留一個模式';

  @override
  String get profileUntitled => '未命名';

  @override
  String get profileDefaultIntent => '整理這段轉寫文字，只回傳最終文字。';

  @override
  String get profileDictationName => '聽寫';

  @override
  String get profileDictationIntent => '將口語整理成通順的書面文字';

  @override
  String get profileChatName => '聊天';

  @override
  String get profileChatIntent => '讓文字簡潔、口語化';

  @override
  String get profileReviewName => '檢查';

  @override
  String get profileReviewIntent => '保留文字，供手動檢查';

  @override
  String get profileZhToEnName => '中→英';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => '翻譯→英';

  @override
  String get profileTranslateToEnIntent =>
      'Translate the speech into natural English, whatever language it is in. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileJaToEnName => '日→英';

  @override
  String get profileJaToEnIntent =>
      'Translate Japanese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileKoToEnName => '韓→英';

  @override
  String get profileKoToEnIntent =>
      'Translate Korean speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileDeToEnName => '德→英';

  @override
  String get profileDeToEnIntent =>
      'Translate German speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileEsToEnName => '西→英';

  @override
  String get profileEsToEnIntent =>
      'Translate Spanish speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileFrToEnName => '法→英';

  @override
  String get profileFrToEnIntent =>
      'Translate French speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profilePtToEnName => '葡→英';

  @override
  String get profilePtToEnIntent =>
      'Translate Portuguese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileItToEnName => '義→英';

  @override
  String get profileItToEnIntent =>
      'Translate Italian speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get shellAlreadyRecording => 'Shinsoku 已在錄音。';

  @override
  String shellPostProcessingEnabled(String profile) {
    return '已為「$profile」開啟文字後處理。';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return '後處理設定未儲存。$reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return '無法拷貝文字。$reason';
  }

  @override
  String get failureTimeout => '服務回應逾時。請檢查網路連線後再試一次。';

  @override
  String get failureNetwork => '無法連線到服務。請檢查網路後再試一次。';

  @override
  String get failureConnectionLost => '連線已中斷。請再試一次。';

  @override
  String get failureKeyMissing => '尚未儲存 API 金鑰。請在設定中新增。';

  @override
  String get failureKeyInvalid => '服務不接受你的 API 金鑰。請在設定中檢查。';

  @override
  String get failureQuota => '服務表示額度已用完或請求過多。請檢查你的帳號。';

  @override
  String get failureNothingHeard => '沒有辨識到語音。請再試一次。';

  @override
  String get failureRecording => '錄音未能完成。請再試一次。';

  @override
  String get failureMicrophone => '麥克風無法使用。請在設定中檢查麥克風取用權限。';

  @override
  String get failureGeneric => '發生問題。請再試一次。';

  @override
  String get nearbyTitle => '電腦麥克風';

  @override
  String get nearbySubtitle => '私密的區域網路連線';

  @override
  String get nearbySectionDesktop => '電腦';

  @override
  String get nearbyFindDesktops => '尋找電腦';

  @override
  String get nearbyAddManually => '手動加入電腦';

  @override
  String get nearbyEndpointLabel => 'WSS 位址';

  @override
  String get nearbyCertificateLabel => '憑證 SHA-256';

  @override
  String get nearbyAdd => '加入';

  @override
  String get nearbySectionTrust => '信任';

  @override
  String get nearbyTrustedDesktop => '已信任的電腦';

  @override
  String get nearbyCertificateFingerprint => '憑證指紋';

  @override
  String get nearbyMatchesTitle => '與電腦設定中的一致';

  @override
  String get nearbyMatchesSubtitle => '請與電腦上「設定」中的指紋對照';

  @override
  String get nearbyPairingCodeLabel => '電腦上顯示的配對碼';

  @override
  String get nearbyDisconnect => '中斷連線';

  @override
  String get nearbyConnect => '連線';

  @override
  String get nearbyPairAndConnect => '配對並連線';

  @override
  String get nearbyForget => '忘記這台電腦';

  @override
  String get nearbySectionRemoteInput => '遠端輸入';

  @override
  String get nearbyProfileRow => '模式';

  @override
  String get nearbyProfileAutomatic => '由電腦自動選擇';

  @override
  String get nearbyProfileSheetTitle => '電腦模式';

  @override
  String get nearbyStopAndTranscribe => '停止並轉成文字';

  @override
  String get nearbyStartRemote => '開始遠端聽寫';

  @override
  String get nearbyConnectToDictate => '連線電腦後即可向電腦聽寫';

  @override
  String nearbyConnectingTo(String name) {
    return '正在連線到 $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return '已連線到 $name';
  }

  @override
  String get nearbyStreaming => '正在傳送麥克風音訊';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在傳送，遺失 $countString 個影格',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => '錄音已傳送到電腦';

  @override
  String get nearbyNotConnected => '未連線';

  @override
  String get nearbyDisconnected => '電腦已中斷連線';

  @override
  String get nearbySearching => '正在搜尋區域網路';

  @override
  String get nearbyNoneFound => '找不到 Shinsoku 電腦';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '找到 $countString 台電腦',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => '已選擇信任的電腦';

  @override
  String get nearbyVerifyFingerprint => '請核對電腦的指紋';

  @override
  String get nearbyTrustRemoved => '已移除本機的信任';

  @override
  String get nearbyErrorPairingCodeRequired => '請輸入電腦上顯示的兩位數配對碼。';

  @override
  String get nearbyErrorFingerprintInvalid => '憑證指紋無效。請輸入全部 64 個十六進位字元。';

  @override
  String get nearbyErrorEndpointInvalid => '請輸入有效的 wss:// 主機和連接埠。';

  @override
  String get nearbyErrorCertificateChanged => '電腦的憑證已變更。請忘記這台電腦後重新配對。';

  @override
  String get nearbyErrorCredentialMissing =>
      '電腦仍記得這部裝置，但本機的憑證已遺失。請在電腦上撤銷後重新配對。';

  @override
  String get nearbyErrorPairingUnavailable => '請先在電腦的設定中產生配對碼，然後再連線。';

  @override
  String get nearbyErrorPairingExpired => '電腦上的配對碼已過期。請產生新的配對碼。';

  @override
  String get nearbyErrorWrongCode => '配對碼不正確。';

  @override
  String get nearbyErrorAttemptsExhausted => '配對嘗試次數已用完。請在電腦上產生新的配對碼。';

  @override
  String get nearbyErrorDesktopBusy => '電腦正在錄音或處理音訊。';

  @override
  String get nearbyErrorConnectFirst => '錄音前請先連線電腦。';

  @override
  String get nearbyErrorTimeout => '電腦沒有及時回應。';

  @override
  String get nearbyErrorConnectionLost => '與電腦的連線已中斷。';

  @override
  String get nearbyErrorMicDenied => '需要麥克風取用權限。請在設定中允許。';

  @override
  String get nearbyErrorRecorderNotReady => '麥克風尚未就緒。請再試一次。';

  @override
  String get nearbyErrorMicStream => '麥克風意外停止。';

  @override
  String get nearbyErrorDiscovery => '無法搜尋區域網路。請檢查 Wi-Fi 後再試一次。';

  @override
  String get nearbyErrorUnexpectedResponse =>
      '電腦傳回了非預期的回應。請在兩部裝置上更新 Shinsoku 後再試一次。';

  @override
  String get nearbyErrorGeneric => '電腦連線發生問題。';

  @override
  String get proName => 'Shinsoku Pro';

  @override
  String get proBadge => 'Pro';

  @override
  String get proFeatureProfilesTitle => '自訂模式';

  @override
  String get proFeatureProfilesBody => '建立自己的模式，並編輯任何模式的提示詞和設定。';

  @override
  String get proFeatureAutoTitle => '依 App 自動切換';

  @override
  String get proFeatureAutoBody => '欄位規則和「捷徑」會為你正在輸入的 App 選擇模式。';

  @override
  String get proFeatureDesktopTitle => '電腦';

  @override
  String get proFeatureDesktopBody => '將這部 iPhone 當作電腦上 Shinsoku 的麥克風。';

  @override
  String get proNote => '一次性購買，支援家人共享。';

  @override
  String proBuyWithPrice(String price) {
    return '以 $price 解鎖';
  }

  @override
  String get proBuy => '解鎖 Shinsoku Pro';

  @override
  String get proPriceLoading => '正在載入價格…';

  @override
  String get proRestore => '恢復購買';

  @override
  String get proOwned => 'Shinsoku Pro 已解鎖。謝謝你！';

  @override
  String get proStatusUnlocked => '已解鎖';

  @override
  String get proSettingsSubtitle => '自訂模式、依 App 切換、電腦';

  @override
  String get proNoticePending => '正在等待核准。購買獲得核准後，Pro 就會立即解鎖。';

  @override
  String get proNoticeCancelled => '已取消購買，不會收取任何費用。';

  @override
  String get proNoticeFailed => '購買未完成。請再試一次。';

  @override
  String get proNoticeUnavailable => '目前無法使用 App Store。請稍後再試。';

  @override
  String get proNoticeRestored => '已恢復購買。Shinsoku Pro 已解鎖。';

  @override
  String get proNoticeNothingToRestore => '這個 Apple 帳號沒有 Shinsoku Pro 的購買紀錄。';

  @override
  String get proLockedProfileEditor =>
      '編輯模式需要 Shinsoku Pro。你仍可在錄音畫面和鍵盤中選擇這個模式。';

  @override
  String get proLockedFieldRules =>
      '欄位規則需要 Shinsoku Pro。你設定的規則會保留，解鎖 Pro 後會再次生效。';

  @override
  String get proLockedUseInApps => '從「捷徑」切換模式需要 Shinsoku Pro。';

  @override
  String get proLockedDesktop =>
      '將這部 iPhone 當作 Mac 或 PC 上 Shinsoku 的無線麥克風：在這裡說話，文字就會出現在電腦上。電腦功能屬於 Shinsoku Pro。';

  @override
  String get proUnlockShort => '取得 Pro';
}
