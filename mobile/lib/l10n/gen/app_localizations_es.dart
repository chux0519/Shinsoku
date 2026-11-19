// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonDone => 'OK';

  @override
  String get commonClear => 'Borrar';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get commonOpenSettings => 'Abrir Ajustes';

  @override
  String get tabRecord => 'Grabar';

  @override
  String get tabDrafts => 'Borradores';

  @override
  String get tabDesktop => 'Ordenador';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String get paneSwitcherLabel => 'Panel';

  @override
  String get recordPlaceholder => 'Toca el micrófono y empieza a hablar.';

  @override
  String get recordListeningPlaceholder => 'Escuchando…';

  @override
  String get recordProcessing => 'Procesando…';

  @override
  String get recordTranscriptLabel => 'Texto';

  @override
  String get recordCopied => 'Copiado. Insértalo desde el teclado o pégalo.';

  @override
  String get recordSavedInsert => 'Guardado. Insértalo desde el teclado.';

  @override
  String get recordResultCopied =>
      'Copiado. Pégalo donde quieras o insértalo desde el teclado.';

  @override
  String get recordStopped => 'Grabación detenida';

  @override
  String get recordHeardTextKept =>
      'Lo que se oyó se conserva aquí y en Borradores.';

  @override
  String get recordTryAgain => 'Volver a grabar';

  @override
  String get recordStatusReady => 'Listo para grabar';

  @override
  String get recordStatusListening => 'Escuchando';

  @override
  String get recordStatusListeningDetail =>
      'Toca detener cuando termines de hablar.';

  @override
  String get recordStatusTranscribing => 'Transcribiendo';

  @override
  String get recordTranscribed => 'Grabación transcrita';

  @override
  String get recordTranscribingDetail =>
      'Subiendo el audio grabado al proveedor seleccionado.';

  @override
  String get recordFailed => 'Error en la grabación';

  @override
  String get recordMicOffLabel => 'El acceso al micrófono está desactivado';

  @override
  String get recordMicOffDetail =>
      'Permite el acceso al micrófono en Ajustes de iOS y vuelve a grabar.';

  @override
  String get recordRecorderNotReady =>
      'El micrófono tiene permiso, pero la grabadora no está lista. Inténtalo de nuevo.';

  @override
  String get recordKeyRequiredLabel => 'Falta configurar el proveedor';

  @override
  String get recordKeyRequiredDetail =>
      'Guarda una clave API de Bailian o Soniox antes de grabar.';

  @override
  String get recordProfileLabel => 'Perfil';

  @override
  String get recordButtonStart => 'Empezar a grabar';

  @override
  String get recordButtonStop => 'Detener grabación';

  @override
  String get recordButtonUnavailable => 'No se puede grabar';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => 'elegido por ti';

  @override
  String get profileReasonAutomation => 'elegido por una automatización';

  @override
  String get profileReasonDefault => 'predeterminado';

  @override
  String get draftsTitle => 'Borradores';

  @override
  String get draftsEmpty => 'Tus textos aparecerán aquí cuando grabes.';

  @override
  String get draftsToday => 'Hoy';

  @override
  String get draftsYesterday => 'Ayer';

  @override
  String get draftsCopyDraft => 'Copiar borrador';

  @override
  String get draftsDeleted => 'Borrador eliminado';

  @override
  String get draftsCopied => 'Borrador copiado al portapapeles.';

  @override
  String get draftEditorTitle => 'Borrador';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionRecognition => 'Reconocimiento';

  @override
  String get settingsMicrophoneTitle => 'Acceso al micrófono';

  @override
  String get settingsMicrophoneAllowed => 'Permitido para la entrada de voz';

  @override
  String get settingsMicrophoneTapToAllow =>
      'Toca para permitir el acceso al micrófono';

  @override
  String get settingsSpeechProvider => 'Proveedor de voz';

  @override
  String get settingsPostProcessingTitle => 'Posprocesado de texto';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return 'Usar $model para limpiar o traducir';
  }

  @override
  String get settingsCloudTitle => 'Procesamiento en la nube';

  @override
  String get settingsCloudSaved =>
      'Las credenciales del proveedor están guardadas';

  @override
  String get settingsCloudNotSaved =>
      'Guarda las credenciales antes de transcribir de verdad';

  @override
  String get settingsLoading => 'Cargando los ajustes guardados';

  @override
  String get settingsRealtimeModel => 'Modelo en tiempo real';

  @override
  String get settingsRecognitionMode => 'Modo de reconocimiento';

  @override
  String get settingsModeStreaming => 'Streaming';

  @override
  String get settingsStreamingModel => 'Modelo ASR en streaming';

  @override
  String get settingsBatchModel => 'Modelo por lotes de Qwen-ASR';

  @override
  String get settingsPostProcessingModel => 'Modelo OpenAI de posprocesado';

  @override
  String get settingsPostProcessingModelHelper =>
      'Solo se usa con el posprocesado de texto activado';

  @override
  String get settingsBaseUrl => 'URL base compatible con OpenAI';

  @override
  String get settingsRealtimeUrl => 'URL de WebSocket en tiempo real';

  @override
  String get settingsSave => 'Guardar ajustes';

  @override
  String get settingsSaving => 'Guardando';

  @override
  String get settingsSaved => 'Ajustes del proveedor guardados';

  @override
  String settingsSaveFailed(String reason) {
    return 'No se guardaron los ajustes. $reason';
  }

  @override
  String get settingsSectionProfiles => 'Perfiles';

  @override
  String get settingsAddProfile => 'Añadir perfil';

  @override
  String get settingsUseInApps => 'Usar en apps';

  @override
  String get settingsUseInAppsSubtitle => 'Cambia de perfil al abrir una app';

  @override
  String get settingsFieldRules => 'Reglas de campo';

  @override
  String get settingsFieldRulesSubtitle =>
      'Búsqueda, dirección web, correo, mensaje';

  @override
  String get settingsSectionKeyboard => 'Teclado';

  @override
  String get settingsKeyboardSetup => 'Configurar el teclado';

  @override
  String get settingsKeyboardSetupSubtitle =>
      'Añade Shinsoku y permite el acceso completo';

  @override
  String get settingsApiKey => 'Clave API';

  @override
  String get settingsShowKey => 'Mostrar clave';

  @override
  String get settingsHideKey => 'Ocultar clave';

  @override
  String get keyboardSetupTitle => 'Teclado';

  @override
  String get keyboardSetupIntro => 'Usa Shinsoku en cualquier campo de texto.';

  @override
  String get keyboardStep1 => 'Abre Ajustes › General › Teclado › Teclados.';

  @override
  String get keyboardStep2 => 'Toca “Añadir nuevo teclado” y elige Shinsoku.';

  @override
  String get keyboardStep3 =>
      'Toca Shinsoku y activa “Permitir acceso completo” para que el teclado pueda insertar tu último texto.';

  @override
  String get useInAppsSummary =>
      'Shinsoku puede cambiar de perfil por sí solo cuando abres una app. Atajos detecta la app y Shinsoku pone el perfil.';

  @override
  String get useInAppsWhenOpened => 'Al abrir la app';

  @override
  String get useInAppsWhenClosed => 'Al cerrar la app';

  @override
  String get useInAppsOpenStep1 =>
      'En Atajos, abre Automatización y toca “Nueva automatización”.';

  @override
  String get useInAppsOpenStep2 =>
      'Elige “App”, selecciona la app y marca “Se abre”. Activa “Ejecutar inmediatamente”.';

  @override
  String get useInAppsOpenStep3 =>
      'Añade la acción “Definir perfil de Shinsoku” y elige el perfil para esa app.';

  @override
  String get useInAppsCloseStep1 =>
      'Añade una segunda automatización para la misma app y marca “Se cierra”. Activa “Ejecutar inmediatamente”.';

  @override
  String get useInAppsCloseStep2 =>
      'Añade “Definir perfil de Shinsoku” y elige tu perfil predeterminado para que las demás apps vuelvan a él.';

  @override
  String get useInAppsKeyboardNote =>
      'También puedes tocar el nombre del perfil en el teclado para cambiarlo. Se mantiene hasta que se vuelva a ejecutar una automatización.';

  @override
  String get useInAppsReadyMade =>
      'Cada perfil tiene además una acción lista para usar en la app Atajos, como “Cambiar Shinsoku a Chat”. No hace falta configurar nada.';

  @override
  String get useInAppsIosNote =>
      'Las acciones de Atajos necesitan iOS 16 o posterior.';

  @override
  String get useInAppsOpenShortcuts => 'Abrir Atajos';

  @override
  String get fieldRulesTitle => 'Reglas de campo';

  @override
  String get fieldRulesSummary =>
      'Usa un perfil automáticamente en ciertos tipos de campo. Solo se aplica si no has elegido un perfil en el teclado y ninguna automatización ha puesto uno.';

  @override
  String get fieldRulesNone => 'Ninguno';

  @override
  String get fieldKindSearch => 'Búsqueda';

  @override
  String get fieldKindUrl => 'Dirección web';

  @override
  String get fieldKindEmail => 'Correo';

  @override
  String get fieldKindMessage => 'Mensaje';

  @override
  String get profileNewTitle => 'Nuevo perfil';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileNameLabel => 'Nombre';

  @override
  String get profilePromptLabel => 'Instrucción de posprocesado';

  @override
  String get profilePromptHelper =>
      'Ejemplo: Traduce el español hablado a un inglés natural.';

  @override
  String get profileAfterText => 'Después del texto';

  @override
  String get profileSuffixNothing => 'Nada';

  @override
  String get profileSuffixSpace => 'Espacio';

  @override
  String get profileSuffixNewLine => 'Nueva línea';

  @override
  String get profileAutoCommit => 'Insertar automáticamente';

  @override
  String get profileAutoCommitSubtitle => 'Inserta sin paso de revisión';

  @override
  String get profileDelete => 'Eliminar perfil';

  @override
  String profileDeleteConfirm(String name) {
    return '¿Eliminar “$name”?';
  }

  @override
  String get profileKeepOne => 'Debe quedar al menos un perfil';

  @override
  String get profileUntitled => 'Sin título';

  @override
  String get profileDefaultIntent =>
      'Limpia la transcripción. Devuelve solo el texto final.';

  @override
  String get profileDictationName => 'Dictado';

  @override
  String get profileDictationIntent =>
      'Convertir lo hablado en un texto natural';

  @override
  String get profileChatName => 'Chat';

  @override
  String get profileChatIntent => 'Hacer el texto breve y conversacional';

  @override
  String get profileReviewName => 'Revisar';

  @override
  String get profileReviewIntent => 'Retener el texto para revisarlo a mano';

  @override
  String get profileZhToEnName => 'ZH → EN';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => 'Traducir → EN';

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
  String get shellAlreadyRecording => 'Shinsoku ya está grabando.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return 'Posprocesado de texto activado para $profile.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return 'No se guardó el ajuste de posprocesado. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'No se pudo copiar el texto. $reason';
  }

  @override
  String get failureTimeout =>
      'El proveedor tardó demasiado en responder. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get failureNetwork =>
      'No hay conexión con el proveedor. Comprueba tu red e inténtalo de nuevo.';

  @override
  String get failureConnectionLost =>
      'Se perdió la conexión. Inténtalo de nuevo.';

  @override
  String get failureKeyMissing =>
      'No hay ninguna clave API guardada. Añade una en Ajustes.';

  @override
  String get failureKeyInvalid =>
      'El proveedor no aceptó tu clave API. Revísala en Ajustes.';

  @override
  String get failureQuota =>
      'El proveedor indica que no queda cuota o que hay demasiadas solicitudes. Revisa tu cuenta.';

  @override
  String get failureNothingHeard =>
      'No se reconoció ninguna voz. Inténtalo de nuevo.';

  @override
  String get failureRecording =>
      'No se pudo completar la grabación. Inténtalo de nuevo.';

  @override
  String get failureMicrophone =>
      'El micrófono no está disponible. Comprueba el acceso al micrófono en Ajustes.';

  @override
  String get failureGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get nearbyTitle => 'Micro para ordenador';

  @override
  String get nearbySubtitle => 'Conexión local privada';

  @override
  String get nearbySectionDesktop => 'Ordenador';

  @override
  String get nearbyFindDesktops => 'Buscar ordenadores';

  @override
  String get nearbyAddManually => 'Añadir ordenador manualmente';

  @override
  String get nearbyEndpointLabel => 'Dirección WSS';

  @override
  String get nearbyCertificateLabel => 'SHA-256 del certificado';

  @override
  String get nearbyAdd => 'Añadir';

  @override
  String get nearbySectionTrust => 'Confianza';

  @override
  String get nearbyTrustedDesktop => 'Ordenador de confianza';

  @override
  String get nearbyCertificateFingerprint => 'Huella digital del certificado';

  @override
  String get nearbyMatchesTitle => 'Coincide con el ordenador';

  @override
  String get nearbyMatchesSubtitle => 'Compárala con los ajustes del ordenador';

  @override
  String get nearbyPairingCodeLabel => 'Código de vinculación del ordenador';

  @override
  String get nearbyDisconnect => 'Desconectar';

  @override
  String get nearbyConnect => 'Conectar';

  @override
  String get nearbyPairAndConnect => 'Vincular y conectar';

  @override
  String get nearbyForget => 'Olvidar ordenador';

  @override
  String get nearbySectionRemoteInput => 'Entrada remota';

  @override
  String get nearbyProfileRow => 'Perfil';

  @override
  String get nearbyProfileAutomatic => 'Automático (ordenador)';

  @override
  String get nearbyProfileSheetTitle => 'Perfil del ordenador';

  @override
  String get nearbyStopAndTranscribe => 'Detener y transcribir';

  @override
  String get nearbyStartRemote => 'Empezar dictado remoto';

  @override
  String get nearbyConnectToDictate => 'Conéctate a un ordenador para dictarle';

  @override
  String nearbyConnectingTo(String name) {
    return 'Conectando con $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return 'Conectado a $name';
  }

  @override
  String get nearbyStreaming => 'Enviando el audio del micrófono';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviando con $countString fotogramas perdidos',
      one: 'Enviando con 1 fotograma perdido',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => 'Grabación enviada al ordenador';

  @override
  String get nearbyNotConnected => 'Sin conexión';

  @override
  String get nearbyDisconnected => 'Ordenador desconectado';

  @override
  String get nearbySearching => 'Buscando en la red local';

  @override
  String get nearbyNoneFound => 'No se encontró ningún ordenador con Shinsoku';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ordenadores encontrados',
      one: '1 ordenador encontrado',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => 'Ordenador de confianza seleccionado';

  @override
  String get nearbyVerifyFingerprint =>
      'Verifica la huella digital del ordenador';

  @override
  String get nearbyTrustRemoved => 'Confianza local eliminada';

  @override
  String get nearbyErrorPairingCodeRequired =>
      'Introduce el código de dos dígitos que muestra el ordenador.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      'La huella digital del certificado no es válida. Introduce los 64 caracteres hexadecimales.';

  @override
  String get nearbyErrorEndpointInvalid =>
      'Introduce un host y puerto wss:// válidos.';

  @override
  String get nearbyErrorCertificateChanged =>
      'El certificado del ordenador ha cambiado. Olvídalo y vuelve a vincularlo.';

  @override
  String get nearbyErrorCredentialMissing =>
      'El ordenador recuerda este dispositivo, pero falta la credencial local. Revócala en el ordenador y vuelve a vincularlo.';

  @override
  String get nearbyErrorPairingUnavailable =>
      'Crea un código de vinculación en los ajustes del ordenador y vuelve a conectar.';

  @override
  String get nearbyErrorPairingExpired =>
      'El código de vinculación ha caducado. Crea uno nuevo.';

  @override
  String get nearbyErrorWrongCode => 'El código de vinculación no es correcto.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'Se agotaron los intentos de vinculación. Crea un código nuevo en el ordenador.';

  @override
  String get nearbyErrorDesktopBusy =>
      'El ordenador ya está grabando o procesando audio.';

  @override
  String get nearbyErrorConnectFirst =>
      'Conéctate a un ordenador antes de grabar.';

  @override
  String get nearbyErrorTimeout => 'El ordenador no respondió a tiempo.';

  @override
  String get nearbyErrorConnectionLost =>
      'Se perdió la conexión con el ordenador.';

  @override
  String get nearbyErrorMicDenied =>
      'Se necesita acceso al micrófono. Permítelo en Ajustes.';

  @override
  String get nearbyErrorRecorderNotReady =>
      'El micrófono no está listo. Inténtalo de nuevo.';

  @override
  String get nearbyErrorMicStream =>
      'El micrófono se detuvo de forma inesperada.';

  @override
  String get nearbyErrorDiscovery =>
      'No se pudo buscar en la red local. Comprueba la Wi-Fi e inténtalo de nuevo.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'El ordenador envió una respuesta inesperada. Actualiza Shinsoku en ambos dispositivos e inténtalo de nuevo.';

  @override
  String get nearbyErrorGeneric =>
      'Algo salió mal con la conexión al ordenador.';
}
