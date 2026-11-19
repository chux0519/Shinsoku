// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonBack => 'Retour';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonDone => 'OK';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonUndo => 'Annuler';

  @override
  String get commonOpenSettings => 'Ouvrir Réglages';

  @override
  String get tabRecord => 'Dicter';

  @override
  String get tabDrafts => 'Brouillons';

  @override
  String get tabDesktop => 'Ordinateur';

  @override
  String get tabSettings => 'Réglages';

  @override
  String get paneSwitcherLabel => 'Panneau';

  @override
  String get recordPlaceholder => 'Touchez le micro et commencez à parler.';

  @override
  String get recordListeningPlaceholder => 'Écoute…';

  @override
  String get recordProcessing => 'Traitement…';

  @override
  String get recordTranscriptLabel => 'Texte';

  @override
  String get recordCopied =>
      'Copié. Insérez-le depuis le clavier ou collez-le.';

  @override
  String get recordSavedInsert => 'Enregistré. Insérez-le depuis le clavier.';

  @override
  String get recordResultCopied =>
      'Copié. Collez-le où vous voulez ou insérez-le depuis le clavier.';

  @override
  String get recordStopped => 'Enregistrement arrêté';

  @override
  String get recordHeardTextKept =>
      'Ce qui a été entendu est conservé ici et dans Brouillons.';

  @override
  String get recordTryAgain => 'Réenregistrer';

  @override
  String get recordStatusReady => 'Prêt à enregistrer';

  @override
  String get recordStatusListening => 'Écoute';

  @override
  String get recordStatusListeningDetail =>
      'Touchez Arrêter quand vous avez fini de parler.';

  @override
  String get recordStatusTranscribing => 'Transcription';

  @override
  String get recordTranscribed => 'Enregistrement transcrit';

  @override
  String get recordTranscribingDetail =>
      'Envoi de l’audio au service sélectionné.';

  @override
  String get recordFailed => 'Échec de l’enregistrement';

  @override
  String get recordMicOffLabel => 'L’accès au micro est désactivé';

  @override
  String get recordMicOffDetail =>
      'Autorisez l’accès au micro dans les Réglages d’iOS, puis réessayez.';

  @override
  String get recordRecorderNotReady =>
      'L’accès au micro est autorisé, mais l’enregistreur n’est pas prêt. Réessayez.';

  @override
  String get recordKeyRequiredLabel => 'Service à configurer';

  @override
  String get recordKeyRequiredDetail =>
      'Enregistrez une clé API Bailian ou Soniox avant d’enregistrer.';

  @override
  String get recordProfileLabel => 'Profil';

  @override
  String get recordButtonStart => 'Commencer l’enregistrement';

  @override
  String get recordButtonStop => 'Arrêter l’enregistrement';

  @override
  String get recordButtonUnavailable => 'Enregistrement indisponible';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => 'choisi par vous';

  @override
  String get profileReasonAutomation => 'choisi par une automatisation';

  @override
  String get profileReasonDefault => 'par défaut';

  @override
  String get draftsTitle => 'Brouillons';

  @override
  String get draftsEmpty =>
      'Vos textes apparaîtront ici après un enregistrement.';

  @override
  String get draftsToday => 'Aujourd’hui';

  @override
  String get draftsYesterday => 'Hier';

  @override
  String get draftsCopyDraft => 'Copier le brouillon';

  @override
  String get draftsDeleted => 'Brouillon supprimé';

  @override
  String get draftsCopied => 'Brouillon copié dans le presse-papiers.';

  @override
  String get draftEditorTitle => 'Brouillon';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSectionRecognition => 'Reconnaissance';

  @override
  String get settingsMicrophoneTitle => 'Accès au micro';

  @override
  String get settingsMicrophoneAllowed => 'Autorisé pour la saisie vocale';

  @override
  String get settingsMicrophoneTapToAllow =>
      'Touchez pour autoriser l’accès au micro';

  @override
  String get settingsSpeechProvider => 'Service de reconnaissance vocale';

  @override
  String get settingsPostProcessingTitle => 'Post-traitement du texte';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return 'Utiliser $model pour nettoyer ou traduire';
  }

  @override
  String get settingsCloudTitle => 'Traitement dans le cloud';

  @override
  String get settingsCloudSaved =>
      'Les identifiants du service sont enregistrés';

  @override
  String get settingsCloudNotSaved =>
      'Enregistrez les identifiants avant une vraie transcription';

  @override
  String get settingsLoading => 'Chargement des réglages enregistrés';

  @override
  String get settingsRealtimeModel => 'Modèle en temps réel';

  @override
  String get settingsRecognitionMode => 'Mode de reconnaissance';

  @override
  String get settingsModeStreaming => 'Streaming';

  @override
  String get settingsStreamingModel => 'Modèle ASR en streaming';

  @override
  String get settingsBatchModel => 'Modèle par lots Qwen-ASR';

  @override
  String get settingsPostProcessingModel => 'Modèle OpenAI de post-traitement';

  @override
  String get settingsPostProcessingModelHelper =>
      'Utilisé seulement si le post-traitement du texte est activé';

  @override
  String get settingsBaseUrl => 'URL de base compatible OpenAI';

  @override
  String get settingsRealtimeUrl => 'URL WebSocket en temps réel';

  @override
  String get settingsSave => 'Enregistrer les réglages';

  @override
  String get settingsSaving => 'Enregistrement';

  @override
  String get settingsSaved => 'Réglages du service enregistrés';

  @override
  String settingsSaveFailed(String reason) {
    return 'Les réglages n’ont pas été enregistrés. $reason';
  }

  @override
  String get settingsSectionProfiles => 'Profils';

  @override
  String get settingsAddProfile => 'Ajouter un profil';

  @override
  String get settingsUseInApps => 'Dans les apps';

  @override
  String get settingsUseInAppsSubtitle =>
      'Changer de profil à l’ouverture d’une app';

  @override
  String get settingsFieldRules => 'Règles de champ';

  @override
  String get settingsFieldRulesSubtitle =>
      'Recherche, adresse web, e-mail, message';

  @override
  String get settingsSectionKeyboard => 'Clavier';

  @override
  String get settingsKeyboardSetup => 'Configurer le clavier';

  @override
  String get settingsKeyboardSetupSubtitle =>
      'Ajoutez Shinsoku et autorisez l’accès complet';

  @override
  String get settingsApiKey => 'Clé API';

  @override
  String get settingsShowKey => 'Afficher la clé';

  @override
  String get settingsHideKey => 'Masquer la clé';

  @override
  String get keyboardSetupTitle => 'Clavier';

  @override
  String get keyboardSetupIntro =>
      'Utilisez Shinsoku dans n’importe quel champ de texte.';

  @override
  String get keyboardStep1 => 'Ouvrez Réglages › Général › Clavier › Claviers.';

  @override
  String get keyboardStep2 =>
      'Touchez « Ajouter un clavier » et choisissez Shinsoku.';

  @override
  String get keyboardStep3 =>
      'Touchez Shinsoku et activez « Autoriser l’accès complet » pour que le clavier puisse insérer votre dernier texte.';

  @override
  String get useInAppsSummary =>
      'Shinsoku peut changer de profil tout seul quand vous ouvrez une app. Raccourcis détecte l’app, Shinsoku règle le profil.';

  @override
  String get useInAppsWhenOpened => 'À l’ouverture de l’app';

  @override
  String get useInAppsWhenClosed => 'À la fermeture de l’app';

  @override
  String get useInAppsOpenStep1 =>
      'Dans Raccourcis, ouvrez Automatisation et touchez « Nouvelle automatisation ».';

  @override
  String get useInAppsOpenStep2 =>
      'Choisissez « App », sélectionnez l’app, puis « Est ouverte ». Activez « Exécuter immédiatement ».';

  @override
  String get useInAppsOpenStep3 =>
      'Ajoutez l’action « Définir le profil Shinsoku » et choisissez le profil de cette app.';

  @override
  String get useInAppsCloseStep1 =>
      'Ajoutez une deuxième automatisation pour la même app avec « Est fermée ». Activez « Exécuter immédiatement ».';

  @override
  String get useInAppsCloseStep2 =>
      'Ajoutez « Définir le profil Shinsoku » et choisissez votre profil par défaut pour que les autres apps y reviennent.';

  @override
  String get useInAppsKeyboardNote =>
      'Vous pouvez aussi toucher le nom du profil dans le clavier pour en changer. Il reste actif jusqu’à la prochaine automatisation.';

  @override
  String get useInAppsReadyMade =>
      'Chaque profil a aussi une action prête à l’emploi dans l’app Raccourcis, par exemple « Passer Shinsoku en Discussion ». Aucune configuration requise.';

  @override
  String get useInAppsIosNote =>
      'Les actions Raccourcis nécessitent iOS 16 ou ultérieur.';

  @override
  String get useInAppsOpenShortcuts => 'Ouvrir Raccourcis';

  @override
  String get fieldRulesTitle => 'Règles de champ';

  @override
  String get fieldRulesSummary =>
      'Utiliser un profil automatiquement dans certains types de champ. S’applique seulement si vous n’avez pas choisi de profil dans le clavier et qu’aucune automatisation n’en a défini un.';

  @override
  String get fieldRulesNone => 'Aucun';

  @override
  String get fieldKindSearch => 'Recherche';

  @override
  String get fieldKindUrl => 'Adresse web';

  @override
  String get fieldKindEmail => 'E-mail';

  @override
  String get fieldKindMessage => 'Message';

  @override
  String get profileNewTitle => 'Nouveau profil';

  @override
  String get profileEditTitle => 'Modifier le profil';

  @override
  String get profileNameLabel => 'Nom';

  @override
  String get profilePromptLabel => 'Consigne de post-traitement';

  @override
  String get profilePromptHelper =>
      'Exemple : Traduis le français parlé en anglais naturel.';

  @override
  String get profileAfterText => 'Après le texte';

  @override
  String get profileSuffixNothing => 'Rien';

  @override
  String get profileSuffixSpace => 'Espace';

  @override
  String get profileSuffixNewLine => 'Retour à la ligne';

  @override
  String get profileAutoCommit => 'Insertion auto';

  @override
  String get profileAutoCommitSubtitle => 'Insérer sans étape de relecture';

  @override
  String get profileDelete => 'Supprimer le profil';

  @override
  String profileDeleteConfirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get profileKeepOne => 'Gardez au moins un profil';

  @override
  String get profileUntitled => 'Sans titre';

  @override
  String get profileDefaultIntent =>
      'Nettoie la transcription. Renvoie uniquement le texte final.';

  @override
  String get profileDictationName => 'Dictée';

  @override
  String get profileDictationIntent => 'Transformer la parole en texte naturel';

  @override
  String get profileChatName => 'Discussion';

  @override
  String get profileChatIntent => 'Rendre le texte concis et conversationnel';

  @override
  String get profileReviewName => 'Relecture';

  @override
  String get profileReviewIntent =>
      'Garder le texte pour une relecture manuelle';

  @override
  String get profileZhToEnName => 'ZH → EN';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => 'Traduire → EN';

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
  String get shellAlreadyRecording => 'Shinsoku enregistre déjà.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return 'Post-traitement du texte activé pour $profile.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return 'Le réglage de post-traitement n’a pas été enregistré. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'Impossible de copier le texte. $reason';
  }

  @override
  String get failureTimeout =>
      'Le service a mis trop de temps à répondre. Vérifiez votre connexion et réessayez.';

  @override
  String get failureNetwork =>
      'Pas de connexion au service. Vérifiez votre réseau et réessayez.';

  @override
  String get failureConnectionLost => 'La connexion a été perdue. Réessayez.';

  @override
  String get failureKeyMissing =>
      'Aucune clé API enregistrée. Ajoutez-en une dans Réglages.';

  @override
  String get failureKeyInvalid =>
      'Le service n’a pas accepté votre clé API. Vérifiez-la dans Réglages.';

  @override
  String get failureQuota =>
      'Le service signale un quota épuisé ou trop de requêtes. Vérifiez votre compte.';

  @override
  String get failureNothingHeard => 'Aucune parole reconnue. Réessayez.';

  @override
  String get failureRecording =>
      'L’enregistrement n’a pas pu aboutir. Réessayez.';

  @override
  String get failureMicrophone =>
      'Le micro n’est pas disponible. Vérifiez l’accès au micro dans Réglages.';

  @override
  String get failureGeneric => 'Un problème est survenu. Réessayez.';

  @override
  String get nearbyTitle => 'Micro pour ordinateur';

  @override
  String get nearbySubtitle => 'Connexion locale privée';

  @override
  String get nearbySectionDesktop => 'Ordinateur';

  @override
  String get nearbyFindDesktops => 'Chercher des ordinateurs';

  @override
  String get nearbyAddManually => 'Ajouter un ordinateur manuellement';

  @override
  String get nearbyEndpointLabel => 'Adresse WSS';

  @override
  String get nearbyCertificateLabel => 'SHA-256 du certificat';

  @override
  String get nearbyAdd => 'Ajouter';

  @override
  String get nearbySectionTrust => 'Confiance';

  @override
  String get nearbyTrustedDesktop => 'Ordinateur de confiance';

  @override
  String get nearbyCertificateFingerprint => 'Empreinte du certificat';

  @override
  String get nearbyMatchesTitle => 'Identique sur l’ordinateur';

  @override
  String get nearbyMatchesSubtitle =>
      'Comparez-la aux réglages de l’ordinateur';

  @override
  String get nearbyPairingCodeLabel =>
      'Code de jumelage affiché sur l’ordinateur';

  @override
  String get nearbyDisconnect => 'Déconnecter';

  @override
  String get nearbyConnect => 'Connecter';

  @override
  String get nearbyPairAndConnect => 'Jumeler et connecter';

  @override
  String get nearbyForget => 'Oublier l’ordinateur';

  @override
  String get nearbySectionRemoteInput => 'Saisie à distance';

  @override
  String get nearbyProfileRow => 'Profil';

  @override
  String get nearbyProfileAutomatic => 'Auto (ordinateur)';

  @override
  String get nearbyProfileSheetTitle => 'Profil de l’ordinateur';

  @override
  String get nearbyStopAndTranscribe => 'Arrêter et transcrire';

  @override
  String get nearbyStartRemote => 'Démarrer la dictée à distance';

  @override
  String get nearbyConnectToDictate => 'Connectez un ordinateur pour y dicter';

  @override
  String nearbyConnectingTo(String name) {
    return 'Connexion à $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return 'Connecté à $name';
  }

  @override
  String get nearbyStreaming => 'Envoi de l’audio du micro';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Envoi avec $countString trames manquantes',
      one: 'Envoi avec 1 trame manquante',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => 'Enregistrement envoyé à l’ordinateur';

  @override
  String get nearbyNotConnected => 'Non connecté';

  @override
  String get nearbyDisconnected => 'Ordinateur déconnecté';

  @override
  String get nearbySearching => 'Recherche sur le réseau local';

  @override
  String get nearbyNoneFound => 'Aucun ordinateur Shinsoku trouvé';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ordinateurs trouvés',
      one: '1 ordinateur trouvé',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => 'Ordinateur de confiance sélectionné';

  @override
  String get nearbyVerifyFingerprint => 'Vérifiez l’empreinte de l’ordinateur';

  @override
  String get nearbyTrustRemoved => 'Confiance locale supprimée';

  @override
  String get nearbyErrorPairingCodeRequired =>
      'Saisissez le code à deux chiffres affiché sur l’ordinateur.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      'L’empreinte du certificat n’est pas valide. Saisissez les 64 caractères hexadécimaux.';

  @override
  String get nearbyErrorEndpointInvalid =>
      'Saisissez un hôte et un port wss:// valides.';

  @override
  String get nearbyErrorCertificateChanged =>
      'Le certificat de l’ordinateur a changé. Oubliez-le et jumelez-le à nouveau.';

  @override
  String get nearbyErrorCredentialMissing =>
      'L’ordinateur reconnaît cet appareil, mais l’identifiant local est introuvable. Révoquez-le sur l’ordinateur et jumelez à nouveau.';

  @override
  String get nearbyErrorPairingUnavailable =>
      'Créez un code de jumelage dans les réglages de l’ordinateur, puis reconnectez-vous.';

  @override
  String get nearbyErrorPairingExpired =>
      'Le code de jumelage a expiré. Créez-en un nouveau.';

  @override
  String get nearbyErrorWrongCode => 'Le code de jumelage est incorrect.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'Plus aucune tentative de jumelage. Créez un nouveau code sur l’ordinateur.';

  @override
  String get nearbyErrorDesktopBusy =>
      'L’ordinateur enregistre ou traite déjà de l’audio.';

  @override
  String get nearbyErrorConnectFirst =>
      'Connectez un ordinateur avant d’enregistrer.';

  @override
  String get nearbyErrorTimeout => 'L’ordinateur n’a pas répondu à temps.';

  @override
  String get nearbyErrorConnectionLost =>
      'La connexion à l’ordinateur a été perdue.';

  @override
  String get nearbyErrorMicDenied =>
      'L’accès au micro est requis. Autorisez-le dans Réglages.';

  @override
  String get nearbyErrorRecorderNotReady =>
      'Le micro n’est pas prêt. Réessayez.';

  @override
  String get nearbyErrorMicStream =>
      'Le micro s’est arrêté de façon inattendue.';

  @override
  String get nearbyErrorDiscovery =>
      'Impossible de chercher sur le réseau local. Vérifiez le Wi-Fi et réessayez.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'L’ordinateur a envoyé une réponse inattendue. Mettez à jour Shinsoku sur les deux appareils et réessayez.';

  @override
  String get nearbyErrorGeneric =>
      'Un problème est survenu avec la connexion à l’ordinateur.';
}
