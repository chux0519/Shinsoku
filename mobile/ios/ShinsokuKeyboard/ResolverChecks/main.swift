import Foundation

// Host-side checks for KeyboardProfileResolver (not part of any Xcode target). Mirrors the cases of
// resolveActive in mobile/test (active_profile + P5 model). Run:
//   mobile/ios/ShinsokuKeyboard/ResolverChecks/run.sh

var failures = 0
func check(_ condition: Bool, _ name: String, line: Int = #line) {
    if !condition {
        failures += 1
        print("FAIL \(name) (line \(line))")
    }
}

typealias P = ProfileGroup.Profile
typealias S = ProfileGroup.Selection
let profiles = [P(id: "a", name: "Default"), P(id: "b", name: "Chat"), P(id: "c", name: "Review")]
let appear = KeyboardProfileResolver.instant("2026-11-19T10:00:00.000Z")!
func sel(_ id: String, _ source: String, _ at: String) -> S { S(profileId: id, source: source, at: at) }

// Timestamps: Dart writes microseconds, Swift milliseconds; whole seconds too.
check(KeyboardProfileResolver.instant("2026-11-19T10:00:00.123456Z") != nil, "parse micros")
check(KeyboardProfileResolver.instant("2026-11-19T10:00:00.123Z") != nil, "parse millis")
check(KeyboardProfileResolver.instant("2026-11-19T10:00:00Z") != nil, "parse seconds")
check(KeyboardProfileResolver.instant(ProfileGroup.timestamp()) != nil, "parse own timestamp")
check(KeyboardProfileResolver.instant("yesterday") == nil, "reject junk")
check(
    KeyboardProfileResolver.sameEvent(sel("b", "manual", "2026-11-19T10:00:00.000Z"),
                                      sel("b", "manual", "2026-11-19T10:00:00Z")),
    "same instant, different spelling")

// No selection, no rule → default.
var r = KeyboardProfileResolver.resolve(selection: nil, profiles: profiles)
check(r?.profile.id == "a" && r?.source == "default", "no selection → default")
check(KeyboardProfileResolver.resolve(selection: nil, profiles: []) == nil, "no profiles → nil")

// Stored selection wins without a rule; missing id → default (PR3).
r = KeyboardProfileResolver.resolve(selection: sel("c", "automation", "2026-11-19T09:00:00Z"), profiles: profiles)
check(r?.profile.id == "c" && r?.source == "automation", "automation selection")
r = KeyboardProfileResolver.resolve(selection: sel("zz", "manual", "2026-11-19T09:00:00Z"), profiles: profiles)
check(r?.profile.id == "a" && r?.source == "default", "PR3 missing id → default")
r = KeyboardProfileResolver.resolve(selection: sel("c", "manual", "not a time"), profiles: profiles)
check(r?.profile.id == "a" && r?.source == "default", "unparseable at → no selection")

// PR2 with selectionAtKeyboardAppear: unchanged explicit selection → rule applies.
let old = sel("c", "automation", "2026-11-19T10:00:01.500Z")  // writer clock ahead of the keyboard
r = KeyboardProfileResolver.resolve(selection: old, profiles: profiles, fieldRuleProfileId: "b",
                                    keyboardAppearedAt: appear, selectionAtKeyboardAppear: old)
check(r?.profile.id == "b" && r?.source == "fieldRule", "PR2 skew: unchanged selection, rule applies")
// A pick made after the keyboard appeared (differs from the captured one) beats the rule, even with an older
// clock.
let pick = sel("c", "manual", "2026-11-19T09:59:58.000Z")
r = KeyboardProfileResolver.resolve(selection: pick, profiles: profiles, fieldRuleProfileId: "b",
                                    keyboardAppearedAt: appear, selectionAtKeyboardAppear: old)
check(r?.profile.id == "c" && r?.source == "manual", "PR2 skew: newer pick wins")
// Default source never beats a rule.
r = KeyboardProfileResolver.resolve(selection: sel("a", "default", "2026-11-19T11:00:00Z"), profiles: profiles,
                                    fieldRuleProfileId: "b", keyboardAppearedAt: appear,
                                    selectionAtKeyboardAppear: nil)
check(r?.profile.id == "b" && r?.source == "fieldRule", "default selection never beats a rule")
// Without a capture: clock comparison.
r = KeyboardProfileResolver.resolve(selection: sel("c", "manual", "2026-11-19T10:00:00Z"), profiles: profiles,
                                    fieldRuleProfileId: "b", keyboardAppearedAt: appear)
check(r?.source == "manual", "at == appear counts as after")
r = KeyboardProfileResolver.resolve(selection: sel("c", "manual", "2026-11-19T09:59:59Z"), profiles: profiles,
                                    fieldRuleProfileId: "b", keyboardAppearedAt: appear)
check(r?.source == "fieldRule", "before appear → rule")
// No keyboard session: a rule never overrides an explicit selection.
r = KeyboardProfileResolver.resolve(selection: sel("c", "manual", "2020-01-01T00:00:00Z"), profiles: profiles,
                                    fieldRuleProfileId: "b")
check(r?.source == "manual", "no session → explicit wins")
// Rule pointing at a missing profile is ignored.
r = KeyboardProfileResolver.resolve(selection: nil, profiles: profiles, fieldRuleProfileId: "zz",
                                    keyboardAppearedAt: appear)
check(r?.source == "default", "rule with missing id ignored")

// Field rules parsing.
let rules = KeyboardProfileResolver.parseFieldRules(#"{"search":"b","email":"","bogus":"c","message":3}"#)
check(rules == [.search: "b"], "parse rules drops empty/unknown/non-string")
check(KeyboardProfileResolver.parseFieldRules(nil).isEmpty, "no rules")
check(KeyboardProfileResolver.parseFieldRules("[1]").isEmpty, "wrong shape")

// Cycling and the deep link.
check(KeyboardProfileResolver.next(after: "a", in: profiles)?.id == "b", "cycle a→b")
check(KeyboardProfileResolver.next(after: "c", in: profiles)?.id == "a", "cycle wraps")
check(KeyboardProfileResolver.next(after: "zz", in: profiles)?.id == "a", "cycle unknown → first")
check(KeyboardProfileResolver.next(after: "a", in: []) == nil, "cycle empty")
check(KeyboardProfileResolver.dictationURL(profileId: "b")?.absoluteString == "shinsoku://dictation?profile=b",
      "deep link")
check(KeyboardProfileResolver.dictationURL(profileId: "a b&c")?.absoluteString
      == "shinsoku://dictation?profile=a%20b%26c", "deep link escapes")
check(KeyboardProfileResolver.dictationURL(profileId: nil)?.absoluteString == "shinsoku://dictation",
      "deep link without profile")

print(failures == 0 ? "resolver checks: all passed" : "resolver checks: \(failures) failed")
exit(failures == 0 ? 0 : 1)
