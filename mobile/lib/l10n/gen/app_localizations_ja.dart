// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get commonBack => '戻る';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '削除';

  @override
  String get commonCopy => 'コピー';

  @override
  String get commonDone => '完了';

  @override
  String get commonClear => '消去';

  @override
  String get commonUndo => '取り消す';

  @override
  String get commonOpenSettings => '設定を開く';

  @override
  String get tabRecord => '録音';

  @override
  String get tabDrafts => '下書き';

  @override
  String get tabDesktop => 'デスクトップ';

  @override
  String get tabSettings => '設定';

  @override
  String get paneSwitcherLabel => '表示パネル';

  @override
  String get recordPlaceholder => 'マイクをタップして話してください。';

  @override
  String get recordListeningPlaceholder => '聞き取り中…';

  @override
  String get recordProcessing => '処理中…';

  @override
  String get recordTranscriptLabel => 'テキスト';

  @override
  String get recordCopied => 'コピーしました。キーボードから挿入するか、ペーストしてください。';

  @override
  String get recordSavedInsert => '保存しました。キーボードから挿入できます。';

  @override
  String get recordResultCopied => 'コピーしました。どこにでもペーストするか、キーボードから挿入できます。';

  @override
  String get recordStopped => '録音が止まりました';

  @override
  String get recordHeardTextKept => '聞き取れた部分はここと下書きに残っています。';

  @override
  String get recordTryAgain => 'もう一度録音';

  @override
  String get recordStatusReady => '録音できます';

  @override
  String get recordStatusListening => '聞き取り中';

  @override
  String get recordStatusListeningDetail => '話し終えたら停止をタップしてください。';

  @override
  String get recordStatusTranscribing => '文字起こし中';

  @override
  String get recordTranscribed => '文字起こしが完了しました';

  @override
  String get recordTranscribingDetail => '録音した音声を選択したサービスに送信しています。';

  @override
  String get recordFailed => '録音できませんでした';

  @override
  String get recordMicOffLabel => 'マイクへのアクセスがオフです';

  @override
  String get recordMicOffDetail => 'iOSの設定でマイクへのアクセスを許可してから、もう一度録音してください。';

  @override
  String get recordRecorderNotReady =>
      'マイクは許可されていますが、録音の準備ができていません。もう一度お試しください。';

  @override
  String get recordKeyRequiredLabel => 'サービスの設定が必要です';

  @override
  String get recordKeyRequiredDetail =>
      '録音する前に、BailianまたはSonioxのAPIキーを保存してください。';

  @override
  String get recordProfileLabel => 'プロファイル';

  @override
  String get recordButtonStart => '録音を開始';

  @override
  String get recordButtonStop => '録音を停止';

  @override
  String get recordButtonUnavailable => '録音できません';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => '手動で選択';

  @override
  String get profileReasonAutomation => 'オートメーションで設定';

  @override
  String get profileReasonDefault => 'デフォルト';

  @override
  String get draftsTitle => '下書き';

  @override
  String get draftsEmpty => '録音すると、ここにテキストが表示されます。';

  @override
  String get draftsToday => '今日';

  @override
  String get draftsYesterday => '昨日';

  @override
  String get draftsCopyDraft => '下書きをコピー';

  @override
  String get draftsDeleted => '下書きを削除しました';

  @override
  String get draftsCopied => '下書きをクリップボードにコピーしました。';

  @override
  String get draftEditorTitle => '下書き';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionRecognition => '音声認識';

  @override
  String get settingsMicrophoneTitle => 'マイクへのアクセス';

  @override
  String get settingsMicrophoneAllowed => '音声入力に許可されています';

  @override
  String get settingsMicrophoneTapToAllow => 'タップしてマイクへのアクセスを許可';

  @override
  String get settingsSpeechProvider => '音声認識サービス';

  @override
  String get settingsPostProcessingTitle => 'テキストの後処理';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return '$modelで整形や翻訳をします';
  }

  @override
  String get settingsCloudTitle => 'クラウド処理';

  @override
  String get settingsCloudSaved => 'サービスの認証情報は保存済みです';

  @override
  String get settingsCloudNotSaved => '実際に文字起こしする前に認証情報を保存してください';

  @override
  String get settingsLoading => '保存した設定を読み込み中';

  @override
  String get settingsRealtimeModel => 'リアルタイムモデル';

  @override
  String get settingsRecognitionMode => '認識方式';

  @override
  String get settingsModeStreaming => 'ストリーミング';

  @override
  String get settingsStreamingModel => 'ストリーミングASRモデル';

  @override
  String get settingsBatchModel => 'Qwen-ASR一括モデル';

  @override
  String get settingsPostProcessingModel => '後処理用OpenAIモデル';

  @override
  String get settingsPostProcessingModelHelper => 'テキストの後処理がオンのときだけ使います';

  @override
  String get settingsBaseUrl => 'OpenAI互換のベースURL';

  @override
  String get settingsRealtimeUrl => 'リアルタイムWebSocket URL';

  @override
  String get settingsSave => '設定を保存';

  @override
  String get settingsSaving => '保存中';

  @override
  String get settingsSaved => 'サービスの設定を保存しました';

  @override
  String settingsSaveFailed(String reason) {
    return '設定を保存できませんでした。$reason';
  }

  @override
  String get settingsSectionProfiles => 'プロファイル';

  @override
  String get settingsAddProfile => 'プロファイルを追加';

  @override
  String get settingsUseInApps => 'Appで使う';

  @override
  String get settingsUseInAppsSubtitle => 'Appを開いたときにプロファイルを切り替える';

  @override
  String get settingsFieldRules => '入力欄ルール';

  @override
  String get settingsFieldRulesSubtitle => '検索、Webアドレス、メール、メッセージ';

  @override
  String get settingsSectionKeyboard => 'キーボード';

  @override
  String get settingsKeyboardSetup => 'キーボードの設定';

  @override
  String get settingsKeyboardSetupSubtitle => 'Shinsokuを追加してフルアクセスを許可';

  @override
  String get settingsApiKey => 'APIキー';

  @override
  String get settingsShowKey => 'キーを表示';

  @override
  String get settingsHideKey => 'キーを隠す';

  @override
  String get keyboardSetupTitle => 'キーボード';

  @override
  String get keyboardSetupIntro => 'どの入力欄からでもShinsokuを使えます。';

  @override
  String get keyboardStep1 => '「設定」›「一般」›「キーボード」›「キーボード」を開きます。';

  @override
  String get keyboardStep2 => '「新しいキーボードを追加」をタップして、Shinsokuを選びます。';

  @override
  String get keyboardStep3 =>
      'Shinsokuをタップして「フルアクセスを許可」をオンにします。これで最新のテキストを挿入できます。';

  @override
  String get useInAppsSummary =>
      'Appを開いたときに、Shinsokuが自動でプロファイルを切り替えられます。「ショートカット」がAppの起動を検知し、Shinsokuがプロファイルを設定します。';

  @override
  String get useInAppsWhenOpened => 'Appを開いたとき';

  @override
  String get useInAppsWhenClosed => 'Appを閉じたとき';

  @override
  String get useInAppsOpenStep1 =>
      '「ショートカット」で「オートメーション」を開き、「新規オートメーション」をタップします。';

  @override
  String get useInAppsOpenStep2 =>
      '「App」を選んでAppを指定し、「開いている」を選びます。「すぐに実行」をオンにします。';

  @override
  String get useInAppsOpenStep3 =>
      'アクション「Shinsokuのプロファイルを設定」を追加して、そのAppで使うプロファイルを選びます。';

  @override
  String get useInAppsCloseStep1 =>
      '同じAppに2つ目のオートメーションを追加して、「閉じている」を選びます。「すぐに実行」をオンにします。';

  @override
  String get useInAppsCloseStep2 =>
      '「Shinsokuのプロファイルを設定」を追加してデフォルトのプロファイルを選ぶと、ほかのAppではそちらに戻ります。';

  @override
  String get useInAppsKeyboardNote =>
      'キーボードのプロファイル名をタップしても切り替えられます。次にオートメーションが実行されるまでそのままです。';

  @override
  String get useInAppsReadyMade =>
      '各プロファイルには「ショートカット」Appですぐ使えるアクションもあります（例：「Shinsokuをチャットに切り替える」）。設定は不要です。';

  @override
  String get useInAppsIosNote => '「ショートカット」のアクションにはiOS 16以降が必要です。';

  @override
  String get useInAppsOpenShortcuts => '「ショートカット」を開く';

  @override
  String get fieldRulesTitle => '入力欄ルール';

  @override
  String get fieldRulesSummary =>
      '特定の種類の入力欄で、プロファイルを自動で使います。キーボードでプロファイルを選んでおらず、オートメーションでも設定されていないときだけ適用されます。';

  @override
  String get fieldRulesNone => 'なし';

  @override
  String get fieldKindSearch => '検索';

  @override
  String get fieldKindUrl => 'Webアドレス';

  @override
  String get fieldKindEmail => 'メール';

  @override
  String get fieldKindMessage => 'メッセージ';

  @override
  String get profileNewTitle => '新規プロファイル';

  @override
  String get profileEditTitle => 'プロファイルを編集';

  @override
  String get profileNameLabel => '名前';

  @override
  String get profilePromptLabel => '後処理のプロンプト';

  @override
  String get profilePromptHelper => '例：日本語の音声を自然な英語に翻訳する。';

  @override
  String get profileAfterText => 'テキストの後';

  @override
  String get profileSuffixNothing => 'なし';

  @override
  String get profileSuffixSpace => 'スペース';

  @override
  String get profileSuffixNewLine => '改行';

  @override
  String get profileAutoCommit => '自動で確定';

  @override
  String get profileAutoCommitSubtitle => '確認せずに挿入します';

  @override
  String get profileDelete => 'プロファイルを削除';

  @override
  String profileDeleteConfirm(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get profileKeepOne => 'プロファイルは1つ以上必要です';

  @override
  String get profileUntitled => '名称未設定';

  @override
  String get profileDefaultIntent => '文字起こしを整えてください。最終的なテキストだけを返してください。';

  @override
  String get profileDictationName => '音声入力';

  @override
  String get profileDictationIntent => '話し言葉を自然な文章に整える';

  @override
  String get profileChatName => 'チャット';

  @override
  String get profileChatIntent => '簡潔で会話らしい文にする';

  @override
  String get profileReviewName => '確認';

  @override
  String get profileReviewIntent => 'テキストを手動で確認するために保留する';

  @override
  String get profileTranslationDescription => '話した内容を英語に翻訳';

  @override
  String get profileZhToEnName => '中→英';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => '翻訳→英';

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
  String get profileDeToEnName => '独→英';

  @override
  String get profileDeToEnIntent =>
      'Translate German speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileEsToEnName => '西→英';

  @override
  String get profileEsToEnIntent =>
      'Translate Spanish speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileFrToEnName => '仏→英';

  @override
  String get profileFrToEnIntent =>
      'Translate French speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profilePtToEnName => '葡→英';

  @override
  String get profilePtToEnIntent =>
      'Translate Portuguese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileItToEnName => '伊→英';

  @override
  String get profileItToEnIntent =>
      'Translate Italian speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get shellAlreadyRecording => 'Shinsokuはすでに録音中です。';

  @override
  String shellPostProcessingEnabled(String profile) {
    return '$profileのテキスト後処理をオンにしました。';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return '後処理の設定を保存できませんでした。$reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'テキストをコピーできませんでした。$reason';
  }

  @override
  String get failureTimeout => 'サービスの応答に時間がかかりすぎています。接続を確認して、もう一度お試しください。';

  @override
  String get failureNetwork => 'サービスに接続できません。ネットワークを確認して、もう一度お試しください。';

  @override
  String get failureConnectionLost => '接続が切れました。もう一度お試しください。';

  @override
  String get failureKeyMissing => 'APIキーが保存されていません。設定で追加してください。';

  @override
  String get failureKeyInvalid => 'APIキーがサービスに受け付けられませんでした。設定で確認してください。';

  @override
  String get failureQuota => '利用枠の上限に達したか、リクエストが多すぎます。アカウントを確認してください。';

  @override
  String get failureNothingHeard => '音声を認識できませんでした。もう一度お試しください。';

  @override
  String get failureRecording => '録音を完了できませんでした。もう一度お試しください。';

  @override
  String get failureMicrophone => 'マイクを使用できません。設定でマイクへのアクセスを確認してください。';

  @override
  String get failureGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get nearbyTitle => 'デスクトップマイク';

  @override
  String get nearbySubtitle => 'ローカルネットワーク内のプライベート接続';

  @override
  String get nearbySectionDesktop => 'デスクトップ';

  @override
  String get nearbyFindDesktops => 'デスクトップを探す';

  @override
  String get nearbyAddManually => 'デスクトップを手動で追加';

  @override
  String get nearbyEndpointLabel => 'WSSエンドポイント';

  @override
  String get nearbyCertificateLabel => '証明書のSHA-256';

  @override
  String get nearbyAdd => '追加';

  @override
  String get nearbySectionTrust => '信頼';

  @override
  String get nearbyTrustedDesktop => '信頼済みのデスクトップ';

  @override
  String get nearbyCertificateFingerprint => '証明書のフィンガープリント';

  @override
  String get nearbyMatchesTitle => 'デスクトップの設定と一致';

  @override
  String get nearbyMatchesSubtitle => 'デスクトップの設定画面と見比べてください';

  @override
  String get nearbyPairingCodeLabel => 'デスクトップに表示されたペアリングコード';

  @override
  String get nearbyDisconnect => '切断';

  @override
  String get nearbyConnect => '接続';

  @override
  String get nearbyPairAndConnect => 'ペアリングして接続';

  @override
  String get nearbyForget => 'デスクトップの登録を解除';

  @override
  String get nearbySectionRemoteInput => 'リモート入力';

  @override
  String get nearbyProfileRow => 'プロファイル';

  @override
  String get nearbyProfileAutomatic => 'デスクトップで自動';

  @override
  String get nearbyProfileSheetTitle => 'デスクトップのプロファイル';

  @override
  String get nearbyStopAndTranscribe => '停止して文字起こし';

  @override
  String get nearbyStartRemote => 'リモート音声入力を開始';

  @override
  String get nearbyConnectToDictate => 'デスクトップに接続すると音声入力できます';

  @override
  String nearbyConnectingTo(String name) {
    return '$nameに接続中';
  }

  @override
  String nearbyConnectedTo(String name) {
    return '$nameに接続済み';
  }

  @override
  String get nearbyStreaming => 'マイクの音声を送信中';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '送信中（$countStringフレーム欠落）',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => '録音をデスクトップに送信しました';

  @override
  String get nearbyNotConnected => '未接続';

  @override
  String get nearbyDisconnected => 'デスクトップとの接続が切れました';

  @override
  String get nearbySearching => 'ローカルネットワークを検索中';

  @override
  String get nearbyNoneFound => 'Shinsokuのデスクトップが見つかりません';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString台のデスクトップが見つかりました',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => '信頼済みのデスクトップを選択しました';

  @override
  String get nearbyVerifyFingerprint => 'デスクトップのフィンガープリントを確認してください';

  @override
  String get nearbyTrustRemoved => 'この端末での信頼を解除しました';

  @override
  String get nearbyErrorPairingCodeRequired => 'デスクトップに表示された2桁のコードを入力してください。';

  @override
  String get nearbyErrorFingerprintInvalid =>
      '証明書のフィンガープリントが正しくありません。16進数で64文字すべて入力してください。';

  @override
  String get nearbyErrorEndpointInvalid => '有効なwss://ホストとポートを入力してください。';

  @override
  String get nearbyErrorCertificateChanged =>
      'デスクトップの証明書が変わりました。登録を解除して、もう一度ペアリングしてください。';

  @override
  String get nearbyErrorCredentialMissing =>
      'デスクトップはこの端末を記憶していますが、この端末の認証情報がありません。デスクトップで取り消してから、もう一度ペアリングしてください。';

  @override
  String get nearbyErrorPairingUnavailable =>
      'デスクトップの設定でペアリングコードを作成してから、もう一度接続してください。';

  @override
  String get nearbyErrorPairingExpired =>
      'デスクトップのペアリングコードの有効期限が切れました。新しいコードを作成してください。';

  @override
  String get nearbyErrorWrongCode => 'ペアリングコードが正しくありません。';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'ペアリングの試行回数の上限に達しました。デスクトップで新しいコードを作成してください。';

  @override
  String get nearbyErrorDesktopBusy => 'デスクトップはすでに録音中か、音声を処理中です。';

  @override
  String get nearbyErrorConnectFirst => '録音する前にデスクトップに接続してください。';

  @override
  String get nearbyErrorTimeout => 'デスクトップから時間内に応答がありませんでした。';

  @override
  String get nearbyErrorConnectionLost => 'デスクトップとの接続が切れました。';

  @override
  String get nearbyErrorMicDenied => 'マイクへのアクセスが必要です。設定で許可してください。';

  @override
  String get nearbyErrorRecorderNotReady => 'マイクの準備ができていません。もう一度お試しください。';

  @override
  String get nearbyErrorMicStream => 'マイクが予期せず停止しました。';

  @override
  String get nearbyErrorDiscovery =>
      'ローカルネットワークを検索できませんでした。Wi-Fiを確認して、もう一度お試しください。';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'デスクトップから予期しない応答がありました。両方の端末でShinsokuをアップデートして、もう一度お試しください。';

  @override
  String get nearbyErrorGeneric => 'デスクトップとの接続で問題が発生しました。';

  @override
  String get proName => 'Shinsoku Pro';

  @override
  String get proBadge => 'Pro';

  @override
  String get proFeatureProfilesTitle => 'カスタムプロファイル';

  @override
  String get proFeatureProfilesBody =>
      '自分だけのプロファイルを作成し、どのプロファイルのプロンプトや設定も編集できます。';

  @override
  String get proFeatureAutoTitle => 'Appごとに自動切り替え';

  @override
  String get proFeatureAutoBody => '入力欄ルールと「ショートカット」が、入力中のAppに合ったプロファイルを選びます。';

  @override
  String get proFeatureDesktopTitle => 'デスクトップ';

  @override
  String get proFeatureDesktopBody => 'このiPhoneを、コンピュータで使うShinsokuのマイクにできます。';

  @override
  String get proNote => '1回限りの購入です。ファミリー共有に対応しています。';

  @override
  String proBuyWithPrice(String price) {
    return '$priceで購入';
  }

  @override
  String get proBuy => 'Shinsoku Proを購入';

  @override
  String get proPriceLoading => '価格を読み込み中…';

  @override
  String get proRestore => '購入を復元';

  @override
  String get proOwned => 'Shinsoku Proのロックが解除されています。ありがとうございます！';

  @override
  String get proStatusUnlocked => 'ロック解除済み';

  @override
  String get proSettingsSubtitle => 'カスタムプロファイル、Appごとの切り替え、デスクトップ';

  @override
  String get proNoticePending => '承認待ちです。購入が承認されるとすぐにProのロックが解除されます。';

  @override
  String get proNoticeCancelled => '購入をキャンセルしました。請求はありません。';

  @override
  String get proNoticeFailed => '購入を完了できませんでした。もう一度お試しください。';

  @override
  String get proNoticeUnavailable => '現在App Storeを利用できません。しばらくしてからもう一度お試しください。';

  @override
  String get proNoticeRestored => '購入を復元しました。Shinsoku Proのロックが解除されました。';

  @override
  String get proNoticeNothingToRestore =>
      'このAppleアカウントでは、Shinsoku Proの過去の購入が見つかりませんでした。';

  @override
  String get proLockedProfileEditor =>
      'プロファイルの編集にはShinsoku Proが必要です。このプロファイルは録音画面やキーボードで引き続き選べます。';

  @override
  String get proLockedFieldRules =>
      '入力欄ルールにはShinsoku Proが必要です。設定したルールは保持され、Proのロックを解除すると再び適用されます。';

  @override
  String get proLockedUseInApps =>
      '「ショートカット」からプロファイルを切り替えるにはShinsoku Proが必要です。';

  @override
  String get proLockedDesktop =>
      'このiPhoneを、MacやPCで使うShinsokuのワイヤレスマイクにできます。ここで話すと、テキストがコンピュータに入力されます。デスクトップはShinsoku Proの機能です。';

  @override
  String get proUnlockShort => 'Proを入手';
}
