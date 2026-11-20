import XCTest

/// Tier-B scene for the App Store keyboard screenshot (release-01 R3): the Shinsoku keyboard over a chat-style
/// page in Safari, the locale's dictated text inserted into the message field.
///
/// Run by the coordinator only (iPhone 17, clean status bar):
///   SCENE_TEST=KeyboardSceneTests/StoreSceneTests SCENE_STATUS_BAR=clean \
///     tool/ios_keyboard_scene.sh <UDID> build/store/keyboard
/// Limit the locales with `TEST_RUNNER_STORE_LOCALES=en-US,ja` (xcodebuild passes TEST_RUNNER_* to the test as
/// STORE_LOCALES); default: all 10 store locales. Per locale:
///   PHASE-xx-store-<locale>-app       Shinsoku launched in the locale, the text seeded as the latest
///   PHASE-xx-store-<locale>-ready     the chat page in Safari, the Shinsoku keyboard up ("Latest text ready")
///   PHASE-xx-store-<locale>-inserted  after Insert: the text in the message field (the store frame)
/// tool/store_frames.py picks `light/PHASE-*-store-<locale>-inserted.png`.
///
/// Language: the Runner and Safari get `-AppleLanguages (<lang>) -AppleLocale <locale>`. The keyboard extension
/// follows the **system** language (the shared simulators run in Chinese and must not be changed), so its keys
/// read Chinese in every locale's frame; the SCENE line `keyboard-language` records what the Record key said.
/// No keys and no real names: the text is the store fixture text (mobile/test/host_review/store_fixtures.dart).
final class StoreSceneTests: SceneTestCase {
    private struct Store {
        let locale: String
        let language: String
        let region: String
        let incoming: String
        let placeholder: String
        let text: String
    }

    private static let all: [Store] = [
        Store(locale: "en-US", language: "en", region: "en_US",
              incoming: "Are we still on for the launch this week?", placeholder: "Message",
              text: "Quick update for the team: the launch moves to Thursday, so let’s finish the release notes "
                + "by Wednesday afternoon."),
        Store(locale: "zh-Hans", language: "zh-Hans", region: "zh_SG",
              incoming: "这周的发布还按原计划吗？", placeholder: "信息",
              text: "跟大家同步一下：发布改到周四，所以我们周三下午之前要把更新说明写完。"),
        Store(locale: "zh-Hant", language: "zh-Hant", region: "zh_TW",
              incoming: "這週的發布還照原計畫嗎？", placeholder: "訊息",
              text: "跟大家同步一下：發布改到週四，所以我們週三下午之前要把更新說明寫完。"),
        Store(locale: "ja", language: "ja", region: "ja_JP",
              incoming: "今週のリリースは予定どおりですか？", placeholder: "メッセージ",
              text: "チームの皆さんへ。リリースは木曜日に変更になったので、水曜日の午後までにリリースノートを仕上げましょう。"),
        Store(locale: "ko", language: "ko", region: "ko_KR",
              incoming: "이번 주 출시는 예정대로인가요?", placeholder: "메시지",
              text: "팀 공지입니다. 출시가 목요일로 바뀌었으니 수요일 오후까지 릴리스 노트를 마무리해 주세요."),
        Store(locale: "de-DE", language: "de", region: "de_DE",
              incoming: "Bleibt es beim Launch diese Woche?", placeholder: "Nachricht",
              text: "Kurzes Update fürs Team: Der Launch ist jetzt am Donnerstag, also lasst uns die Release Notes "
                + "bis Mittwochnachmittag fertigstellen."),
        Store(locale: "fr-FR", language: "fr", region: "fr_FR",
              incoming: "Le lancement est toujours prévu cette semaine ?", placeholder: "Message",
              text: "Petit point pour l’équipe : le lancement passe à jeudi, donc finissons les notes de version "
                + "d’ici mercredi après-midi."),
        Store(locale: "es-ES", language: "es", region: "es_ES",
              incoming: "¿Seguimos con el lanzamiento esta semana?", placeholder: "Mensaje",
              text: "Una actualización para el equipo: el lanzamiento pasa al jueves, así que terminemos las notas "
                + "de la versión antes del miércoles por la tarde."),
        Store(locale: "pt-BR", language: "pt-BR", region: "pt_BR",
              incoming: "O lançamento continua para esta semana?", placeholder: "Mensagem",
              text: "Atualização rápida para o time: o lançamento mudou para quinta, então vamos fechar as notas "
                + "da versão até quarta à tarde."),
        Store(locale: "it", language: "it", region: "it_IT",
              incoming: "Il lancio è ancora previsto per questa settimana?", placeholder: "Messaggio",
              text: "Aggiornamento veloce per il team: il lancio slitta a giovedì, quindi chiudiamo le note di "
                + "rilascio entro mercoledì pomeriggio."),
    ]

    func testStoreKeyboardScene() throws {
        let wanted = (ProcessInfo.processInfo.environment["STORE_LOCALES"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let stores = wanted.isEmpty ? Self.all : Self.all.filter { wanted.contains($0.locale) }
        check(!stores.isEmpty, "store-locales", "no known locale in STORE_LOCALES=\(wanted)")

        ensureKeyboardAdded()
        setFullAccess(true)
        addTeardownBlock { [unowned self] in
            self.runner.terminate()
            self.safari.terminate()
            self.safari.launchArguments = Self.englishArguments
            self.restoreSystemKeyboard()
        }

        for store in stores {
            let arguments = ["-AppleLanguages", "(\(store.language))", "-AppleLocale", store.region]
            // The locale's text becomes the latest, through the app's real publish path.
            runner.terminate()
            launchRunner(["-ShinsokuSceneResetLatest", "YES", "-ShinsokuSceneSeedLatest", store.text] + arguments,
                         shotName: "store-\(store.locale)-app")

            safari.terminate()
            safari.launchArguments = arguments
            safari.launch()
            safari.open(URL(string: Self.pageURL(store))!)
            let message = field()
            require(message, "\(store.locale)-message-field", timeout: 15)
            message.tap()
            switchToShinsoku(retapping: message, step: "\(store.locale)-shinsoku-keyboard")
            let record = key("Record")
            print("SCENE keyboard-language \(store.locale): Record key '\(record.label)'")
            require(statusText("Latest text ready"), "\(store.locale)-latest-ready", timeout: 5)
            shot("store-\(store.locale)-ready")

            tap(key("Insert latest text"), "\(store.locale)-insert")
            require(statusText("Inserted"), "\(store.locale)-inserted", timeout: 5)
            // Let the caret settle and the field grow before the frame.
            Thread.sleep(forTimeInterval: 1)
            shot("store-\(store.locale)-inserted")
            check(fieldValue().contains(store.text), "\(store.locale)-field-text", "field: \(fieldValue())")
        }
    }

    /// A neutral chat page: one incoming bubble and the message field (a textarea, found by `field()`).
    private static func pageURL(_ store: Store) -> String {
        let html = """
            <meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>
            <title>\(store.placeholder)</title>
            <style>
            body{margin:0;font:17px -apple-system,sans-serif;background:#fff;color:#1c2426}
            .log{padding:24px 14px 8px;display:flex;flex-direction:column;gap:8px}
            .in{align-self:flex-start;max-width:78%;background:#e9e9eb;border-radius:18px;padding:9px 13px}
            .bar{display:flex;padding:8px 10px;border-top:1px solid #e5e5ea}
            textarea{flex:1;font:17px -apple-system,sans-serif;border:1px solid #d1d1d6;border-radius:18px;
            padding:8px 13px;height:7.5em;resize:none;outline:none}
            </style>
            <div class=log><div class=in>\(store.incoming)</div></div>
            <div class=bar><textarea aria-label='\(store.placeholder)' placeholder='\(store.placeholder)'></textarea></div>
            """
        return "data:text/html;charset=utf-8," + html.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
}
