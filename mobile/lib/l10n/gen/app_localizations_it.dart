// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonCopy => 'Copia';

  @override
  String get commonDone => 'Fine';

  @override
  String get commonClear => 'Cancella';

  @override
  String get commonUndo => 'Annulla';

  @override
  String get commonOpenSettings => 'Apri Impostazioni';

  @override
  String get tabRecord => 'Registra';

  @override
  String get tabDrafts => 'Bozze';

  @override
  String get tabDesktop => 'Computer';

  @override
  String get tabSettings => 'Impostazioni';

  @override
  String get paneSwitcherLabel => 'Pannello';

  @override
  String get recordPlaceholder => 'Tocca il microfono e inizia a parlare.';

  @override
  String get recordListeningPlaceholder => 'In ascolto…';

  @override
  String get recordProcessing => 'Elaborazione…';

  @override
  String get recordTranscriptLabel => 'Testo';

  @override
  String get recordCopied => 'Copiato. Inseriscilo dalla tastiera o incollalo.';

  @override
  String get recordSavedInsert => 'Salvato. Inseriscilo dalla tastiera.';

  @override
  String get recordResultCopied =>
      'Copiato. Incollalo dove vuoi o inseriscilo dalla tastiera.';

  @override
  String get recordStopped => 'Registrazione interrotta';

  @override
  String get recordHeardTextKept =>
      'Quello che è stato sentito resta qui e nelle Bozze.';

  @override
  String get recordTryAgain => 'Registra di nuovo';

  @override
  String get recordStatusReady => 'Pronto a registrare';

  @override
  String get recordStatusListening => 'In ascolto';

  @override
  String get recordStatusListeningDetail =>
      'Tocca Stop quando hai finito di parlare.';

  @override
  String get recordStatusTranscribing => 'Trascrizione in corso';

  @override
  String get recordTranscribed => 'Registrazione trascritta';

  @override
  String get recordTranscribingDetail =>
      'Invio dell’audio registrato al servizio selezionato.';

  @override
  String get recordFailed => 'Registrazione non riuscita';

  @override
  String get recordMicOffLabel => 'L’accesso al microfono è disattivato';

  @override
  String get recordMicOffDetail =>
      'Consenti l’accesso al microfono nelle Impostazioni di iOS, poi registra di nuovo.';

  @override
  String get recordRecorderNotReady =>
      'L’accesso al microfono è consentito, ma il registratore non è pronto. Riprova.';

  @override
  String get recordKeyRequiredLabel => 'Configura il servizio';

  @override
  String get recordKeyRequiredDetail =>
      'Salva una chiave API di Bailian o Soniox prima di registrare.';

  @override
  String get recordProfileLabel => 'Profilo';

  @override
  String get recordButtonStart => 'Avvia registrazione';

  @override
  String get recordButtonStop => 'Interrompi registrazione';

  @override
  String get recordButtonUnavailable => 'Registrazione non disponibile';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => 'scelto da te';

  @override
  String get profileReasonAutomation => 'impostato da un’automazione';

  @override
  String get profileReasonDefault => 'predefinito';

  @override
  String get draftsTitle => 'Bozze';

  @override
  String get draftsEmpty =>
      'I tuoi testi appariranno qui dopo una registrazione.';

  @override
  String get draftsToday => 'Oggi';

  @override
  String get draftsYesterday => 'Ieri';

  @override
  String get draftsCopyDraft => 'Copia bozza';

  @override
  String get draftsDeleted => 'Bozza eliminata';

  @override
  String get draftsCopied => 'Bozza copiata negli appunti.';

  @override
  String get draftEditorTitle => 'Bozza';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsSectionRecognition => 'Riconoscimento';

  @override
  String get settingsMicrophoneTitle => 'Accesso al microfono';

  @override
  String get settingsMicrophoneAllowed => 'Consentito per l’input vocale';

  @override
  String get settingsMicrophoneTapToAllow =>
      'Tocca per consentire l’accesso al microfono';

  @override
  String get settingsSpeechProvider => 'Servizio vocale';

  @override
  String get settingsPostProcessingTitle => 'Post-elaborazione del testo';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return 'Usa $model per ripulire o tradurre';
  }

  @override
  String get settingsCloudTitle => 'Elaborazione nel cloud';

  @override
  String get settingsCloudSaved => 'Le credenziali del servizio sono salvate';

  @override
  String get settingsCloudNotSaved =>
      'Salva le credenziali prima di trascrivere davvero';

  @override
  String get settingsLoading => 'Caricamento delle impostazioni salvate';

  @override
  String get settingsRealtimeModel => 'Modello in tempo reale';

  @override
  String get settingsRecognitionMode => 'Modalità di riconoscimento';

  @override
  String get settingsModeStreaming => 'Streaming';

  @override
  String get settingsStreamingModel => 'Modello ASR in streaming';

  @override
  String get settingsBatchModel => 'Modello batch Qwen-ASR';

  @override
  String get settingsPostProcessingModel =>
      'Modello OpenAI per la post-elaborazione';

  @override
  String get settingsPostProcessingModelHelper =>
      'Usato solo con la post-elaborazione del testo attiva';

  @override
  String get settingsBaseUrl => 'URL di base compatibile con OpenAI';

  @override
  String get settingsRealtimeUrl => 'URL WebSocket in tempo reale';

  @override
  String get settingsSave => 'Salva impostazioni';

  @override
  String get settingsSaving => 'Salvataggio';

  @override
  String get settingsSaved => 'Impostazioni del servizio salvate';

  @override
  String settingsSaveFailed(String reason) {
    return 'Le impostazioni non sono state salvate. $reason';
  }

  @override
  String get settingsSectionProfiles => 'Profili';

  @override
  String get settingsAddProfile => 'Aggiungi profilo';

  @override
  String get settingsUseInApps => 'Usa nelle app';

  @override
  String get settingsUseInAppsSubtitle => 'Cambia profilo quando apri un’app';

  @override
  String get settingsFieldRules => 'Regole dei campi';

  @override
  String get settingsFieldRulesSubtitle =>
      'Ricerca, indirizzo web, email, messaggio';

  @override
  String get settingsSectionKeyboard => 'Tastiera';

  @override
  String get settingsKeyboardSetup => 'Configura la tastiera';

  @override
  String get settingsKeyboardSetupSubtitle =>
      'Aggiungi Shinsoku e consenti l’accesso completo';

  @override
  String get settingsApiKey => 'Chiave API';

  @override
  String get settingsShowKey => 'Mostra chiave';

  @override
  String get settingsHideKey => 'Nascondi chiave';

  @override
  String get keyboardSetupTitle => 'Tastiera';

  @override
  String get keyboardSetupIntro => 'Usa Shinsoku in qualsiasi campo di testo.';

  @override
  String get keyboardStep1 =>
      'Apri Impostazioni › Generali › Tastiera › Tastiere.';

  @override
  String get keyboardStep2 =>
      'Tocca “Aggiungi nuova tastiera” e scegli Shinsoku.';

  @override
  String get keyboardStep3 =>
      'Tocca Shinsoku e attiva “Consenti accesso completo”, così la tastiera può inserire il tuo testo più recente.';

  @override
  String get useInAppsSummary =>
      'Shinsoku può cambiare profilo da solo quando apri un’app. Comandi Rapidi rileva l’app, Shinsoku imposta il profilo.';

  @override
  String get useInAppsWhenOpened => 'Quando l’app viene aperta';

  @override
  String get useInAppsWhenClosed => 'Quando l’app viene chiusa';

  @override
  String get useInAppsOpenStep1 =>
      'In Comandi Rapidi, apri Automazione e tocca “Nuova automazione”.';

  @override
  String get useInAppsOpenStep2 =>
      'Scegli “App”, seleziona l’app e poi “Viene aperta”. Attiva “Esegui immediatamente”.';

  @override
  String get useInAppsOpenStep3 =>
      'Aggiungi l’azione “Imposta profilo di Shinsoku” e scegli il profilo per quell’app.';

  @override
  String get useInAppsCloseStep1 =>
      'Aggiungi una seconda automazione per la stessa app con “Viene chiusa”. Attiva “Esegui immediatamente”.';

  @override
  String get useInAppsCloseStep2 =>
      'Aggiungi “Imposta profilo di Shinsoku” e scegli il tuo profilo predefinito, così le altre app tornano a quello.';

  @override
  String get useInAppsKeyboardNote =>
      'Puoi anche toccare il nome del profilo nella tastiera per cambiarlo. Resta attivo finché non parte di nuovo un’automazione.';

  @override
  String get useInAppsReadyMade =>
      'Ogni profilo ha anche un’azione pronta nell’app Comandi Rapidi, come “Passa Shinsoku a Chat”. Nessuna configurazione necessaria.';

  @override
  String get useInAppsIosNote =>
      'Le azioni di Comandi Rapidi richiedono iOS 16 o versioni successive.';

  @override
  String get useInAppsOpenShortcuts => 'Apri Comandi Rapidi';

  @override
  String get fieldRulesTitle => 'Regole dei campi';

  @override
  String get fieldRulesSummary =>
      'Usa un profilo automaticamente in certi tipi di campo. Vale solo se non hai scelto un profilo nella tastiera e nessuna automazione ne ha impostato uno.';

  @override
  String get fieldRulesNone => 'Nessuno';

  @override
  String get fieldKindSearch => 'Ricerca';

  @override
  String get fieldKindUrl => 'Indirizzo web';

  @override
  String get fieldKindEmail => 'Email';

  @override
  String get fieldKindMessage => 'Messaggio';

  @override
  String get profileNewTitle => 'Nuovo profilo';

  @override
  String get profileEditTitle => 'Modifica profilo';

  @override
  String get profileNameLabel => 'Nome';

  @override
  String get profilePromptLabel => 'Istruzione di post-elaborazione';

  @override
  String get profilePromptHelper =>
      'Esempio: Traduci l’italiano parlato in un inglese naturale.';

  @override
  String get profileAfterText => 'Dopo il testo';

  @override
  String get profileSuffixNothing => 'Niente';

  @override
  String get profileSuffixSpace => 'Spazio';

  @override
  String get profileSuffixNewLine => 'A capo';

  @override
  String get profileAutoCommit => 'Inserimento automatico';

  @override
  String get profileAutoCommitSubtitle => 'Inserisci senza revisione';

  @override
  String get profileDelete => 'Elimina profilo';

  @override
  String profileDeleteConfirm(String name) {
    return 'Eliminare “$name”?';
  }

  @override
  String get profileKeepOne => 'Deve restare almeno un profilo';

  @override
  String get profileUntitled => 'Senza titolo';

  @override
  String get profileDefaultIntent =>
      'Ripulisci la trascrizione. Restituisci solo il testo finale.';

  @override
  String get profileDictationName => 'Dettatura';

  @override
  String get profileDictationIntent =>
      'Trasformare il parlato in un testo scorrevole';

  @override
  String get profileChatName => 'Chat';

  @override
  String get profileChatIntent => 'Rendere il testo breve e colloquiale';

  @override
  String get profileReviewName => 'Revisione';

  @override
  String get profileReviewIntent => 'Tenere il testo per una revisione manuale';

  @override
  String get profileZhToEnName => 'ZH → EN';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => 'Traduci → EN';

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
  String get shellAlreadyRecording => 'Shinsoku sta già registrando.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return 'Post-elaborazione del testo attivata per $profile.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return 'L’impostazione di post-elaborazione non è stata salvata. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'Impossibile copiare il testo. $reason';
  }

  @override
  String get failureTimeout =>
      'Il servizio ha impiegato troppo a rispondere. Controlla la connessione e riprova.';

  @override
  String get failureNetwork =>
      'Nessuna connessione al servizio. Controlla la rete e riprova.';

  @override
  String get failureConnectionLost =>
      'La connessione si è interrotta. Riprova.';

  @override
  String get failureKeyMissing =>
      'Nessuna chiave API salvata. Aggiungine una in Impostazioni.';

  @override
  String get failureKeyInvalid =>
      'Il servizio non ha accettato la tua chiave API. Controllala in Impostazioni.';

  @override
  String get failureQuota =>
      'Il servizio segnala quota esaurita o troppe richieste. Controlla il tuo account.';

  @override
  String get failureNothingHeard => 'Nessun parlato riconosciuto. Riprova.';

  @override
  String get failureRecording =>
      'Impossibile completare la registrazione. Riprova.';

  @override
  String get failureMicrophone =>
      'Il microfono non è disponibile. Controlla l’accesso al microfono in Impostazioni.';

  @override
  String get failureGeneric => 'Si è verificato un problema. Riprova.';

  @override
  String get nearbyTitle => 'Microfono per computer';

  @override
  String get nearbySubtitle => 'Connessione locale privata';

  @override
  String get nearbySectionDesktop => 'Computer';

  @override
  String get nearbyFindDesktops => 'Cerca computer';

  @override
  String get nearbyAddManually => 'Aggiungi computer manualmente';

  @override
  String get nearbyEndpointLabel => 'Indirizzo WSS';

  @override
  String get nearbyCertificateLabel => 'SHA-256 del certificato';

  @override
  String get nearbyAdd => 'Aggiungi';

  @override
  String get nearbySectionTrust => 'Attendibilità';

  @override
  String get nearbyTrustedDesktop => 'Computer attendibile';

  @override
  String get nearbyCertificateFingerprint => 'Impronta del certificato';

  @override
  String get nearbyMatchesTitle => 'Uguale a quella del computer';

  @override
  String get nearbyMatchesSubtitle =>
      'Confrontala con le impostazioni del computer';

  @override
  String get nearbyPairingCodeLabel =>
      'Codice di abbinamento mostrato sul computer';

  @override
  String get nearbyDisconnect => 'Disconnetti';

  @override
  String get nearbyConnect => 'Connetti';

  @override
  String get nearbyPairAndConnect => 'Abbina e connetti';

  @override
  String get nearbyForget => 'Dimentica computer';

  @override
  String get nearbySectionRemoteInput => 'Input remoto';

  @override
  String get nearbyProfileRow => 'Profilo';

  @override
  String get nearbyProfileAutomatic => 'Automatico (computer)';

  @override
  String get nearbyProfileSheetTitle => 'Profilo del computer';

  @override
  String get nearbyStopAndTranscribe => 'Interrompi e trascrivi';

  @override
  String get nearbyStartRemote => 'Avvia dettatura remota';

  @override
  String get nearbyConnectToDictate =>
      'Connettiti a un computer per dettare su di esso';

  @override
  String nearbyConnectingTo(String name) {
    return 'Connessione a $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return 'Connesso a $name';
  }

  @override
  String get nearbyStreaming => 'Invio dell’audio del microfono';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Invio con $countString frame mancanti',
      one: 'Invio con 1 frame mancante',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => 'Registrazione inviata al computer';

  @override
  String get nearbyNotConnected => 'Non connesso';

  @override
  String get nearbyDisconnected => 'Computer disconnesso';

  @override
  String get nearbySearching => 'Ricerca nella rete locale';

  @override
  String get nearbyNoneFound => 'Nessun computer Shinsoku trovato';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString computer trovati',
      one: '1 computer trovato',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => 'Computer attendibile selezionato';

  @override
  String get nearbyVerifyFingerprint => 'Verifica l’impronta del computer';

  @override
  String get nearbyTrustRemoved => 'Attendibilità locale rimossa';

  @override
  String get nearbyErrorPairingCodeRequired =>
      'Inserisci il codice a due cifre mostrato sul computer.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      'L’impronta del certificato non è valida. Inserisci tutti i 64 caratteri esadecimali.';

  @override
  String get nearbyErrorEndpointInvalid =>
      'Inserisci un host e una porta wss:// validi.';

  @override
  String get nearbyErrorCertificateChanged =>
      'Il certificato del computer è cambiato. Dimenticalo e abbinalo di nuovo.';

  @override
  String get nearbyErrorCredentialMissing =>
      'Il computer ricorda questo dispositivo, ma manca la credenziale locale. Revocala sul computer e abbina di nuovo.';

  @override
  String get nearbyErrorPairingUnavailable =>
      'Crea un codice di abbinamento nelle impostazioni del computer, poi connettiti di nuovo.';

  @override
  String get nearbyErrorPairingExpired =>
      'Il codice di abbinamento è scaduto. Creane uno nuovo.';

  @override
  String get nearbyErrorWrongCode => 'Il codice di abbinamento non è corretto.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'Tentativi di abbinamento esauriti. Crea un nuovo codice sul computer.';

  @override
  String get nearbyErrorDesktopBusy =>
      'Il computer sta già registrando o elaborando audio.';

  @override
  String get nearbyErrorConnectFirst =>
      'Connettiti a un computer prima di registrare.';

  @override
  String get nearbyErrorTimeout => 'Il computer non ha risposto in tempo.';

  @override
  String get nearbyErrorConnectionLost =>
      'La connessione al computer si è interrotta.';

  @override
  String get nearbyErrorMicDenied =>
      'Serve l’accesso al microfono. Consentilo in Impostazioni.';

  @override
  String get nearbyErrorRecorderNotReady =>
      'Il microfono non è pronto. Riprova.';

  @override
  String get nearbyErrorMicStream =>
      'Il microfono si è fermato inaspettatamente.';

  @override
  String get nearbyErrorDiscovery =>
      'Impossibile cercare nella rete locale. Controlla il Wi-Fi e riprova.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'Il computer ha inviato una risposta inattesa. Aggiorna Shinsoku su entrambi i dispositivi e riprova.';

  @override
  String get nearbyErrorGeneric =>
      'Si è verificato un problema con la connessione al computer.';
}
