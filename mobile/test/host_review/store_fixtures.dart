// Store screenshot fixtures (release-01 R3): believable text in each store
// locale's own language. No real names or hosts (desktops are example-*), no
// keys. Keys are store locales (docs/store/metadata/<locale>.yaml).

/// One locale's fixture text.
class StoreText {
  const StoreText({
    required this.liveCommitted,
    required this.livePending,
    required this.result,
    required this.errand,
    required this.weekend,
    required this.email,
    required this.emailProfileName,
    required this.emailProfileIntent,
  });

  /// Record, mid-sentence: words already final, then the interim words.
  final String liveCommitted;
  final String livePending;

  /// The cleaned text after the recording (also the newest draft).
  final String result;

  /// Older drafts: a chat message, a note, an email.
  final String errand;
  final String weekend;
  final String email;

  /// The custom (Pro) profile.
  final String emailProfileName;
  final String emailProfileIntent;
}

/// Spoken in the device language, kept as English by the translation profile.
const translatedDraft =
    'Could we move our call to Friday morning? Thursday is fully booked.';

/// App locale tag (as tool/host_review.sh takes it) for a store locale.
const storeAppLocale = {
  'en-US': 'en',
  'zh-Hans': 'zh-Hans',
  'zh-Hant': 'zh-Hant',
  'ja': 'ja',
  'ko': 'ko',
  'de-DE': 'de',
  'fr-FR': 'fr',
  'es-ES': 'es',
  'pt-BR': 'pt-BR',
  'it': 'it',
};

const storeText = <String, StoreText>{
  'en-US': StoreText(
    liveCommitted:
        'Quick update for the team: the launch moves to Thursday, so let’s ',
    livePending: 'finish the release notes by Wednesday',
    result:
        'Quick update for the team: the launch moves to Thursday, so let’s '
        'finish the release notes by Wednesday afternoon.',
    errand: 'Can you pick up oat milk and bread on the way home?',
    weekend:
        'Ideas for the weekend: farmers’ market in the morning, then a long '
        'walk by the river.',
    email:
        'Thank you for the quick reply. I’ve attached the updated invoice and '
        'will call you on Monday.',
    emailProfileName: 'Polite email',
    emailProfileIntent: 'Turn my notes into a polite, well-structured email',
  ),
  'zh-Hans': StoreText(
    liveCommitted: '跟大家同步一下：发布改到周四，所以我们',
    livePending: '周三下午之前把更新说明',
    result: '跟大家同步一下：发布改到周四，所以我们周三下午之前要把更新说明写完。',
    errand: '回家路上帮我买一下燕麦奶和面包。',
    weekend: '周末计划：上午去逛集市，下午沿着河边散散步。',
    email: '感谢您的及时回复。更新后的发票已附上，周一我再给您打电话。',
    emailProfileName: '正式邮件',
    emailProfileIntent: '把我的要点写成礼貌、条理清楚的邮件',
  ),
  'zh-Hant': StoreText(
    liveCommitted: '跟大家同步一下：發布改到週四，所以我們',
    livePending: '週三下午之前把更新說明',
    result: '跟大家同步一下：發布改到週四，所以我們週三下午之前要把更新說明寫完。',
    errand: '回家路上幫我買一下燕麥奶和麵包。',
    weekend: '週末計畫：上午去逛市集，下午沿著河邊散散步。',
    email: '感謝您的及時回覆。更新後的發票已附上，週一我再打電話給您。',
    emailProfileName: '正式郵件',
    emailProfileIntent: '把我的重點寫成禮貌、條理清楚的郵件',
  ),
  'ja': StoreText(
    liveCommitted: 'チームの皆さんへ。リリースは木曜日に変更になったので、',
    livePending: '水曜日の午後までにリリースノートを',
    result: 'チームの皆さんへ。リリースは木曜日に変更になったので、水曜日の午後までにリリースノートを仕上げましょう。',
    errand: '帰りにオーツミルクとパンを買ってきてもらえる？',
    weekend: '週末の予定：午前中はマルシェ、午後は川沿いをゆっくり散歩。',
    email: '早速のご返信ありがとうございます。更新した請求書を添付しましたので、月曜日にお電話いたします。',
    emailProfileName: '丁寧なメール',
    emailProfileIntent: 'メモから丁寧で読みやすいメールを作成',
  ),
  'ko': StoreText(
    liveCommitted: '팀 공지입니다. 출시가 목요일로 바뀌었으니 ',
    livePending: '수요일 오후까지 릴리스 노트를',
    result: '팀 공지입니다. 출시가 목요일로 바뀌었으니 수요일 오후까지 릴리스 노트를 마무리해 주세요.',
    errand: '집에 오는 길에 귀리 우유랑 빵 좀 사다 줄래?',
    weekend: '주말 계획: 오전에는 장터 구경, 오후에는 강변 산책.',
    email: '빠른 회신 감사합니다. 수정된 청구서를 첨부했으며, 월요일에 전화드리겠습니다.',
    emailProfileName: '정중한 이메일',
    emailProfileIntent: '메모를 정중하고 깔끔한 이메일로 정리',
  ),
  'de-DE': StoreText(
    liveCommitted:
        'Kurzes Update fürs Team: Der Launch ist jetzt am Donnerstag, also '
        'lasst uns ',
    livePending: 'die Release Notes bis Mittwoch',
    result:
        'Kurzes Update fürs Team: Der Launch ist jetzt am Donnerstag, also '
        'lasst uns die Release Notes bis Mittwochnachmittag fertigstellen.',
    errand: 'Kannst du auf dem Heimweg Haferdrink und Brot mitbringen?',
    weekend:
        'Pläne fürs Wochenende: morgens auf den Wochenmarkt, danach ein '
        'langer Spaziergang am Fluss.',
    email:
        'Vielen Dank für Ihre schnelle Antwort. Die aktualisierte Rechnung '
        'finden Sie im Anhang, ich rufe Sie am Montag an.',
    emailProfileName: 'Förmliche E-Mail',
    emailProfileIntent: 'Höfliche E-Mail aus meinen Stichpunkten',
  ),
  'fr-FR': StoreText(
    liveCommitted:
        'Petit point pour l’équipe : le lancement passe à jeudi, donc ',
    livePending: 'finissons les notes de version',
    result:
        'Petit point pour l’équipe : le lancement passe à jeudi, donc '
        'finissons les notes de version d’ici mercredi après-midi.',
    errand: 'Tu peux prendre du lait d’avoine et du pain en rentrant ?',
    weekend:
        'Programme du week-end : marché le matin, puis une longue balade '
        'au bord de la rivière.',
    email:
        'Merci pour votre réponse rapide. Vous trouverez ci-joint la facture '
        'mise à jour ; je vous appelle lundi.',
    emailProfileName: 'E-mail formel',
    emailProfileIntent: 'Un e-mail poli à partir de mes notes',
  ),
  'es-ES': StoreText(
    liveCommitted:
        'Una actualización para el equipo: el lanzamiento pasa al jueves, así '
        'que ',
    livePending: 'terminemos las notas de la versión',
    result:
        'Una actualización para el equipo: el lanzamiento pasa al jueves, así '
        'que terminemos las notas de la versión antes del miércoles por la '
        'tarde.',
    errand: '¿Puedes comprar leche de avena y pan de camino a casa?',
    weekend:
        'Plan para el fin de semana: mercado por la mañana y después un paseo '
        'largo junto al río.',
    email:
        'Gracias por su rápida respuesta. Le adjunto la factura actualizada y '
        'le llamo el lunes.',
    emailProfileName: 'Correo formal',
    emailProfileIntent: 'Un correo amable a partir de mis notas',
  ),
  'pt-BR': StoreText(
    liveCommitted:
        'Atualização rápida para o time: o lançamento mudou para quinta, então '
        'vamos ',
    livePending: 'fechar as notas da versão',
    result:
        'Atualização rápida para o time: o lançamento mudou para quinta, então '
        'vamos fechar as notas da versão até quarta à tarde.',
    errand: 'Você pode comprar leite de aveia e pão no caminho de casa?',
    weekend:
        'Planos para o fim de semana: feira de manhã e depois uma longa '
        'caminhada à beira do rio.',
    email:
        'Obrigado pela resposta rápida. Segue em anexo a fatura atualizada; '
        'ligo para você na segunda.',
    emailProfileName: 'E-mail formal',
    emailProfileIntent: 'Um e-mail educado a partir das minhas notas',
  ),
  'it': StoreText(
    liveCommitted:
        'Aggiornamento veloce per il team: il lancio slitta a giovedì, quindi ',
    livePending: 'chiudiamo le note di rilascio',
    result:
        'Aggiornamento veloce per il team: il lancio slitta a giovedì, quindi '
        'chiudiamo le note di rilascio entro mercoledì pomeriggio.',
    errand: 'Puoi prendere latte d’avena e pane tornando a casa?',
    weekend:
        'Programma per il weekend: mercato la mattina, poi una lunga '
        'passeggiata lungo il fiume.',
    email:
        'Grazie per la rapida risposta. In allegato trova la fattura '
        'aggiornata; la chiamo lunedì.',
    emailProfileName: 'E-mail formale',
    emailProfileIntent: 'Un’e-mail cortese dai miei appunti',
  ),
};
