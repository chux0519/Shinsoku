# Shinsoku glossary (i18n-01 I5)

One term, one translation per language. ARB files (`mobile/lib/l10n/app_<tag>.arb`), the native catalogs
(`mobile/ios/**/*.xcstrings`) and `AppShortcuts.strings` follow this table. Change a term here first, then
everywhere it is used.

**Tone:** short, plain, friendly — like Apple's own UI in that language. Sentences end the way Apple ends them
(ja: です/ます is avoided in labels, used in full sentences; ko: 해요체 in sentences, nouns in labels; de/fr/es/
pt-BR/it: the form Apple's own iOS text uses — de "du", es "tú", pt-BR "você", it "tu", fr "vous").

**Variants:** `zh-Hant` uses Taiwan wording (HK falls back to it). `zh-Hans` targets Singapore, Malaysia and
overseas readers: mainland-neutral, no mainland-only slang. `pt-BR` is also the `pt` fallback. `es` is neutral
Spanish (Apple's `es` wording: *Ajustes*, *Añadir*).

**Never translated:** Shinsoku, Shinsoku Pro, Pro (badge), Bailian, Soniox, Qwen-ASR, Fun-ASR, OpenAI, WebSocket, WSS, `wss://`, SHA-256,
API key (kept as "API" + the local word for key), Wi-Fi (de: WLAN, as on iOS), iOS.

## Product terms

| English | ja | zh-Hant | ko | de | es | zh-Hans | fr | pt-BR | it |
|---|---|---|---|---|---|---|---|---|---|
| profile | プロファイル | 模式 | 프로필 | Profil | perfil | 模式 | profil | perfil | profilo |
| field rule | 入力欄ルール | 欄位規則 | 입력란 규칙 | Feldregel | regla de campo | 输入框规则 | règle de champ | regra de campo | regola del campo |
| draft | 下書き | 草稿 | 초안 | Entwurf | borrador | 草稿 | brouillon | rascunho | bozza |
| insert (text) | 挿入 | 插入 | 삽입 | einfügen | insertar | 插入 | insérer | inserir | inserire |
| record / recording | 録音 | 錄音 | 녹음 | aufnehmen / Aufnahme | grabar / grabación | 录音 | enregistrer / enregistrement | gravar / gravação | registrare / registrazione |
| Record (tab, Record key) | 録音 | 錄音 | 녹음 | Aufnahme | Grabar | 录音 | Dicter | Gravar | Registra |
| transcript | テキスト | 文字 | 텍스트 | Text | texto | 文本 | texte | texto | testo |
| transcribe | 文字起こし | 轉成文字 | 텍스트로 변환 | transkribieren | transcribir | 转写 | transcrire | transcrever | trascrivere |
| post-processing | 後処理 | 後處理 | 후처리 | Nachbearbeitung | posprocesado | 后处理 | post-traitement | pós-processamento | post-elaborazione |
| speech provider | 音声認識サービス | 語音辨識服務 | 음성 인식 서비스 | Spracherkennungsdienst | proveedor de voz | 语音识别服务 | service de reconnaissance vocale | provedor de voz | servizio vocale |
| recognition | 音声認識 | 語音辨識 | 음성 인식 | Spracherkennung | reconocimiento | 语音识别 | reconnaissance | reconhecimento | riconoscimento |
| streaming (mode) | ストリーミング | 串流 | 스트리밍 | Streaming | streaming | 流式 | streaming | streaming | streaming |
| keyboard | キーボード | 鍵盤 | 키보드 | Tastatur | teclado | 键盘 | clavier | teclado | tastiera |
| Desktop (tab: phone as a mic for a computer) | デスクトップ | 電腦 | 데스크톱 | Computer | Ordenador | 电脑 | Ordinateur | Computador | Computer |
| Desktop Mic | デスクトップマイク | 電腦麥克風 | 데스크톱 마이크 | Computer-Mikro | Micro para ordenador | 电脑麦克风 | Micro pour ordinateur | Microfone do computador | Microfono per computer |
| pair / pairing code | ペアリング / ペアリングコード | 配對 / 配對碼 | 페어링 / 페어링 코드 | koppeln / Kopplungscode | vincular / código de vinculación | 配对 / 配对码 | jumeler / code de jumelage | parear / código de pareamento | abbinare / codice di abbinamento |
| fingerprint (certificate) | フィンガープリント | 指紋 | 지문 | Fingerabdruck | huella digital | 指纹 | empreinte | impressão digital | impronta |
| microphone | マイク | 麥克風 | 마이크 | Mikrofon | micrófono | 麦克风 | micro | microfone | microfono |
| unlock (Pro) | ロック解除 / 購入 (button) | 解鎖 | 잠금 해제 | freischalten | desbloquear | 解锁 | débloquer | desbloquear | sbloccare |
| custom profiles | カスタムプロファイル | 自訂模式 | 사용자 프로필 | eigene Profile | perfiles propios | 自定模式 | profils personnalisés | perfis personalizados | profili personalizzati |
| automation | オートメーション | 自動化操作 | 자동화 | Automation | automatización | 自动化 | automatisation | automação | automazione |

## Built-in profile names

| English | ja | zh-Hant | ko | de | es | zh-Hans | fr | pt-BR | it |
|---|---|---|---|---|---|---|---|---|---|
| Dictation | 音声入力 | 聽寫 | 받아쓰기 | Diktat | Dictado | 听写 | Dictée | Ditado | Dettatura |
| Chat | チャット | 聊天 | 채팅 | Chat | Chat | 聊天 | Discussion | Conversa | Chat |
| Review | 確認 | 檢查 | 검토 | Prüfen | Revisar | 检查 | Relecture | Revisar | Revisione |
| ZH -> EN | 中→英 | 中→英 | 중→영 | ZH → EN | ZH → EN | 中→英 | ZH → EN | ZH → EN | ZH → EN |
| Translate -> EN | 翻訳→英 | 翻譯→英 | 번역→영 | Übersetzen → EN | Traducir → EN | 翻译→英 | Traduire → EN | Traduzir → EN | Traduci → EN |
| JA / KO / DE / ES / FR / PT / IT -> EN | 日→英 | — | 한→영 | DE → EN | ES → EN | — | FR → EN | PT → EN | IT → EN |

Translation profile description in the profile list (`profileTranslationDescription`; the instruction sent to the
model stays English): ja 話した内容を英語に翻訳 · zh-Hant 把說的話翻譯成英文 · ko 말한 내용을 영어로 번역 ·
de Gesprochenes ins Englische übersetzen · es Traducir lo hablado al inglés · zh-Hans 把说的话翻译成英文 ·
fr Traduire la parole en anglais · pt-BR Traduzir a fala para o inglês · it Tradurre il parlato in inglese.

Only the translation profile of the device's own language is created (I3), so each language needs only its own
short form; the rest are filled for completeness (e.g. ja `韓→英`, zh `日→英`).

## Apple names (use exactly what iOS shows)

| English | ja | zh-Hant | ko | de | es | zh-Hans | fr | pt-BR | it |
|---|---|---|---|---|---|---|---|---|---|
| Settings (app) | 設定 | 設定 | 설정 | Einstellungen | Ajustes | 设置 | Réglages | Ajustes | Impostazioni |
| General | 一般 | 一般 | 일반 | Allgemein | General | 通用 | Général | Geral | Generali |
| Keyboard › Keyboards | キーボード › キーボード | 鍵盤 › 鍵盤 | 키보드 › 키보드 | Tastatur › Tastaturen | Teclado › Teclados | 键盘 › 键盘 | Clavier › Claviers | Teclado › Teclados | Tastiera › Tastiere |
| Add New Keyboard | 新しいキーボードを追加 | 新增鍵盤 | 새로운 키보드 추가 | Tastatur hinzufügen | Añadir nuevo teclado | 添加新键盘 | Ajouter un clavier | Adicionar Novo Teclado | Aggiungi nuova tastiera |
| Allow Full Access | フルアクセスを許可 | 允許完整取用 | 전체 접근 허용 | Vollen Zugriff erlauben | Permitir acceso completo | 允许完全访问 | Autoriser l'accès complet | Permitir Acesso Total | Consenti accesso completo |
| Full Access | フルアクセス | 完整取用 | 전체 접근 | Voller Zugriff | acceso completo | 完全访问 | accès complet | Acesso Total | accesso completo |
| Shortcuts (app) | ショートカット | 捷徑 | 단축어 | Kurzbefehle | Atajos | 快捷指令 | Raccourcis | Atalhos | Comandi Rapidi |
| App Shortcuts | Appショートカット | App 捷徑 | 앱 단축어 | App-Kurzbefehle | Atajos de app | App 快捷指令 | Raccourcis d'app | Atalhos de App | Comandi rapidi app |
| Automation (tab) | オートメーション | 自動化操作 | 자동화 | Automation | Automatización | 自动化 | Automatisation | Automação | Automazione |
| New Automation | 新規オートメーション | 新增自動化操作 | 새로운 자동화 | Neue Automation | Nueva automatización | 新建自动化 | Nouvelle automatisation | Nova Automação | Nuova automazione |
| App (trigger) | App | App | 앱 | App | App | App | App | App | App |
| Is Opened / Is Closed | 開いている / 閉じている | 已打開 / 已關閉 | 열림 / 닫힘 | Wird geöffnet / Wird geschlossen | Se abre / Se cierra | 已打开 / 已关闭 | Est ouverte / Est fermée | É Aberto / É Fechado | Viene aperta / Viene chiusa |
| Run Immediately | すぐに実行 | 立即執行 | 즉시 실행 | Sofort ausführen | Ejecutar inmediatamente | 立即运行 | Exécuter immédiatement | Executar Imediatamente | Esegui immediatamente |
| Restore Purchases | 購入を復元 | 恢復購買 | 구입 항목 복원 | Käufe wiederherstellen | Restaurar compras | 恢复购买 | Restaurer les achats | Restaurar Compras | Ripristina acquisti |
| Family Sharing | ファミリー共有 | 家人共享 | 가족 공유 | Familienfreigabe | En familia | 家人共享 | Partage familial | Compartilhamento Familiar | In famiglia |
| Apple Account | Appleアカウント | Apple 帳號 | Apple 계정 | Apple Account | cuenta de Apple | Apple 账户 | compte Apple | Conta Apple | Account Apple |
| Home Screen | ホーム画面 | 主畫面 | 홈 화면 | Home-Bildschirm | pantalla de inicio | 主屏幕 | écran d'accueil | Tela de Início | schermata Home |
| Next keyboard (globe, VoiceOver) | 次のキーボード | 下一個鍵盤 | 다음 키보드 | Nächste Tastatur | Siguiente teclado | 下一个键盘 | Clavier suivant | Próximo teclado | Tastiera successiva |

The automation trigger names ("Is Opened", "Is Closed", "Run Immediately") change between iOS versions; they
were taken from iOS 17/18 and should be confirmed on a device in each language before a store submission (tier C).

## Return key titles (keyboard, lowercase where the system keyboard is)

| English | ja | zh-Hant | ko | de | es | zh-Hans | fr | pt-BR | it |
|---|---|---|---|---|---|---|---|---|---|
| return | 改行 | 換行 | 리턴 | Return | intro | 换行 | retour | retorno | invio |
| go | 開く | 前往 | 이동 | Öffnen | ir | 前往 | aller | ir | vai |
| search | 検索 | 搜尋 | 검색 | Suchen | buscar | 搜索 | rechercher | buscar | cerca |
| send | 送信 | 傳送 | 보내기 | Senden | enviar | 发送 | envoyer | enviar | invia |
| done | 完了 | 完成 | 완료 | Fertig | OK | 完成 | OK | OK | fine |
| next | 次へ | 下一步 | 다음 | Weiter | siguiente | 下一步 | suivant | próximo | avanti |
| join | 接続 | 加入 | 연결 | Verbinden | conectar | 加入 | rejoindre | conectar | unisciti |
| route | 経路 | 路線 | 경로 | Route | ruta | 路线 | itinéraire | rota | percorso |
| call | 緊急電話 | 緊急電話 | 긴급 전화 | Notruf | llamar | 紧急呼叫 | appel | ligar | chiama |
| continue | 続ける | 繼續 | 계속 | Weiter | continuar | 继续 | continuer | continuar | continua |
| space | 空白 | 空格 | 스페이스 | Leerzeichen | espacio | 空格 | espace | espaço | spazio |

## App Shortcut phrases (Siri, Spotlight, Shortcuts tiles)

`${applicationName}` and `${profile}` are kept. The first phrase is also the tile title of the ready-made
action per profile, and `useInAppsReadyMade` quotes it with the translated "Chat" profile name.

| English | ja | zh-Hant | ko | de | es | zh-Hans | fr | pt-BR | it |
|---|---|---|---|---|---|---|---|---|---|
| Switch ${applicationName} to ${profile} | ${applicationName}を${profile}に切り替える | 將${applicationName}切換為${profile} | ${applicationName}에서 ${profile} 프로필로 전환 | ${applicationName} auf ${profile} umstellen | Cambiar ${applicationName} a ${profile} | 将${applicationName}切换为${profile} | Passer ${applicationName} en ${profile} | Mudar ${applicationName} para ${profile} | Passa ${applicationName} a ${profile} |
| Use ${profile} in ${applicationName} | ${applicationName}で${profile}を使う | 在${applicationName}使用${profile} | ${applicationName}에서 ${profile} 사용 | ${profile} in ${applicationName} verwenden | Usar ${profile} en ${applicationName} | 在${applicationName}中使用${profile} | Utiliser ${profile} dans ${applicationName} | Usar ${profile} no ${applicationName} | Usa ${profile} in ${applicationName} |
| Set ${applicationName} profile | ${applicationName}のプロファイルを設定 | 設定${applicationName}模式 | ${applicationName} 프로필 설정 | ${applicationName}-Profil festlegen | Definir perfil de ${applicationName} | 设置${applicationName}模式 | Définir le profil ${applicationName} | Definir perfil do ${applicationName} | Imposta profilo di ${applicationName} |
| Switch ${applicationName} profile | ${applicationName}のプロファイルを切り替える | 切換${applicationName}模式 | ${applicationName} 프로필 전환 | ${applicationName}-Profil wechseln | Cambiar perfil de ${applicationName} | 切换${applicationName}模式 | Changer de profil ${applicationName} | Mudar perfil do ${applicationName} | Cambia profilo di ${applicationName} |
| Get ${applicationName} profile | ${applicationName}のプロファイルを取得 | 取得${applicationName}模式 | ${applicationName} 프로필 가져오기 | ${applicationName}-Profil abrufen | Obtener perfil de ${applicationName} | 获取${applicationName}模式 | Obtenir le profil ${applicationName} | Obter perfil do ${applicationName} | Ottieni profilo di ${applicationName} |

## Notes per language
- **zh-Hans / zh-Hant:** "profile" is 模式 (a voice mode the user switches), not 配置文件/描述檔 (Apple's
  configuration profiles) and not 預設 (means "default" in Taiwan). The Bailian recognition switch is
  识别方式 / 辨識方式 so it does not collide with 模式. Full-width punctuation; no space between CJK and
  `${applicationName}`.
- **ja:** katakana プロファイル (same as iOS's own "profile" elsewhere); full-width punctuation 「」 for quotes.
- **ko:** particles are avoided around placeholders (no 을/를 after a name we do not know).
- **de:** "Computer" for the Desktop tab (Desktop is not used for a PC in German UI text).
- **fr:** the Record tab and key say "Dicter": "Enregistrer" is already Save.
- **fr/es/it/pt-BR:** typographic quotes: « » (fr, with narrow spaces), “ ” (es, pt-BR, it).
