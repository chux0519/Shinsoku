// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get commonBack => '뒤로';

  @override
  String get commonCancel => '취소';

  @override
  String get commonSave => '저장';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonCopy => '복사';

  @override
  String get commonDone => '완료';

  @override
  String get commonClear => '지우기';

  @override
  String get commonUndo => '실행 취소';

  @override
  String get commonOpenSettings => '설정 열기';

  @override
  String get tabRecord => '녹음';

  @override
  String get tabDrafts => '초안';

  @override
  String get tabDesktop => '데스크톱';

  @override
  String get tabSettings => '설정';

  @override
  String get paneSwitcherLabel => '패널';

  @override
  String get recordPlaceholder => '마이크를 탭하고 말해 보세요.';

  @override
  String get recordListeningPlaceholder => '듣는 중…';

  @override
  String get recordProcessing => '처리 중…';

  @override
  String get recordTranscriptLabel => '텍스트';

  @override
  String get recordCopied => '복사했어요. 키보드에서 삽입하거나 붙여넣으세요.';

  @override
  String get recordSavedInsert => '저장했어요. 키보드에서 삽입하세요.';

  @override
  String get recordResultCopied => '복사했어요. 어디에나 붙여넣거나 키보드에서 삽입하세요.';

  @override
  String get recordStopped => '녹음이 중지됨';

  @override
  String get recordHeardTextKept => '인식된 내용은 여기와 초안에 남아 있어요.';

  @override
  String get recordTryAgain => '다시 녹음';

  @override
  String get recordStatusReady => '녹음 준비됨';

  @override
  String get recordStatusListening => '듣는 중';

  @override
  String get recordStatusListeningDetail => '다 말했으면 중지를 탭하세요.';

  @override
  String get recordStatusTranscribing => '텍스트로 변환 중';

  @override
  String get recordTranscribed => '녹음을 텍스트로 변환함';

  @override
  String get recordTranscribingDetail => '녹음한 오디오를 선택한 서비스로 업로드하는 중이에요.';

  @override
  String get recordFailed => '녹음 실패';

  @override
  String get recordMicOffLabel => '마이크 접근이 꺼져 있음';

  @override
  String get recordMicOffDetail => 'iOS 설정에서 마이크 접근을 허용한 다음 다시 녹음해 보세요.';

  @override
  String get recordRecorderNotReady =>
      '마이크 권한은 허용되었지만 녹음기가 준비되지 않았어요. 다시 시도하세요.';

  @override
  String get recordKeyRequiredLabel => '서비스 설정 필요';

  @override
  String get recordKeyRequiredDetail =>
      '녹음하기 전에 Bailian 또는 Soniox API 키를 저장하세요.';

  @override
  String get recordProfileLabel => '프로필';

  @override
  String get recordButtonStart => '녹음 시작';

  @override
  String get recordButtonStop => '녹음 중지';

  @override
  String get recordButtonUnavailable => '녹음할 수 없음';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => '직접 선택함';

  @override
  String get profileReasonAutomation => '자동화로 설정됨';

  @override
  String get profileReasonDefault => '기본값';

  @override
  String get draftsTitle => '초안';

  @override
  String get draftsEmpty => '녹음하면 텍스트가 여기에 표시돼요.';

  @override
  String get draftsToday => '오늘';

  @override
  String get draftsYesterday => '어제';

  @override
  String get draftsCopyDraft => '초안 복사';

  @override
  String get draftsDeleted => '초안을 삭제함';

  @override
  String get draftsCopied => '초안을 클립보드에 복사했어요.';

  @override
  String get draftEditorTitle => '초안';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSectionRecognition => '음성 인식';

  @override
  String get settingsMicrophoneTitle => '마이크 접근';

  @override
  String get settingsMicrophoneAllowed => '음성 입력에 허용됨';

  @override
  String get settingsMicrophoneTapToAllow => '탭하여 마이크 접근 허용';

  @override
  String get settingsSpeechProvider => '음성 인식 서비스';

  @override
  String get settingsPostProcessingTitle => '텍스트 후처리';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return '$model(으)로 다듬거나 번역';
  }

  @override
  String get settingsCloudTitle => '클라우드 처리';

  @override
  String get settingsCloudSaved => '서비스 인증 정보가 저장됨';

  @override
  String get settingsCloudNotSaved => '실제로 변환하기 전에 인증 정보를 저장하세요';

  @override
  String get settingsLoading => '저장된 설정을 불러오는 중';

  @override
  String get settingsRealtimeModel => '실시간 모델';

  @override
  String get settingsRecognitionMode => '인식 방식';

  @override
  String get settingsModeStreaming => '스트리밍';

  @override
  String get settingsStreamingModel => '스트리밍 ASR 모델';

  @override
  String get settingsBatchModel => 'Qwen-ASR 일괄 모델';

  @override
  String get settingsPostProcessingModel => '후처리 OpenAI 모델';

  @override
  String get settingsPostProcessingModelHelper => '텍스트 후처리가 켜져 있을 때만 사용';

  @override
  String get settingsBaseUrl => 'OpenAI 호환 기본 URL';

  @override
  String get settingsRealtimeUrl => '실시간 WebSocket URL';

  @override
  String get settingsSave => '설정 저장';

  @override
  String get settingsSaving => '저장 중';

  @override
  String get settingsSaved => '서비스 설정을 저장함';

  @override
  String settingsSaveFailed(String reason) {
    return '설정을 저장하지 못했어요. $reason';
  }

  @override
  String get settingsSectionProfiles => '프로필';

  @override
  String get settingsAddProfile => '프로필 추가';

  @override
  String get settingsUseInApps => '앱에서 사용';

  @override
  String get settingsUseInAppsSubtitle => '앱을 열면 프로필 전환';

  @override
  String get settingsFieldRules => '입력란 규칙';

  @override
  String get settingsFieldRulesSubtitle => '검색, 웹 주소, 이메일, 메시지';

  @override
  String get settingsSectionKeyboard => '키보드';

  @override
  String get settingsKeyboardSetup => '키보드 설정';

  @override
  String get settingsKeyboardSetupSubtitle => 'Shinsoku 추가 및 전체 접근 허용';

  @override
  String get settingsApiKey => 'API 키';

  @override
  String get settingsShowKey => '키 보기';

  @override
  String get settingsHideKey => '키 숨기기';

  @override
  String get keyboardSetupTitle => '키보드';

  @override
  String get keyboardSetupIntro => '모든 입력란에서 Shinsoku를 사용하세요.';

  @override
  String get keyboardStep1 => '설정 › 일반 › 키보드 › 키보드를 여세요.';

  @override
  String get keyboardStep2 => '\'새로운 키보드 추가\'를 탭하고 Shinsoku를 선택하세요.';

  @override
  String get keyboardStep3 =>
      'Shinsoku를 탭하고 \'전체 접근 허용\'을 켜세요. 그래야 키보드가 최신 텍스트를 삽입할 수 있어요.';

  @override
  String get useInAppsSummary =>
      '앱을 열 때 Shinsoku가 알아서 프로필을 전환할 수 있어요. 단축어가 앱을 감지하고, Shinsoku가 프로필을 설정해요.';

  @override
  String get useInAppsWhenOpened => '앱을 열 때';

  @override
  String get useInAppsWhenClosed => '앱을 닫을 때';

  @override
  String get useInAppsOpenStep1 => '단축어에서 \'자동화\'를 열고 \'새로운 자동화\'를 탭하세요.';

  @override
  String get useInAppsOpenStep2 =>
      '\'앱\'을 선택하고 앱을 고른 다음 \'열림\'을 선택하세요. \'즉시 실행\'을 켜세요.';

  @override
  String get useInAppsOpenStep3 =>
      '\'Shinsoku 프로필 설정\' 동작을 추가하고 그 앱에서 쓸 프로필을 선택하세요.';

  @override
  String get useInAppsCloseStep1 =>
      '같은 앱에 두 번째 자동화를 추가하고 \'닫힘\'을 선택하세요. \'즉시 실행\'을 켜세요.';

  @override
  String get useInAppsCloseStep2 =>
      '\'Shinsoku 프로필 설정\'을 추가하고 기본 프로필을 선택하면 다른 앱에서는 기본 프로필로 돌아가요.';

  @override
  String get useInAppsKeyboardNote =>
      '키보드에서 프로필 이름을 탭해 전환할 수도 있어요. 자동화가 다시 실행될 때까지 유지돼요.';

  @override
  String get useInAppsReadyMade =>
      '각 프로필에는 단축어 앱에서 바로 쓸 수 있는 동작도 있어요(예: \'Shinsoku에서 채팅 프로필로 전환\'). 따로 설정할 필요가 없어요.';

  @override
  String get useInAppsIosNote => '단축어 동작을 사용하려면 iOS 16 이상이 필요해요.';

  @override
  String get useInAppsOpenShortcuts => '단축어 열기';

  @override
  String get fieldRulesTitle => '입력란 규칙';

  @override
  String get fieldRulesSummary =>
      '특정 종류의 입력란에서 자동으로 프로필을 사용해요. 키보드에서 프로필을 고르지 않았고 자동화로 설정된 프로필도 없을 때만 적용돼요.';

  @override
  String get fieldRulesNone => '없음';

  @override
  String get fieldKindSearch => '검색';

  @override
  String get fieldKindUrl => '웹 주소';

  @override
  String get fieldKindEmail => '이메일';

  @override
  String get fieldKindMessage => '메시지';

  @override
  String get profileNewTitle => '새로운 프로필';

  @override
  String get profileEditTitle => '프로필 편집';

  @override
  String get profileNameLabel => '이름';

  @override
  String get profilePromptLabel => '후처리 프롬프트';

  @override
  String get profilePromptHelper => '예: 한국어 음성을 자연스러운 영어로 번역해 줘.';

  @override
  String get profileAfterText => '텍스트 뒤에';

  @override
  String get profileSuffixNothing => '없음';

  @override
  String get profileSuffixSpace => '공백';

  @override
  String get profileSuffixNewLine => '줄바꿈';

  @override
  String get profileAutoCommit => '자동 입력';

  @override
  String get profileAutoCommitSubtitle => '확인 없이 바로 삽입';

  @override
  String get profileDelete => '프로필 삭제';

  @override
  String profileDeleteConfirm(String name) {
    return '\'$name\' 프로필을 삭제할까요?';
  }

  @override
  String get profileKeepOne => '프로필이 하나 이상 있어야 해요';

  @override
  String get profileUntitled => '제목 없음';

  @override
  String get profileDefaultIntent => '받아쓴 텍스트를 다듬어 줘. 최종 텍스트만 돌려줘.';

  @override
  String get profileDictationName => '받아쓰기';

  @override
  String get profileDictationIntent => '말한 내용을 자연스러운 글로 다듬기';

  @override
  String get profileChatName => '채팅';

  @override
  String get profileChatIntent => '간결하고 대화체로 만들기';

  @override
  String get profileReviewName => '검토';

  @override
  String get profileReviewIntent => '직접 검토하도록 텍스트를 보류';

  @override
  String get profileZhToEnName => '중→영';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => '번역→영';

  @override
  String get profileTranslateToEnIntent =>
      'Translate the speech into natural English, whatever language it is in. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileJaToEnName => '일→영';

  @override
  String get profileJaToEnIntent =>
      'Translate Japanese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileKoToEnName => '한→영';

  @override
  String get profileKoToEnIntent =>
      'Translate Korean speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileDeToEnName => '독→영';

  @override
  String get profileDeToEnIntent =>
      'Translate German speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileEsToEnName => '스→영';

  @override
  String get profileEsToEnIntent =>
      'Translate Spanish speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileFrToEnName => '프→영';

  @override
  String get profileFrToEnIntent =>
      'Translate French speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profilePtToEnName => '포→영';

  @override
  String get profilePtToEnIntent =>
      'Translate Portuguese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileItToEnName => '이→영';

  @override
  String get profileItToEnIntent =>
      'Translate Italian speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get shellAlreadyRecording => 'Shinsoku가 이미 녹음 중이에요.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return '\'$profile\' 프로필의 텍스트 후처리를 켰어요.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return '후처리 설정을 저장하지 못했어요. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return '텍스트를 복사하지 못했어요. $reason';
  }

  @override
  String get failureTimeout => '서비스 응답이 너무 오래 걸려요. 연결을 확인하고 다시 시도하세요.';

  @override
  String get failureNetwork => '서비스에 연결할 수 없어요. 네트워크를 확인하고 다시 시도하세요.';

  @override
  String get failureConnectionLost => '연결이 끊겼어요. 다시 시도하세요.';

  @override
  String get failureKeyMissing => '저장된 API 키가 없어요. 설정에서 추가하세요.';

  @override
  String get failureKeyInvalid => '서비스가 API 키를 받아들이지 않았어요. 설정에서 확인하세요.';

  @override
  String get failureQuota => '사용량이 남아 있지 않거나 요청이 너무 많다고 해요. 계정을 확인하세요.';

  @override
  String get failureNothingHeard => '인식된 음성이 없어요. 다시 시도하세요.';

  @override
  String get failureRecording => '녹음을 완료하지 못했어요. 다시 시도하세요.';

  @override
  String get failureMicrophone => '마이크를 사용할 수 없어요. 설정에서 마이크 접근을 확인하세요.';

  @override
  String get failureGeneric => '문제가 발생했어요. 다시 시도하세요.';

  @override
  String get nearbyTitle => '데스크톱 마이크';

  @override
  String get nearbySubtitle => '비공개 로컬 연결';

  @override
  String get nearbySectionDesktop => '데스크톱';

  @override
  String get nearbyFindDesktops => '데스크톱 찾기';

  @override
  String get nearbyAddManually => '데스크톱 직접 추가';

  @override
  String get nearbyEndpointLabel => 'WSS 엔드포인트';

  @override
  String get nearbyCertificateLabel => '인증서 SHA-256';

  @override
  String get nearbyAdd => '추가';

  @override
  String get nearbySectionTrust => '신뢰';

  @override
  String get nearbyTrustedDesktop => '신뢰하는 데스크톱';

  @override
  String get nearbyCertificateFingerprint => '인증서 지문';

  @override
  String get nearbyMatchesTitle => '데스크톱 설정과 일치함';

  @override
  String get nearbyMatchesSubtitle => '데스크톱의 설정 화면과 비교하세요';

  @override
  String get nearbyPairingCodeLabel => '데스크톱에 표시된 페어링 코드';

  @override
  String get nearbyDisconnect => '연결 해제';

  @override
  String get nearbyConnect => '연결';

  @override
  String get nearbyPairAndConnect => '페어링 후 연결';

  @override
  String get nearbyForget => '데스크톱 지우기';

  @override
  String get nearbySectionRemoteInput => '원격 입력';

  @override
  String get nearbyProfileRow => '프로필';

  @override
  String get nearbyProfileAutomatic => '데스크톱에서 자동';

  @override
  String get nearbyProfileSheetTitle => '데스크톱 프로필';

  @override
  String get nearbyStopAndTranscribe => '중지하고 텍스트로 변환';

  @override
  String get nearbyStartRemote => '원격 받아쓰기 시작';

  @override
  String get nearbyConnectToDictate => '데스크톱에 연결하면 받아쓰기할 수 있어요';

  @override
  String nearbyConnectingTo(String name) {
    return '$name에 연결 중';
  }

  @override
  String nearbyConnectedTo(String name) {
    return '$name에 연결됨';
  }

  @override
  String get nearbyStreaming => '마이크 오디오 전송 중';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '전송 중, $countString개 프레임 누락',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => '녹음을 데스크톱으로 보냄';

  @override
  String get nearbyNotConnected => '연결 안 됨';

  @override
  String get nearbyDisconnected => '데스크톱 연결이 끊김';

  @override
  String get nearbySearching => '로컬 네트워크 검색 중';

  @override
  String get nearbyNoneFound => 'Shinsoku 데스크톱을 찾지 못함';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '데스크톱 $countString대를 찾음',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => '신뢰하는 데스크톱을 선택함';

  @override
  String get nearbyVerifyFingerprint => '데스크톱 지문을 확인하세요';

  @override
  String get nearbyTrustRemoved => '이 기기의 신뢰를 제거함';

  @override
  String get nearbyErrorPairingCodeRequired => '데스크톱에 표시된 두 자리 코드를 입력하세요.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      '인증서 지문이 올바르지 않아요. 16진수 64자를 모두 입력하세요.';

  @override
  String get nearbyErrorEndpointInvalid => '올바른 wss:// 호스트와 포트를 입력하세요.';

  @override
  String get nearbyErrorCertificateChanged =>
      '데스크톱 인증서가 바뀌었어요. 데스크톱을 지우고 다시 페어링하세요.';

  @override
  String get nearbyErrorCredentialMissing =>
      '데스크톱은 이 기기를 기억하지만 이 기기의 인증 정보가 없어요. 데스크톱에서 취소한 다음 다시 페어링하세요.';

  @override
  String get nearbyErrorPairingUnavailable =>
      '데스크톱 설정에서 페어링 코드를 만든 다음 다시 연결하세요.';

  @override
  String get nearbyErrorPairingExpired => '데스크톱 페어링 코드가 만료되었어요. 새로 만드세요.';

  @override
  String get nearbyErrorWrongCode => '페어링 코드가 올바르지 않아요.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      '페어링 시도 횟수를 모두 사용했어요. 데스크톱에서 새 코드를 만드세요.';

  @override
  String get nearbyErrorDesktopBusy => '데스크톱이 이미 녹음하거나 오디오를 처리하는 중이에요.';

  @override
  String get nearbyErrorConnectFirst => '녹음하기 전에 데스크톱에 연결하세요.';

  @override
  String get nearbyErrorTimeout => '데스크톱이 제때 응답하지 않았어요.';

  @override
  String get nearbyErrorConnectionLost => '데스크톱과의 연결이 끊겼어요.';

  @override
  String get nearbyErrorMicDenied => '마이크 접근이 필요해요. 설정에서 허용하세요.';

  @override
  String get nearbyErrorRecorderNotReady => '마이크가 준비되지 않았어요. 다시 시도하세요.';

  @override
  String get nearbyErrorMicStream => '마이크가 예기치 않게 중지되었어요.';

  @override
  String get nearbyErrorDiscovery =>
      '로컬 네트워크를 검색하지 못했어요. Wi-Fi를 확인하고 다시 시도하세요.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      '데스크톱이 예상치 못한 응답을 보냈어요. 두 기기 모두 Shinsoku를 업데이트하고 다시 시도하세요.';

  @override
  String get nearbyErrorGeneric => '데스크톱 연결에 문제가 발생했어요.';
}
