// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDelete => 'Apagar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonDone => 'OK';

  @override
  String get commonClear => 'Limpar';

  @override
  String get commonUndo => 'Desfazer';

  @override
  String get commonOpenSettings => 'Abrir Ajustes';

  @override
  String get tabRecord => 'Gravar';

  @override
  String get tabDrafts => 'Rascunhos';

  @override
  String get tabDesktop => 'Computador';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String get paneSwitcherLabel => 'Painel';

  @override
  String get recordPlaceholder => 'Toque no microfone e comece a falar.';

  @override
  String get recordListeningPlaceholder => 'Ouvindo…';

  @override
  String get recordProcessing => 'Processando…';

  @override
  String get recordTranscriptLabel => 'Texto';

  @override
  String get recordCopied => 'Copiado. Insira pelo teclado ou cole.';

  @override
  String get recordSavedInsert => 'Salvo. Insira pelo teclado.';

  @override
  String get recordResultCopied =>
      'Copiado. Cole onde quiser ou insira pelo teclado.';

  @override
  String get recordStopped => 'Gravação interrompida';

  @override
  String get recordHeardTextKept =>
      'O que foi ouvido fica guardado aqui e em Rascunhos.';

  @override
  String get recordTryAgain => 'Gravar de novo';

  @override
  String get recordStatusReady => 'Pronto para gravar';

  @override
  String get recordStatusListening => 'Ouvindo';

  @override
  String get recordStatusListeningDetail =>
      'Toque em parar quando terminar de falar.';

  @override
  String get recordStatusTranscribing => 'Transcrevendo';

  @override
  String get recordTranscribed => 'Gravação transcrita';

  @override
  String get recordTranscribingDetail =>
      'Enviando o áudio gravado ao provedor selecionado.';

  @override
  String get recordFailed => 'Falha na gravação';

  @override
  String get recordMicOffLabel => 'O acesso ao microfone está desativado';

  @override
  String get recordMicOffDetail =>
      'Permita o acesso ao microfone nos Ajustes do iOS e grave de novo.';

  @override
  String get recordRecorderNotReady =>
      'O microfone foi permitido, mas o gravador não está pronto. Tente de novo.';

  @override
  String get recordKeyRequiredLabel => 'Configure o provedor';

  @override
  String get recordKeyRequiredDetail =>
      'Salve uma chave de API do Bailian ou do Soniox antes de gravar.';

  @override
  String get recordProfileLabel => 'Perfil';

  @override
  String get recordButtonStart => 'Começar a gravar';

  @override
  String get recordButtonStop => 'Parar de gravar';

  @override
  String get recordButtonUnavailable => 'Gravação indisponível';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => 'escolhido por você';

  @override
  String get profileReasonAutomation => 'definido por automação';

  @override
  String get profileReasonDefault => 'padrão';

  @override
  String get draftsTitle => 'Rascunhos';

  @override
  String get draftsEmpty => 'Seus textos aparecem aqui depois que você gravar.';

  @override
  String get draftsToday => 'Hoje';

  @override
  String get draftsYesterday => 'Ontem';

  @override
  String get draftsCopyDraft => 'Copiar rascunho';

  @override
  String get draftsDeleted => 'Rascunho apagado';

  @override
  String get draftsCopied => 'Rascunho copiado para a área de transferência.';

  @override
  String get draftEditorTitle => 'Rascunho';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionRecognition => 'Reconhecimento';

  @override
  String get settingsMicrophoneTitle => 'Acesso ao microfone';

  @override
  String get settingsMicrophoneAllowed => 'Permitido para entrada de voz';

  @override
  String get settingsMicrophoneTapToAllow =>
      'Toque para permitir o acesso ao microfone';

  @override
  String get settingsSpeechProvider => 'Provedor de voz';

  @override
  String get settingsPostProcessingTitle => 'Pós-processamento de texto';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return 'Usar $model para limpar ou traduzir';
  }

  @override
  String get settingsCloudTitle => 'Processamento na nuvem';

  @override
  String get settingsCloudSaved => 'As credenciais do provedor estão salvas';

  @override
  String get settingsCloudNotSaved =>
      'Salve as credenciais antes de transcrever de verdade';

  @override
  String get settingsLoading => 'Carregando os ajustes salvos';

  @override
  String get settingsRealtimeModel => 'Modelo em tempo real';

  @override
  String get settingsRecognitionMode => 'Modo de reconhecimento';

  @override
  String get settingsModeStreaming => 'Streaming';

  @override
  String get settingsStreamingModel => 'Modelo ASR em streaming';

  @override
  String get settingsBatchModel => 'Modelo em lote do Qwen-ASR';

  @override
  String get settingsPostProcessingModel =>
      'Modelo OpenAI de pós-processamento';

  @override
  String get settingsPostProcessingModelHelper =>
      'Usado só com o pós-processamento de texto ativado';

  @override
  String get settingsBaseUrl => 'URL base compatível com OpenAI';

  @override
  String get settingsRealtimeUrl => 'URL do WebSocket em tempo real';

  @override
  String get settingsSave => 'Salvar Ajustes';

  @override
  String get settingsSaving => 'Salvando';

  @override
  String get settingsSaved => 'Ajustes do provedor salvos';

  @override
  String settingsSaveFailed(String reason) {
    return 'Os ajustes não foram salvos. $reason';
  }

  @override
  String get settingsSectionProfiles => 'Perfis';

  @override
  String get settingsAddProfile => 'Adicionar perfil';

  @override
  String get settingsUseInApps => 'Usar nos apps';

  @override
  String get settingsUseInAppsSubtitle => 'Trocar de perfil ao abrir um app';

  @override
  String get settingsFieldRules => 'Regras de campo';

  @override
  String get settingsFieldRulesSubtitle =>
      'Busca, endereço web, e-mail, mensagem';

  @override
  String get settingsSectionKeyboard => 'Teclado';

  @override
  String get settingsKeyboardSetup => 'Configurar teclado';

  @override
  String get settingsKeyboardSetupSubtitle =>
      'Adicione o Shinsoku e permita o Acesso Total';

  @override
  String get settingsApiKey => 'Chave de API';

  @override
  String get settingsShowKey => 'Mostrar chave';

  @override
  String get settingsHideKey => 'Ocultar chave';

  @override
  String get keyboardSetupTitle => 'Teclado';

  @override
  String get keyboardSetupIntro => 'Use o Shinsoku em qualquer campo de texto.';

  @override
  String get keyboardStep1 => 'Abra Ajustes › Geral › Teclado › Teclados.';

  @override
  String get keyboardStep2 =>
      'Toque em “Adicionar Novo Teclado” e escolha Shinsoku.';

  @override
  String get keyboardStep3 =>
      'Toque em Shinsoku e ative “Permitir Acesso Total” para o teclado poder inserir seu texto mais recente.';

  @override
  String get useInAppsSummary =>
      'O Shinsoku pode trocar de perfil sozinho quando você abre um app. O Atalhos detecta o app, e o Shinsoku define o perfil.';

  @override
  String get useInAppsWhenOpened => 'Quando o app é aberto';

  @override
  String get useInAppsWhenClosed => 'Quando o app é fechado';

  @override
  String get useInAppsOpenStep1 =>
      'No Atalhos, abra Automação e toque em “Nova Automação”.';

  @override
  String get useInAppsOpenStep2 =>
      'Escolha “App”, selecione o app e marque “É Aberto”. Ative “Executar Imediatamente”.';

  @override
  String get useInAppsOpenStep3 =>
      'Adicione a ação “Definir Perfil do Shinsoku” e escolha o perfil para esse app.';

  @override
  String get useInAppsCloseStep1 =>
      'Adicione uma segunda automação para o mesmo app e marque “É Fechado”. Ative “Executar Imediatamente”.';

  @override
  String get useInAppsCloseStep2 =>
      'Adicione “Definir Perfil do Shinsoku” e escolha seu perfil padrão, para que os outros apps voltem a ele.';

  @override
  String get useInAppsKeyboardNote =>
      'Você também pode tocar no nome do perfil no teclado para trocar. Ele fica até uma automação rodar de novo.';

  @override
  String get useInAppsReadyMade =>
      'Cada perfil também tem uma ação pronta no app Atalhos, como “Mudar Shinsoku para Conversa”. Não precisa configurar nada.';

  @override
  String get useInAppsIosNote =>
      'As ações do Atalhos precisam do iOS 16 ou posterior.';

  @override
  String get useInAppsOpenShortcuts => 'Abrir Atalhos';

  @override
  String get fieldRulesTitle => 'Regras de campo';

  @override
  String get fieldRulesSummary =>
      'Use um perfil automaticamente em certos tipos de campo. Só vale quando você não escolheu um perfil no teclado e nenhuma automação definiu um.';

  @override
  String get fieldRulesNone => 'Nenhum';

  @override
  String get fieldKindSearch => 'Busca';

  @override
  String get fieldKindUrl => 'Endereço web';

  @override
  String get fieldKindEmail => 'E-mail';

  @override
  String get fieldKindMessage => 'Mensagem';

  @override
  String get profileNewTitle => 'Novo perfil';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileNameLabel => 'Nome';

  @override
  String get profilePromptLabel => 'Instrução de pós-processamento';

  @override
  String get profilePromptHelper =>
      'Exemplo: Traduza a fala em português para um inglês natural.';

  @override
  String get profileAfterText => 'Depois do texto';

  @override
  String get profileSuffixNothing => 'Nada';

  @override
  String get profileSuffixSpace => 'Espaço';

  @override
  String get profileSuffixNewLine => 'Nova linha';

  @override
  String get profileAutoCommit => 'Inserir automaticamente';

  @override
  String get profileAutoCommitSubtitle => 'Inserir sem etapa de revisão';

  @override
  String get profileDelete => 'Apagar perfil';

  @override
  String profileDeleteConfirm(String name) {
    return 'Apagar “$name”?';
  }

  @override
  String get profileKeepOne => 'Mantenha pelo menos um perfil';

  @override
  String get profileUntitled => 'Sem título';

  @override
  String get profileDefaultIntent =>
      'Limpe a transcrição. Retorne só o texto final.';

  @override
  String get profileDictationName => 'Ditado';

  @override
  String get profileDictationIntent => 'Transformar a fala em um texto natural';

  @override
  String get profileChatName => 'Conversa';

  @override
  String get profileChatIntent => 'Deixar o texto curto e informal';

  @override
  String get profileReviewName => 'Revisar';

  @override
  String get profileReviewIntent => 'Segurar o texto para revisão manual';

  @override
  String get profileZhToEnName => 'ZH → EN';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => 'Traduzir → EN';

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
  String get shellAlreadyRecording => 'O Shinsoku já está gravando.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return 'Pós-processamento de texto ativado para $profile.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return 'O ajuste de pós-processamento não foi salvo. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'Não foi possível copiar o texto. $reason';
  }

  @override
  String get failureTimeout =>
      'O provedor demorou demais para responder. Verifique a conexão e tente de novo.';

  @override
  String get failureNetwork =>
      'Sem conexão com o provedor. Verifique a rede e tente de novo.';

  @override
  String get failureConnectionLost => 'A conexão caiu. Tente de novo.';

  @override
  String get failureKeyMissing =>
      'Nenhuma chave de API salva. Adicione uma em Ajustes.';

  @override
  String get failureKeyInvalid =>
      'O provedor não aceitou sua chave de API. Verifique-a em Ajustes.';

  @override
  String get failureQuota =>
      'O provedor informa que a cota acabou ou que há solicitações demais. Verifique sua conta.';

  @override
  String get failureNothingHeard =>
      'Nenhuma fala foi reconhecida. Tente de novo.';

  @override
  String get failureRecording =>
      'Não foi possível concluir a gravação. Tente de novo.';

  @override
  String get failureMicrophone =>
      'O microfone não está disponível. Verifique o acesso ao microfone em Ajustes.';

  @override
  String get failureGeneric => 'Algo deu errado. Tente de novo.';

  @override
  String get nearbyTitle => 'Microfone do computador';

  @override
  String get nearbySubtitle => 'Conexão local privada';

  @override
  String get nearbySectionDesktop => 'Computador';

  @override
  String get nearbyFindDesktops => 'Buscar computadores';

  @override
  String get nearbyAddManually => 'Adicionar computador manualmente';

  @override
  String get nearbyEndpointLabel => 'Endereço WSS';

  @override
  String get nearbyCertificateLabel => 'SHA-256 do certificado';

  @override
  String get nearbyAdd => 'Adicionar';

  @override
  String get nearbySectionTrust => 'Confiança';

  @override
  String get nearbyTrustedDesktop => 'Computador confiável';

  @override
  String get nearbyCertificateFingerprint => 'Impressão digital do certificado';

  @override
  String get nearbyMatchesTitle => 'Igual à do computador';

  @override
  String get nearbyMatchesSubtitle => 'Compare com os ajustes no computador';

  @override
  String get nearbyPairingCodeLabel => 'Código de pareamento do computador';

  @override
  String get nearbyDisconnect => 'Desconectar';

  @override
  String get nearbyConnect => 'Conectar';

  @override
  String get nearbyPairAndConnect => 'Parear e conectar';

  @override
  String get nearbyForget => 'Esquecer computador';

  @override
  String get nearbySectionRemoteInput => 'Entrada remota';

  @override
  String get nearbyProfileRow => 'Perfil';

  @override
  String get nearbyProfileAutomatic => 'Automático (computador)';

  @override
  String get nearbyProfileSheetTitle => 'Perfil do computador';

  @override
  String get nearbyStopAndTranscribe => 'Parar e transcrever';

  @override
  String get nearbyStartRemote => 'Começar ditado remoto';

  @override
  String get nearbyConnectToDictate =>
      'Conecte-se a um computador para ditar nele';

  @override
  String nearbyConnectingTo(String name) {
    return 'Conectando a $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return 'Conectado a $name';
  }

  @override
  String get nearbyStreaming => 'Transmitindo o áudio do microfone';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Transmitindo com $countString quadros perdidos',
      one: 'Transmitindo com 1 quadro perdido',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => 'Gravação enviada ao computador';

  @override
  String get nearbyNotConnected => 'Não conectado';

  @override
  String get nearbyDisconnected => 'Computador desconectado';

  @override
  String get nearbySearching => 'Buscando na rede local';

  @override
  String get nearbyNoneFound => 'Nenhum computador com Shinsoku encontrado';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString computadores encontrados',
      one: '1 computador encontrado',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => 'Computador confiável selecionado';

  @override
  String get nearbyVerifyFingerprint =>
      'Confira a impressão digital do computador';

  @override
  String get nearbyTrustRemoved => 'Confiança local removida';

  @override
  String get nearbyErrorPairingCodeRequired =>
      'Digite o código de dois dígitos mostrado no computador.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      'A impressão digital do certificado é inválida. Digite todos os 64 caracteres hexadecimais.';

  @override
  String get nearbyErrorEndpointInvalid =>
      'Digite um host e uma porta wss:// válidos.';

  @override
  String get nearbyErrorCertificateChanged =>
      'O certificado do computador mudou. Esqueça-o e pareie de novo.';

  @override
  String get nearbyErrorCredentialMissing =>
      'O computador lembra deste dispositivo, mas a credencial local sumiu. Revogue-a no computador e pareie de novo.';

  @override
  String get nearbyErrorPairingUnavailable =>
      'Crie um código de pareamento nos ajustes do computador e conecte de novo.';

  @override
  String get nearbyErrorPairingExpired =>
      'O código de pareamento expirou. Crie um novo.';

  @override
  String get nearbyErrorWrongCode => 'O código de pareamento está incorreto.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'As tentativas de pareamento acabaram. Crie um novo código no computador.';

  @override
  String get nearbyErrorDesktopBusy =>
      'O computador já está gravando ou processando áudio.';

  @override
  String get nearbyErrorConnectFirst =>
      'Conecte-se a um computador antes de gravar.';

  @override
  String get nearbyErrorTimeout => 'O computador não respondeu a tempo.';

  @override
  String get nearbyErrorConnectionLost => 'A conexão com o computador caiu.';

  @override
  String get nearbyErrorMicDenied =>
      'É preciso acesso ao microfone. Permita em Ajustes.';

  @override
  String get nearbyErrorRecorderNotReady =>
      'O microfone não está pronto. Tente de novo.';

  @override
  String get nearbyErrorMicStream => 'O microfone parou inesperadamente.';

  @override
  String get nearbyErrorDiscovery =>
      'Não foi possível buscar na rede local. Verifique o Wi-Fi e tente de novo.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'O computador enviou uma resposta inesperada. Atualize o Shinsoku nos dois dispositivos e tente de novo.';

  @override
  String get nearbyErrorGeneric =>
      'Algo deu errado com a conexão ao computador.';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDelete => 'Apagar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonDone => 'OK';

  @override
  String get commonClear => 'Limpar';

  @override
  String get commonUndo => 'Desfazer';

  @override
  String get commonOpenSettings => 'Abrir Ajustes';

  @override
  String get tabRecord => 'Gravar';

  @override
  String get tabDrafts => 'Rascunhos';

  @override
  String get tabDesktop => 'Computador';

  @override
  String get tabSettings => 'Ajustes';

  @override
  String get paneSwitcherLabel => 'Painel';

  @override
  String get recordPlaceholder => 'Toque no microfone e comece a falar.';

  @override
  String get recordListeningPlaceholder => 'Ouvindo…';

  @override
  String get recordProcessing => 'Processando…';

  @override
  String get recordTranscriptLabel => 'Texto';

  @override
  String get recordCopied => 'Copiado. Insira pelo teclado ou cole.';

  @override
  String get recordSavedInsert => 'Salvo. Insira pelo teclado.';

  @override
  String get recordResultCopied =>
      'Copiado. Cole onde quiser ou insira pelo teclado.';

  @override
  String get recordStopped => 'Gravação interrompida';

  @override
  String get recordHeardTextKept =>
      'O que foi ouvido fica guardado aqui e em Rascunhos.';

  @override
  String get recordTryAgain => 'Gravar de novo';

  @override
  String get recordStatusReady => 'Pronto para gravar';

  @override
  String get recordStatusListening => 'Ouvindo';

  @override
  String get recordStatusListeningDetail =>
      'Toque em parar quando terminar de falar.';

  @override
  String get recordStatusTranscribing => 'Transcrevendo';

  @override
  String get recordTranscribed => 'Gravação transcrita';

  @override
  String get recordTranscribingDetail =>
      'Enviando o áudio gravado ao provedor selecionado.';

  @override
  String get recordFailed => 'Falha na gravação';

  @override
  String get recordMicOffLabel => 'O acesso ao microfone está desativado';

  @override
  String get recordMicOffDetail =>
      'Permita o acesso ao microfone nos Ajustes do iOS e grave de novo.';

  @override
  String get recordRecorderNotReady =>
      'O microfone foi permitido, mas o gravador não está pronto. Tente de novo.';

  @override
  String get recordKeyRequiredLabel => 'Configure o provedor';

  @override
  String get recordKeyRequiredDetail =>
      'Salve uma chave de API do Bailian ou do Soniox antes de gravar.';

  @override
  String get recordProfileLabel => 'Perfil';

  @override
  String get recordButtonStart => 'Começar a gravar';

  @override
  String get recordButtonStop => 'Parar de gravar';

  @override
  String get recordButtonUnavailable => 'Gravação indisponível';

  @override
  String profileReasonLine(String name, String why) {
    return '$name · $why';
  }

  @override
  String get profileReasonManual => 'escolhido por você';

  @override
  String get profileReasonAutomation => 'definido por automação';

  @override
  String get profileReasonDefault => 'padrão';

  @override
  String get draftsTitle => 'Rascunhos';

  @override
  String get draftsEmpty => 'Seus textos aparecem aqui depois que você gravar.';

  @override
  String get draftsToday => 'Hoje';

  @override
  String get draftsYesterday => 'Ontem';

  @override
  String get draftsCopyDraft => 'Copiar rascunho';

  @override
  String get draftsDeleted => 'Rascunho apagado';

  @override
  String get draftsCopied => 'Rascunho copiado para a área de transferência.';

  @override
  String get draftEditorTitle => 'Rascunho';

  @override
  String draftEditorCaptured(String time, String profile) {
    return '$time · $profile';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionRecognition => 'Reconhecimento';

  @override
  String get settingsMicrophoneTitle => 'Acesso ao microfone';

  @override
  String get settingsMicrophoneAllowed => 'Permitido para entrada de voz';

  @override
  String get settingsMicrophoneTapToAllow =>
      'Toque para permitir o acesso ao microfone';

  @override
  String get settingsSpeechProvider => 'Provedor de voz';

  @override
  String get settingsPostProcessingTitle => 'Pós-processamento de texto';

  @override
  String settingsPostProcessingSubtitle(String model) {
    return 'Usar $model para limpar ou traduzir';
  }

  @override
  String get settingsCloudTitle => 'Processamento na nuvem';

  @override
  String get settingsCloudSaved => 'As credenciais do provedor estão salvas';

  @override
  String get settingsCloudNotSaved =>
      'Salve as credenciais antes de transcrever de verdade';

  @override
  String get settingsLoading => 'Carregando os ajustes salvos';

  @override
  String get settingsRealtimeModel => 'Modelo em tempo real';

  @override
  String get settingsRecognitionMode => 'Modo de reconhecimento';

  @override
  String get settingsModeStreaming => 'Streaming';

  @override
  String get settingsStreamingModel => 'Modelo ASR em streaming';

  @override
  String get settingsBatchModel => 'Modelo em lote do Qwen-ASR';

  @override
  String get settingsPostProcessingModel =>
      'Modelo OpenAI de pós-processamento';

  @override
  String get settingsPostProcessingModelHelper =>
      'Usado só com o pós-processamento de texto ativado';

  @override
  String get settingsBaseUrl => 'URL base compatível com OpenAI';

  @override
  String get settingsRealtimeUrl => 'URL do WebSocket em tempo real';

  @override
  String get settingsSave => 'Salvar Ajustes';

  @override
  String get settingsSaving => 'Salvando';

  @override
  String get settingsSaved => 'Ajustes do provedor salvos';

  @override
  String settingsSaveFailed(String reason) {
    return 'Os ajustes não foram salvos. $reason';
  }

  @override
  String get settingsSectionProfiles => 'Perfis';

  @override
  String get settingsAddProfile => 'Adicionar perfil';

  @override
  String get settingsUseInApps => 'Usar nos apps';

  @override
  String get settingsUseInAppsSubtitle => 'Trocar de perfil ao abrir um app';

  @override
  String get settingsFieldRules => 'Regras de campo';

  @override
  String get settingsFieldRulesSubtitle =>
      'Busca, endereço web, e-mail, mensagem';

  @override
  String get settingsSectionKeyboard => 'Teclado';

  @override
  String get settingsKeyboardSetup => 'Configurar teclado';

  @override
  String get settingsKeyboardSetupSubtitle =>
      'Adicione o Shinsoku e permita o Acesso Total';

  @override
  String get settingsApiKey => 'Chave de API';

  @override
  String get settingsShowKey => 'Mostrar chave';

  @override
  String get settingsHideKey => 'Ocultar chave';

  @override
  String get keyboardSetupTitle => 'Teclado';

  @override
  String get keyboardSetupIntro => 'Use o Shinsoku em qualquer campo de texto.';

  @override
  String get keyboardStep1 => 'Abra Ajustes › Geral › Teclado › Teclados.';

  @override
  String get keyboardStep2 =>
      'Toque em “Adicionar Novo Teclado” e escolha Shinsoku.';

  @override
  String get keyboardStep3 =>
      'Toque em Shinsoku e ative “Permitir Acesso Total” para o teclado poder inserir seu texto mais recente.';

  @override
  String get useInAppsSummary =>
      'O Shinsoku pode trocar de perfil sozinho quando você abre um app. O Atalhos detecta o app, e o Shinsoku define o perfil.';

  @override
  String get useInAppsWhenOpened => 'Quando o app é aberto';

  @override
  String get useInAppsWhenClosed => 'Quando o app é fechado';

  @override
  String get useInAppsOpenStep1 =>
      'No Atalhos, abra Automação e toque em “Nova Automação”.';

  @override
  String get useInAppsOpenStep2 =>
      'Escolha “App”, selecione o app e marque “É Aberto”. Ative “Executar Imediatamente”.';

  @override
  String get useInAppsOpenStep3 =>
      'Adicione a ação “Definir Perfil do Shinsoku” e escolha o perfil para esse app.';

  @override
  String get useInAppsCloseStep1 =>
      'Adicione uma segunda automação para o mesmo app e marque “É Fechado”. Ative “Executar Imediatamente”.';

  @override
  String get useInAppsCloseStep2 =>
      'Adicione “Definir Perfil do Shinsoku” e escolha seu perfil padrão, para que os outros apps voltem a ele.';

  @override
  String get useInAppsKeyboardNote =>
      'Você também pode tocar no nome do perfil no teclado para trocar. Ele fica até uma automação rodar de novo.';

  @override
  String get useInAppsReadyMade =>
      'Cada perfil também tem uma ação pronta no app Atalhos, como “Mudar Shinsoku para Conversa”. Não precisa configurar nada.';

  @override
  String get useInAppsIosNote =>
      'As ações do Atalhos precisam do iOS 16 ou posterior.';

  @override
  String get useInAppsOpenShortcuts => 'Abrir Atalhos';

  @override
  String get fieldRulesTitle => 'Regras de campo';

  @override
  String get fieldRulesSummary =>
      'Use um perfil automaticamente em certos tipos de campo. Só vale quando você não escolheu um perfil no teclado e nenhuma automação definiu um.';

  @override
  String get fieldRulesNone => 'Nenhum';

  @override
  String get fieldKindSearch => 'Busca';

  @override
  String get fieldKindUrl => 'Endereço web';

  @override
  String get fieldKindEmail => 'E-mail';

  @override
  String get fieldKindMessage => 'Mensagem';

  @override
  String get profileNewTitle => 'Novo perfil';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileNameLabel => 'Nome';

  @override
  String get profilePromptLabel => 'Instrução de pós-processamento';

  @override
  String get profilePromptHelper =>
      'Exemplo: Traduza a fala em português para um inglês natural.';

  @override
  String get profileAfterText => 'Depois do texto';

  @override
  String get profileSuffixNothing => 'Nada';

  @override
  String get profileSuffixSpace => 'Espaço';

  @override
  String get profileSuffixNewLine => 'Nova linha';

  @override
  String get profileAutoCommit => 'Inserir automaticamente';

  @override
  String get profileAutoCommitSubtitle => 'Inserir sem etapa de revisão';

  @override
  String get profileDelete => 'Apagar perfil';

  @override
  String profileDeleteConfirm(String name) {
    return 'Apagar “$name”?';
  }

  @override
  String get profileKeepOne => 'Mantenha pelo menos um perfil';

  @override
  String get profileUntitled => 'Sem título';

  @override
  String get profileDefaultIntent =>
      'Limpe a transcrição. Retorne só o texto final.';

  @override
  String get profileDictationName => 'Ditado';

  @override
  String get profileDictationIntent => 'Transformar a fala em um texto natural';

  @override
  String get profileChatName => 'Conversa';

  @override
  String get profileChatIntent => 'Deixar o texto curto e informal';

  @override
  String get profileReviewName => 'Revisar';

  @override
  String get profileReviewIntent => 'Segurar o texto para revisão manual';

  @override
  String get profileZhToEnName => 'ZH → EN';

  @override
  String get profileZhToEnIntent =>
      'Translate Chinese speech into natural English. Preserve the meaning, keep it concise, and return only the English text.';

  @override
  String get profileTranslateToEnName => 'Traduzir → EN';

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
  String get shellAlreadyRecording => 'O Shinsoku já está gravando.';

  @override
  String shellPostProcessingEnabled(String profile) {
    return 'Pós-processamento de texto ativado para $profile.';
  }

  @override
  String shellPostProcessingNotSaved(String reason) {
    return 'O ajuste de pós-processamento não foi salvo. $reason';
  }

  @override
  String shellClipboardFailed(String reason) {
    return 'Não foi possível copiar o texto. $reason';
  }

  @override
  String get failureTimeout =>
      'O provedor demorou demais para responder. Verifique a conexão e tente de novo.';

  @override
  String get failureNetwork =>
      'Sem conexão com o provedor. Verifique a rede e tente de novo.';

  @override
  String get failureConnectionLost => 'A conexão caiu. Tente de novo.';

  @override
  String get failureKeyMissing =>
      'Nenhuma chave de API salva. Adicione uma em Ajustes.';

  @override
  String get failureKeyInvalid =>
      'O provedor não aceitou sua chave de API. Verifique-a em Ajustes.';

  @override
  String get failureQuota =>
      'O provedor informa que a cota acabou ou que há solicitações demais. Verifique sua conta.';

  @override
  String get failureNothingHeard =>
      'Nenhuma fala foi reconhecida. Tente de novo.';

  @override
  String get failureRecording =>
      'Não foi possível concluir a gravação. Tente de novo.';

  @override
  String get failureMicrophone =>
      'O microfone não está disponível. Verifique o acesso ao microfone em Ajustes.';

  @override
  String get failureGeneric => 'Algo deu errado. Tente de novo.';

  @override
  String get nearbyTitle => 'Microfone do computador';

  @override
  String get nearbySubtitle => 'Conexão local privada';

  @override
  String get nearbySectionDesktop => 'Computador';

  @override
  String get nearbyFindDesktops => 'Buscar computadores';

  @override
  String get nearbyAddManually => 'Adicionar computador manualmente';

  @override
  String get nearbyEndpointLabel => 'Endereço WSS';

  @override
  String get nearbyCertificateLabel => 'SHA-256 do certificado';

  @override
  String get nearbyAdd => 'Adicionar';

  @override
  String get nearbySectionTrust => 'Confiança';

  @override
  String get nearbyTrustedDesktop => 'Computador confiável';

  @override
  String get nearbyCertificateFingerprint => 'Impressão digital do certificado';

  @override
  String get nearbyMatchesTitle => 'Igual à do computador';

  @override
  String get nearbyMatchesSubtitle => 'Compare com os ajustes no computador';

  @override
  String get nearbyPairingCodeLabel => 'Código de pareamento do computador';

  @override
  String get nearbyDisconnect => 'Desconectar';

  @override
  String get nearbyConnect => 'Conectar';

  @override
  String get nearbyPairAndConnect => 'Parear e conectar';

  @override
  String get nearbyForget => 'Esquecer computador';

  @override
  String get nearbySectionRemoteInput => 'Entrada remota';

  @override
  String get nearbyProfileRow => 'Perfil';

  @override
  String get nearbyProfileAutomatic => 'Automático (computador)';

  @override
  String get nearbyProfileSheetTitle => 'Perfil do computador';

  @override
  String get nearbyStopAndTranscribe => 'Parar e transcrever';

  @override
  String get nearbyStartRemote => 'Começar ditado remoto';

  @override
  String get nearbyConnectToDictate =>
      'Conecte-se a um computador para ditar nele';

  @override
  String nearbyConnectingTo(String name) {
    return 'Conectando a $name';
  }

  @override
  String nearbyConnectedTo(String name) {
    return 'Conectado a $name';
  }

  @override
  String get nearbyStreaming => 'Transmitindo o áudio do microfone';

  @override
  String nearbyStreamingGaps(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Transmitindo com $countString quadros perdidos',
      one: 'Transmitindo com 1 quadro perdido',
    );
    return '$_temp0';
  }

  @override
  String get nearbyRecordingSent => 'Gravação enviada ao computador';

  @override
  String get nearbyNotConnected => 'Não conectado';

  @override
  String get nearbyDisconnected => 'Computador desconectado';

  @override
  String get nearbySearching => 'Buscando na rede local';

  @override
  String get nearbyNoneFound => 'Nenhum computador com Shinsoku encontrado';

  @override
  String nearbyDesktopsFound(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString computadores encontrados',
      one: '1 computador encontrado',
    );
    return '$_temp0';
  }

  @override
  String get nearbyTrustedSelected => 'Computador confiável selecionado';

  @override
  String get nearbyVerifyFingerprint =>
      'Confira a impressão digital do computador';

  @override
  String get nearbyTrustRemoved => 'Confiança local removida';

  @override
  String get nearbyErrorPairingCodeRequired =>
      'Digite o código de dois dígitos mostrado no computador.';

  @override
  String get nearbyErrorFingerprintInvalid =>
      'A impressão digital do certificado é inválida. Digite todos os 64 caracteres hexadecimais.';

  @override
  String get nearbyErrorEndpointInvalid =>
      'Digite um host e uma porta wss:// válidos.';

  @override
  String get nearbyErrorCertificateChanged =>
      'O certificado do computador mudou. Esqueça-o e pareie de novo.';

  @override
  String get nearbyErrorCredentialMissing =>
      'O computador lembra deste dispositivo, mas a credencial local sumiu. Revogue-a no computador e pareie de novo.';

  @override
  String get nearbyErrorPairingUnavailable =>
      'Crie um código de pareamento nos ajustes do computador e conecte de novo.';

  @override
  String get nearbyErrorPairingExpired =>
      'O código de pareamento expirou. Crie um novo.';

  @override
  String get nearbyErrorWrongCode => 'O código de pareamento está incorreto.';

  @override
  String get nearbyErrorAttemptsExhausted =>
      'As tentativas de pareamento acabaram. Crie um novo código no computador.';

  @override
  String get nearbyErrorDesktopBusy =>
      'O computador já está gravando ou processando áudio.';

  @override
  String get nearbyErrorConnectFirst =>
      'Conecte-se a um computador antes de gravar.';

  @override
  String get nearbyErrorTimeout => 'O computador não respondeu a tempo.';

  @override
  String get nearbyErrorConnectionLost => 'A conexão com o computador caiu.';

  @override
  String get nearbyErrorMicDenied =>
      'É preciso acesso ao microfone. Permita em Ajustes.';

  @override
  String get nearbyErrorRecorderNotReady =>
      'O microfone não está pronto. Tente de novo.';

  @override
  String get nearbyErrorMicStream => 'O microfone parou inesperadamente.';

  @override
  String get nearbyErrorDiscovery =>
      'Não foi possível buscar na rede local. Verifique o Wi-Fi e tente de novo.';

  @override
  String get nearbyErrorUnexpectedResponse =>
      'O computador enviou uma resposta inesperada. Atualize o Shinsoku nos dois dispositivos e tente de novo.';

  @override
  String get nearbyErrorGeneric =>
      'Algo deu errado com a conexão ao computador.';
}
