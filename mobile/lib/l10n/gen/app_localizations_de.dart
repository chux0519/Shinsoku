// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Sichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonClear => 'Leeren';

  @override
  String get commonUndo => 'Widerrufen';

  @override
  String get commonOpenSettings => 'Einstellungen öffnen';

  @override
  String get tabRecord => 'Aufnahme';

  @override
  String get tabDrafts => 'Entwürfe';

  @override
  String get tabDesktop => 'Computer';

  @override
  String get tabSettings => 'Einstellungen';

  @override
  String get paneSwitcherLabel => 'Bereich';

  @override
  String get recordPlaceholder => 'Tippe auf das Mikrofon und sprich los.';

  @override
  String get recordListeningPlaceholder => 'Hört zu …';

  @override
  String get recordProcessing => 'Wird verarbeitet …';

  @override
  String get recordTranscriptLabel => 'Text';

  @override
  String get recordCopied =>
      'Kopiert. Füge ihn über die Tastatur ein oder setze ihn ein.';

  @override
  String get recordSavedInsert => 'Gesichert. Füge ihn über die Tastatur ein.';

  @override
  String get recordResultCopied =>
      'Kopiert. Setze ihn irgendwo ein oder füge ihn über die Tastatur ein.';

  @override
  String get recordStopped => 'Aufnahme beendet';

  @override
  String get recordHeardTextKept =>
      'Was erkannt wurde, bleibt hier und in den Entwürfen erhalten.';

  @override
  String get recordTryAgain => 'Erneut aufnehmen';

  @override
  String get recordStatusReady => 'Bereit zur Aufnahme';

  @override
  String get recordStatusListening => 'Hört zu';

  @override
  String get recordStatusListeningDetail =>
      'Tippe auf Stopp, wenn du fertig bist.';

  @override
  String get recordStatusTranscribing => 'Wird transkribiert';

  @override
  String get recordTranscribed => 'Aufnahme transkribiert';

  @override
  String get recordTranscribingDetail =>
      'Die Aufnahme wird zum gewählten Dienst hochgeladen.';

  @override
  String get recordFailed => 'Aufnahme fehlgeschlagen';

  @override
  String get recordMicOffLabel => 'Mikrofonzugriff ist aus';

  @override
  String get recordMicOffDetail =>
      'Erlaube den Mikrofonzugriff in den iOS-Einstellungen und nimm dann erneut auf.';

  @override
  String get recordRecorderNotReady =>
      'Der Mikrofonzugriff ist erlaubt, aber die Aufnahme ist noch nicht bereit. Versuche es erneut.';

  @override
  String get recordKeyRequiredLabel => 'Dienst muss eingerichtet werden';

  @override
  String get recordKeyRequiredDetail =>
      'Sichere vor der Aufnahme einen API-Schlüssel für Bailian oder Soniox.';

  @override
  String get recordProfileLabel => 'Profil';

  @override
  String get recordButtonStart => 'Aufnahme starten';

  @override
  String get recordButtonStop => 'Aufnahme stoppen';

  @override
  String get recordButtonUnavailable => 'Aufnahme nicht verfügbar';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => 'von dir gewählt';

  @override
  String get profileReasonAutomation => 'per Automation';

  @override
  String get profileReasonDefault => 'Standard';

  @override
  String get draftsTitle => 'Entwürfe';

  @override
  String get draftsEmpty =>
      'Deine Texte erscheinen hier, sobald du etwas aufnimmst.';

  @override
  String get draftsToday => 'Heute';

  @override
  String get draftsYesterday => 'Gestern';

  @override
  String get draftsCopyDraft => 'Entwurf kopieren';

  @override
  String get draftsDeleted => 'Entwurf gelöscht';

  @override
  String get draftsCopied => 'Entwurf in die Zwischenablage kopiert.';

  @override
  String get draftEditorTitle => 'Entwurf';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionRecognition => 'Spracherkennung';

  @override
  String get settingsMicrophoneTitle => 'Mikrofonzugriff';

  @override
  String get settingsMicrophoneAllowed => 'Für Spracheingabe erlaubt';

  @override
  String get settingsMicrophoneTapToAllow =>
      'Tippen, um den Mikrofonzugriff zu erlauben';

  @override
  String get settingsSpeechProvider => 'Spracherkennungsdienst';

  @override
  String get settingsPostProcessingTitle => 'Text-Nachbearbeitung';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return '$model zum Bereinigen oder Übersetzen verwenden';
  }

  @override
  String get settingsCloudTitle => 'Cloud-Verarbeitung';

  @override
  String get settingsCloudSaved => 'Zugangsdaten des Dienstes sind gesichert';

  @override
  String get settingsCloudNotSaved =>
      'Sichere Zugangsdaten, bevor du echt transkribierst';

  @override
  String get settingsLoading => 'Gesicherte Einstellungen werden geladen';

  @override
  String get settingsRealtimeModel => 'Echtzeitmodell';

  @override
  String get settingsRecognitionMode => 'Erkennungsmodus';

  @override
  String get settingsModeStreaming => 'Streaming';

  @override
  String get settingsStreamingModel => 'Streaming-ASR-Modell';

  @override
  String get settingsBatchModel => 'Qwen-ASR-Batchmodell';

  @override
  String get settingsPostProcessingModel => 'OpenAI-Modell für Nachbearbeitung';

  @override
  String get settingsPostProcessingModelHelper =>
      'Nur bei aktiver Text-Nachbearbeitung verwendet';

  @override
  String get settingsBaseUrl => 'OpenAI-kompatible Basis-URL';

  @override
  String get settingsRealtimeUrl => 'Echtzeit-WebSocket-URL';

  @override
  String get settingsSave => 'Einstellungen sichern';

  @override
  String get settingsSaving => 'Wird gesichert';

  @override
  String get settingsSaved => 'Diensteinstellungen gesichert';

  @override
  String settingsSaveFailed(String reason) {
    return 'Einstellungen wurden nicht gesichert. $reason';
  }

  @override
  String get settingsSectionProfiles => 'Profile';

  @override
  String get settingsAddProfile => 'Profil hinzufügen';

  @override
  String get settingsUseInApps => 'In Apps verwenden';

  @override
  String get settingsUseInAppsSubtitle =>
      'Profil beim Öffnen einer App wechseln';

  @override
  String get settingsFieldRules => 'Feldregeln';

  @override
  String get settingsFieldRulesSubtitle =>
      'Suche, Webadresse, E-Mail, Nachricht';

  @override
  String get settingsSectionKeyboard => 'Tastatur';

  @override
  String get settingsKeyboardSetup => 'Tastatur einrichten';

  @override
  String get settingsKeyboardSetupSubtitle =>
      'Shinsoku hinzufügen und vollen Zugriff erlauben';

  @override
  String get settingsApiKey => 'API-Schlüssel';

  @override
  String get settingsShowKey => 'Schlüssel einblenden';

  @override
  String get settingsHideKey => 'Schlüssel ausblenden';

  @override
  String get keyboardSetupTitle => 'Tastatur';

  @override
  String get keyboardSetupIntro => 'Nutze Shinsoku in jedem Textfeld.';

  @override
  String get keyboardStep1 =>
      'Öffne „Einstellungen“ › „Allgemein“ › „Tastatur“ › „Tastaturen“.';

  @override
  String get keyboardStep2 =>
      'Tippe auf „Tastatur hinzufügen“ und wähle Shinsoku.';

  @override
  String get keyboardStep3 =>
      'Tippe auf Shinsoku und aktiviere „Vollen Zugriff erlauben“, damit die Tastatur deinen neuesten Text einfügen kann.';

  @override
  String get useInAppsSummary =>
      'Shinsoku kann das Profil selbst wechseln, wenn du eine App öffnest. Kurzbefehle erkennt die App, Shinsoku setzt das Profil.';

  @override
  String get useInAppsWhenOpened => 'Wenn die App geöffnet wird';

  @override
  String get useInAppsWhenClosed => 'Wenn die App geschlossen wird';

  @override
  String get useInAppsOpenStep1 =>
      'Öffne in Kurzbefehle „Automation“ und tippe auf „Neue Automation“.';

  @override
  String get useInAppsOpenStep2 =>
      'Wähle „App“, dann die App und „Wird geöffnet“. Aktiviere „Sofort ausführen“.';

  @override
  String get useInAppsOpenStep3 =>
      'Füge die Aktion „Shinsoku-Profil festlegen“ hinzu und wähle das Profil für diese App.';

  @override
  String get useInAppsCloseStep1 =>
      'Füge für dieselbe App eine zweite Automation mit „Wird geschlossen“ hinzu. Aktiviere „Sofort ausführen“.';

  @override
  String get useInAppsCloseStep2 =>
      'Füge „Shinsoku-Profil festlegen“ hinzu und wähle dein Standardprofil, damit andere Apps wieder dazu zurückkehren.';

  @override
  String get useInAppsKeyboardNote =>
      'Du kannst auch in der Tastatur auf den Profilnamen tippen, um zu wechseln. Das bleibt, bis wieder eine Automation läuft.';

  @override
  String get useInAppsReadyMade =>
      'Jedes Profil hat außerdem eine fertige Aktion in der App „Kurzbefehle“, zum Beispiel „Shinsoku auf Chat umstellen“. Keine Einrichtung nötig.';

  @override
  String get useInAppsIosNote =>
      'Die Kurzbefehle-Aktionen benötigen iOS 16 oder neuer.';

  @override
  String get useInAppsOpenShortcuts => 'Kurzbefehle öffnen';

  @override
  String get fieldRulesTitle => 'Feldregeln';

  @override
  String get fieldRulesSummary =>
      'Ein Profil automatisch in bestimmten Feldarten verwenden. Gilt nur, wenn du in der Tastatur kein Profil gewählt und keine Automation eines gesetzt hat.';

  @override
  String get fieldRulesNone => 'Keine';

  @override
  String get fieldKindSearch => 'Suche';

  @override
  String get fieldKindUrl => 'Webadresse';

  @override
  String get fieldKindEmail => 'E-Mail';

  @override
  String get fieldKindMessage => 'Nachricht';

  @override
  String get profileNewTitle => 'Neues Profil';

  @override
  String get profileEditTitle => 'Profil bearbeiten';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profilePromptLabel => 'Prompt für die Nachbearbeitung';

  @override
  String get profilePromptHelper =>
      'Beispiel: Übersetze deutsche Sprache in natürliches Englisch.';

  @override
  String get profileAfterText => 'Nach dem Text';

  @override
  String get profileSuffixNothing => 'Nichts';

  @override
  String get profileSuffixSpace => 'Leerzeichen';

  @override
  String get profileSuffixNewLine => 'Neue Zeile';

  @override
  String get profileAutoCommit => 'Automatisch einfügen';

  @override
  String get profileAutoCommitSubtitle => 'Ohne Prüfschritt einfügen';

  @override
  String get profileDelete => 'Profil löschen';

  @override
  String profileDeleteConfirm(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get profileKeepOne => 'Mindestens ein Profil muss bleiben';

  @override
  String get profileUntitled => 'Ohne Titel';

  @override
  String get profileDefaultIntent =>
      'Bereinige das Transkript. Gib nur den fertigen Text zurück.';

  @override
  String get profileDictationName => 'Diktat';

  @override
  String get profileDictationIntent =>
      'Gesprochenes in natürlichen Fließtext bringen';

  @override
  String get profileChatName => 'Chat';

  @override
  String get profileChatIntent => 'Text knapp und locker formulieren';

  @override
  String get profileReviewName => 'Prüfen';

  @override
  String get profileReviewIntent => 'Text zur manuellen Prüfung zurückhalten';

  @override
  String get profileZhToEnName => 'ZH → EN';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => 'Übersetzen → EN';

  @override
  String get profileTranslateToEnIntent =>
      'Translate the speech into natural English, whatever language it is in. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileJaToEnName => 'JA → EN';

  @override
  String get profileJaToEnIntent =>
      'Translate Japanese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileKoToEnName => 'KO → EN';

  @override
  String get profileKoToEnIntent =>
      'Translate Korean speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileDeToEnName => 'DE → EN';

  @override
  String get profileDeToEnIntent =>
      'Translate German speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileEsToEnName => 'ES → EN';

  @override
  String get profileEsToEnIntent =>
      'Translate Spanish speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileFrToEnName => 'FR → EN';

  @override
  String get profileFrToEnIntent =>
      'Translate French speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profilePtToEnName => 'PT → EN';

  @override
  String get profilePtToEnIntent =>
      'Translate Portuguese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileItToEnName => 'IT → EN';

  @override
  String get profileItToEnIntent =>
      'Translate Italian speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get shellAlreadyRecording => 'Shinsoku nimmt bereits auf.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return 'Text-Nachbearbeitung für $profile aktiviert.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return 'Die Nachbearbeitung wurde nicht gesichert. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'Der Text konnte nicht kopiert werden. $reason';
  }

  @override
  String get failureTimeout =>
      'Der Dienst hat zu lange gebraucht. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get failureNetwork =>
      'Keine Verbindung zum Dienst. Prüfe dein Netzwerk und versuche es erneut.';

  @override
  String get failureConnectionLost =>
      'Die Verbindung wurde unterbrochen. Versuche es erneut.';

  @override
  String get failureKeyMissing =>
      'Kein API-Schlüssel gesichert. Füge einen in den Einstellungen hinzu.';

  @override
  String get failureKeyInvalid =>
      'Der Dienst hat deinen API-Schlüssel nicht akzeptiert. Prüfe ihn in den Einstellungen.';

  @override
  String get failureQuota =>
      'Der Dienst meldet kein Kontingent mehr oder zu viele Anfragen. Prüfe dein Konto.';

  @override
  String get failureNothingHeard =>
      'Es wurde keine Sprache erkannt. Versuche es erneut.';

  @override
  String get failureRecording =>
      'Die Aufnahme konnte nicht abgeschlossen werden. Versuche es erneut.';

  @override
  String get failureMicrophone =>
      'Das Mikrofon ist nicht verfügbar. Prüfe den Mikrofonzugriff in den Einstellungen.';

  @override
  String get failureGeneric => 'Etwas ist schiefgelaufen. Versuche es erneut.';

  @override
  String get nearbyTitle => 'Computer-Mikro';

  @override
  String get nearbySubtitle => 'Private lokale Verbindung';

  @override
  String get nearbySectionDesktop => 'Computer';

  @override
  String get nearbyFindDesktops => 'Computer suchen';

  @override
  String get nearbyAddManually => 'Computer manuell hinzufügen';

  @override
  String get nearbyEndpointLabel => 'WSS-Endpunkt';

  @override
  String get nearbyCertificateLabel => 'Zertifikat SHA-256';

  @override
  String get nearbyAdd => 'Hinzufügen';

  @override
  String get nearbySectionTrust => 'Vertrauen';

  @override
  String get nearbyTrustedDesktop => 'Vertrauenswürdiger Computer';

  @override
  String get nearbyCertificateFingerprint => 'Zertifikat-Fingerabdruck';

  @override
  String get nearbyMatchesTitle => 'Stimmt mit dem Computer überein';

  @override
  String get nearbyMatchesSubtitle =>
      'Vergleiche ihn mit den Einstellungen auf dem Computer';

  @override
  String get nearbyPairingCodeLabel => 'Kopplungscode auf dem Computer';

  @override
  String get nearbyDisconnect => 'Trennen';

  @override
  String get nearbyConnect => 'Verbinden';

  @override
  String get nearbyPairAndConnect => 'Koppeln und verbinden';

  @override
  String get nearbyForget => 'Computer vergessen';

  @override
  String get nearbySectionRemoteInput => 'Ferneingabe';

  @override
  String get nearbyProfileRow => 'Profil';

  @override
  String get nearbyProfileAutomatic => 'Automatisch (Computer)';

  @override
  String get nearbyProfileSheetTitle => 'Computer-Profil';

  @override
  String get nearbyStopAndTranscribe => 'Stoppen und transkribieren';

  @override
  String get nearbyStartRemote => 'Ferndiktat starten';

  @override
  String get nearbyConnectToDictate =>
      'Verbinde dich mit einem Computer, um darauf zu diktieren';

  @override
  String nearbyConnectingTo(String name) {
    return 'Verbinden mit $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return 'Verbunden mit $name';
  }

  @override
  String get nearbyStreaming => 'Mikrofonton wird gestreamt';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Streaming mit $countString fehlenden Frames',
      one: 'Streaming mit 1 fehlenden Frame',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => 'Aufnahme an den Computer gesendet';

  @override
  String get nearbyNotConnected => 'Nicht verbunden';

  @override
  String get nearbyDisconnected => 'Computer getrennt';

  @override
  String get nearbySearching => 'Lokales Netzwerk wird durchsucht';

  @override
  String get nearbyNoneFound => 'Kein Shinsoku-Computer gefunden';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Computer gefunden',
      one: '1 Computer gefunden',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => 'Vertrauenswürdiger Computer ausgewählt';

  @override
  String get nearbyVerifyFingerprint => 'Prüfe den Fingerabdruck des Computers';

  @override
  String get nearbyTrustRemoved => 'Lokales Vertrauen entfernt';

  @override
  String get nearbyErrorPairingCodeRequired =>
      'Gib den zweistelligen Code vom Computer ein.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      'Der Zertifikat-Fingerabdruck ist ungültig. Gib alle 64 Hexadezimalzeichen ein.';

  @override
  String get nearbyErrorEndpointInvalid =>
      'Gib einen gültigen wss://-Host und Port ein.';

  @override
  String get nearbyErrorCertificateChanged =>
      'Das Zertifikat des Computers hat sich geändert. Vergiss ihn und kopple erneut.';

  @override
  String get nearbyErrorCredentialMissing =>
      'Der Computer kennt dieses Gerät, aber die lokalen Zugangsdaten fehlen. Widerrufe es auf dem Computer und kopple erneut.';

  @override
  String get nearbyErrorPairingUnavailable =>
      'Erstelle in den Einstellungen des Computers einen Kopplungscode und verbinde dich dann erneut.';

  @override
  String get nearbyErrorPairingExpired =>
      'Der Kopplungscode ist abgelaufen. Erstelle einen neuen.';

  @override
  String get nearbyErrorWrongCode => 'Der Kopplungscode ist falsch.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'Keine Kopplungsversuche mehr übrig. Erstelle auf dem Computer einen neuen Code.';

  @override
  String get nearbyErrorDesktopBusy =>
      'Der Computer nimmt bereits auf oder verarbeitet Audio.';

  @override
  String get nearbyErrorConnectFirst =>
      'Verbinde dich vor der Aufnahme mit einem Computer.';

  @override
  String get nearbyErrorTimeout =>
      'Der Computer hat nicht rechtzeitig geantwortet.';

  @override
  String get nearbyErrorConnectionLost =>
      'Die Verbindung zum Computer wurde unterbrochen.';

  @override
  String get nearbyErrorMicDenied =>
      'Mikrofonzugriff wird benötigt. Erlaube ihn in den Einstellungen.';

  @override
  String get nearbyErrorRecorderNotReady =>
      'Das Mikrofon ist nicht bereit. Versuche es erneut.';

  @override
  String get nearbyErrorMicStream => 'Das Mikrofon wurde unerwartet beendet.';

  @override
  String get nearbyErrorDiscovery =>
      'Das lokale Netzwerk konnte nicht durchsucht werden. Prüfe das WLAN und versuche es erneut.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'Der Computer hat unerwartet geantwortet. Aktualisiere Shinsoku auf beiden Geräten und versuche es erneut.';

  @override
  String get nearbyErrorGeneric =>
      'Bei der Verbindung zum Computer ist etwas schiefgelaufen.';

  @override
  String get proName => 'Shinsoku Pro';

  @override
  String get proBadge => 'Pro';

  @override
  String get proFeatureProfilesTitle => 'Eigene Profile';

  @override
  String get proFeatureProfilesBody =>
      'Erstelle eigene Profile und bearbeite Prompt und Einstellungen jedes Profils.';

  @override
  String get proFeatureAutoTitle => 'Automatisch je App wechseln';

  @override
  String get proFeatureAutoBody =>
      'Feldregeln und Kurzbefehle wählen das Profil für die App, in der du gerade schreibst.';

  @override
  String get proFeatureDesktopTitle => 'Computer';

  @override
  String get proFeatureDesktopBody =>
      'Nutze dieses iPhone als Mikrofon für Shinsoku auf deinem Computer.';

  @override
  String get proNote => 'Einmaliger Kauf. Mit Familienfreigabe.';

  @override
  String proBuyWithPrice(String price) {
    return 'Für $price freischalten';
  }

  @override
  String get proBuy => 'Shinsoku Pro freischalten';

  @override
  String get proPriceLoading => 'Preis wird geladen …';

  @override
  String get proRestore => 'Käufe wiederherstellen';

  @override
  String get proOwned => 'Shinsoku Pro ist freigeschaltet. Danke!';

  @override
  String get proStatusUnlocked => 'Freigeschaltet';

  @override
  String get proSettingsSubtitle => 'Eigene Profile, Wechsel je App, Computer';

  @override
  String get proNoticePending =>
      'Warten auf Bestätigung. Pro wird freigeschaltet, sobald der Kauf bestätigt ist.';

  @override
  String get proNoticeCancelled =>
      'Kauf abgebrochen. Es wurde nichts berechnet.';

  @override
  String get proNoticeFailed =>
      'Der Kauf ist nicht durchgegangen. Bitte versuche es erneut.';

  @override
  String get proNoticeUnavailable =>
      'Der App Store ist gerade nicht verfügbar. Versuche es später erneut.';

  @override
  String get proNoticeRestored =>
      'Kauf wiederhergestellt. Shinsoku Pro ist freigeschaltet.';

  @override
  String get proNoticeNothingToRestore =>
      'Für diesen Apple Account wurde kein früherer Kauf von Shinsoku Pro gefunden.';

  @override
  String get proLockedProfileEditor =>
      'Zum Bearbeiten von Profilen brauchst du Shinsoku Pro. Auf dem Aufnahme-Bildschirm und in der Tastatur kannst du dieses Profil weiterhin wählen.';

  @override
  String get proLockedFieldRules =>
      'Feldregeln brauchen Shinsoku Pro. Deine Regeln bleiben erhalten und gelten wieder, sobald Pro freigeschaltet ist.';

  @override
  String get proLockedUseInApps =>
      'Zum Wechseln von Profilen über Kurzbefehle brauchst du Shinsoku Pro.';

  @override
  String get proLockedDesktop =>
      'Nutze dieses iPhone als drahtloses Mikrofon für Shinsoku auf deinem Mac oder PC: Du sprichst hier, der Text landet auf dem Computer. Computer gehört zu Shinsoku Pro.';

  @override
  String get proUnlockShort => 'Pro holen';
}
