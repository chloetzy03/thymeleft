import Foundation

/// Finds the expiry date in the messy text a camera reads off a pack.
/// (Translation: it gets lines like ["NET WT 500g", "BEST BEFORE 18 NOV 2026", "L2345"] and
/// answers "18 Nov 2026". It only does maths on text, so we can test it with hundreds of
/// examples without ever opening a camera.)
struct ExpiryDateParser {

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - lines: the text lines read from the pack, in reading order.
    ///   - dayFirst: for dates like 03/04/26, is it 3 April (true) or March 4 (false)?
    ///   - now: today. Dates far in the past or future are ignored as misreads.
    func parse(lines: [String], dayFirst: Bool, now: Date) -> ScannedExpiryDate? {
        var candidates: [Candidate] = []

        // Cameras often split one printed date across lines ("5" / "NOV 2027", or "5 NOV" / "2027").
        // So we also read every pair of neighbouring lines as if they were one line.
        func gather(_ texts: [(raw: String, previous: String)]) -> [Candidate] {
            var result: [Candidate] = []
            for (rawLine, previous) in texts {
                let line = normalize(rawLine)
                for found in dates(in: line, dayFirst: dayFirst) where isPlausible(found.date, now: now) {
                    let label = label(before: found.range, in: line, previousLine: previous)
                    result.append(Candidate(date: found.date, alternative: found.alternative, hasDay: found.hasDay,
                                            label: label, sourceText: rawLine.trimmingCharacters(in: .whitespaces)))
                }
            }
            return result
        }

        candidates = gather(lines.enumerated().map { index, line in (line, index > 0 ? normalize(lines[index - 1]) : "") })
        if lines.count > 1 {
            let pairs = (1..<lines.count).map { index in
                ("\(lines[index - 1]) \(lines[index])", index > 1 ? normalize(lines[index - 2]) : "")
            }
            // A joined pair only matters when it finds a date no single line found on its own.
            let alone = candidates
            for joined in gather(pairs) where !alone.contains(where: { $0.hasDay && $0.date == joined.date }) {
                candidates.append(joined)
            }
        }

        // "NOV 2027" (no day) is only a fallback. If the same month also appears WITH a day somewhere,
        // the day-less one is just the same date read badly, so drop it.
        candidates = candidates.filter { candidate in
            candidate.hasDay || !candidates.contains { other in
                other.hasDay && calendar.isDate(other.date, equalTo: candidate.date, toGranularity: .month)
            }
        }

        // A date labelled "made on" is not an expiry date. Drop those if there is anything else.
        let notManufactured = candidates.filter { $0.label != .manufactured }
        guard let best = notManufactured.max(by: { lhs, rhs in
            if lhs.label != rhs.label { return lhs.label.rank < rhs.label.rank }
            return lhs.date < rhs.date // otherwise the later date is more likely the expiry date
        }) else { return nil }

        return ScannedExpiryDate(date: best.date,
                                 sourceText: best.sourceText,
                                 alternative: best.alternative.flatMap { isPlausible($0, now: now) ? $0 : nil },
                                 dayWasGuessed: !best.hasDay)
    }

    // MARK: - Types

    private enum Label {
        case expiry, none, manufactured
        /// Higher wins when choosing between dates.
        var rank: Int {
            switch self {
            case .expiry: return 2
            case .none: return 1
            case .manufactured: return 0
            }
        }
    }

    private struct Candidate {
        let date: Date
        let alternative: Date?
        let hasDay: Bool
        let label: Label
        let sourceText: String
    }

    private struct Found {
        let date: Date
        let alternative: Date?
        let hasDay: Bool
        let range: NSRange
    }

    // MARK: - Cleaning up the text

    /// Upper-case, tidy spaces, and fix letters the camera often mistakes for digits
    /// (an "O" inside a number is almost always a zero).
    private func normalize(_ text: String) -> String {
        // Full-width digits and punctuation (as printed on some packs) become normal ones first: "２０２７" -> "2027".
        let halfWidth = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        var result = halfWidth.uppercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        let fixes: [(pattern: String, replacement: String)] = [
            (#"(?<=\d)O(?=\d)"#, "0"), (#"(?<=\d)O(?=[/.\-\s]\d)"#, "0"), (#"(?<![A-Z\d])O(?=\d[/.\-])"#, "0"),
            (#"(?<=\d)[IL](?=\d)"#, "1"), (#"(?<=\d)[IL](?=[/.\-\s]\d)"#, "1"), (#"(?<![A-Z\d])[IL](?=\d[/.\-])"#, "1")
        ]
        for fix in fixes {
            result = result.replacingOccurrences(of: fix.pattern, with: fix.replacement, options: .regularExpression)
        }
        result = fixDayLetters(in: result)
        return result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// Cameras read the day number in "5 NOV 2027" as "S NOV 2027" (S looks like 5), "O5" as "05" and so on.
    /// If a short token sits right before a month name and a year, turn the look-alike letters into digits.
    private func fixDayLetters(in text: String) -> String {
        let pattern = #"(?<![A-Z\d])([0-9OILSBZ]{1,2})(?= ?(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.? ?[\-/']? ?\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let look: [Character: Character] = ["O": "0", "I": "1", "L": "1", "S": "5", "B": "8", "Z": "2"]
        var result = text
        // Go from the end so earlier positions stay valid while we replace.
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range(at: 1), in: result) else { continue }
            let token = String(result[range])
            // A two-letter token with no digit ("IS", "BO") is probably a real word, so leave it.
            if token.count == 2, !token.contains(where: \.isNumber) { continue }
            let fixed = String(token.map { look[$0] ?? $0 })
            if let day = Int(fixed), (1...31).contains(day) { result.replaceSubrange(range, with: fixed) }
        }
        return result
    }

    // MARK: - Finding dates

    private func dates(in line: String, dayFirst: Bool) -> [Found] {
        var found: [Found] = []
        var used: [NSRange] = []

        func take(_ pattern: String, hasDay: Bool = true, build: ([String]) -> (date: Date, alternative: Date?)?) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let whole = NSRange(line.startIndex..., in: line)
            for match in regex.matches(in: line, range: whole) {
                // Don't read the same characters twice (e.g. the "26" of "18NOV26" as a month).
                guard !used.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { continue }
                let parts = (0..<match.numberOfRanges).map { index -> String in
                    guard let range = Range(match.range(at: index), in: line) else { return "" }
                    return String(line[range])
                }
                if let result = build(parts) {
                    found.append(Found(date: result.date, alternative: result.alternative, hasDay: hasDay, range: match.range))
                    used.append(match.range)
                }
            }
        }

        // 0a. Chinese style: 2027年11月5日, 2027年11月5号, 27年11月5日 (year, month, day: never ambiguous)
        take(#"(?<!\d)(\d{4}|\d{2}) ?年 ?(\d{1,2}) ?月 ?(\d{1,2}) ?[日号]?"#) { parts in
            guard let year = Int(parts[1]), let month = Int(parts[2]), let day = Int(parts[3]),
                  let date = makeDate(day: day, month: month, year: fullYear(year)) else { return nil }
            return (date, nil)
        }
        // 0b. Chinese style without a day: 2027年11月 (lasts until the end of that month)
        take(#"(?<!\d)(\d{4}|\d{2}) ?年 ?(\d{1,2}) ?月"#, hasDay: false) { parts in
            guard let year = Int(parts[1]), let month = Int(parts[2]),
                  let date = endOfMonth(month: month, year: fullYear(year)) else { return nil }
            return (date, nil)
        }
        // 1. 18/11/2026, 18-11-26, 18.11.26, 18 11 2026 (day and month in the user's order)
        take(#"(?<!\d)(\d{1,2})[\s./\-](\d{1,2})[\s./\-](\d{4}|\d{2})(?!\d)"#) { parts in
            guard let a = Int(parts[1]), let b = Int(parts[2]), let year = Int(parts[3]) else { return nil }
            return resolveDayMonth(a, b, year: fullYear(year), dayFirst: dayFirst)
        }
        // 2. 2026-11-18, 2026/11/18 (year first is never ambiguous)
        take(#"(?<!\d)(\d{4})[\s./\-](\d{1,2})[\s./\-](\d{1,2})(?!\d)"#) { parts in
            guard let year = Int(parts[1]), let month = Int(parts[2]), let day = Int(parts[3]),
                  let date = makeDate(day: day, month: month, year: year) else { return nil }
            return (date, nil)
        }
        // 3. 18 NOV 2026, 18NOV26, 18 November 2026
        take(#"(?<!\d)(\d{1,2}) ?([A-Z]{3,9})\.? ?[\-/']? ?(\d{4}|\d{2})(?!\d)"#) { parts in
            guard let day = Int(parts[1]), let month = Self.monthNumber(parts[2]), let year = Int(parts[3]),
                  let date = makeDate(day: day, month: month, year: fullYear(year)) else { return nil }
            return (date, nil)
        }
        // 4. NOV 18 2026, NOV 18 26
        take(#"(?<![A-Z])([A-Z]{3,9})\.? ?(\d{1,2})(?: |[\-/'.] ?)(\d{4}|\d{2})(?!\d)"#) { parts in
            guard let month = Self.monthNumber(parts[1]), let day = Int(parts[2]), let year = Int(parts[3]),
                  let date = makeDate(day: day, month: month, year: fullYear(year)) else { return nil }
            return (date, nil)
        }
        // 5. NOV 2026, NOV26 (no day: it lasts until the end of that month)
        take(#"(?<![A-Z])([A-Z]{3,9})\.? ?[\-/']? ?(\d{4}|\d{2})(?!\d)"#, hasDay: false) { parts in
            guard let month = Self.monthNumber(parts[1]), let year = Int(parts[2]),
                  let date = endOfMonth(month: month, year: fullYear(year)) else { return nil }
            return (date, nil)
        }
        // 6. 11/2026, 11.26 (month and year only)
        take(#"(?<![\d/.\-])(\d{1,2})[./\-](\d{4}|\d{2})(?![\d/.\-])"#, hasDay: false) { parts in
            guard let month = Int(parts[1]), let year = Int(parts[2]),
                  let date = endOfMonth(month: month, year: fullYear(year)) else { return nil }
            return (date, nil)
        }
        return found
    }

    /// For 03/04/26: use the user's order, but remember the swapped reading too.
    private func resolveDayMonth(_ a: Int, _ b: Int, year: Int, dayFirst: Bool) -> (date: Date, alternative: Date?)? {
        if a > 12 { return makeDate(day: a, month: b, year: year).map { ($0, nil) } } // must be the day
        if b > 12 { return makeDate(day: b, month: a, year: year).map { ($0, nil) } } // must be the day
        let primary = dayFirst ? makeDate(day: a, month: b, year: year) : makeDate(day: b, month: a, year: year)
        let swapped = dayFirst ? makeDate(day: b, month: a, year: year) : makeDate(day: a, month: b, year: year)
        guard let primary else { return nil }
        return (primary, a == b ? nil : swapped) // 04/04 reads the same both ways
    }

    // MARK: - Labels ("EXP", "MFG" ...)

    private func label(before range: NSRange, in line: String, previousLine: String) -> Label {
        let before = (line as NSString).substring(to: range.location)
        // If little text comes before the date, the label may be on the line above ("BEST BEFORE" / "18/11/26").
        // But a line that has its own date (it contains digits) labels only that date, not the next one.
        let previousIsOnlyALabel = previousLine.rangeOfCharacter(from: .decimalDigits) == nil
        let carriedLabel = (before.count < 6 && previousIsOnlyALabel) ? previousLine + " " : ""
        let context = String((carriedLabel + before).suffix(24))

        let expiryEnd = lastMatchEnd(of: #"\bEXP\w*|BEST ?BEFORE|\bBBE?\b|USE ?BY|BEST ?BY|SELL ?BY|\bUBD\b|\bBEFORE\b|保质期至|保质期限至|有效期至|有效期|到期|食用期限|最佳食用|赏味期|请在|截止|失效"#, in: context)
        let madeEnd = lastMatchEnd(of: #"\bMF[GD]\b|\bMANUF\w*|\bPROD\w*|\bPKD\b|\bPACKED\b|\bDOM\b|生产日期|生产|制造|灌装|包装日期|出厂|分装"#, in: context)

        switch (expiryEnd, madeEnd) {
        case let (expiry?, made?): return expiry > made ? .expiry : .manufactured // the closest label wins
        case (.some, nil): return .expiry
        case (nil, .some): return .manufactured
        case (nil, nil): return .none
        }
    }

    private func lastMatchEnd(of pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.last.map { $0.range.location + $0.range.length }
    }

    // MARK: - Dates

    private func fullYear(_ year: Int) -> Int { year < 100 ? 2000 + year : year }

    /// Builds a date, or nil for impossible ones such as 31/02.
    private func makeDate(day: Int, month: Int, year: Int) -> Date? {
        var parts = DateComponents(year: year, month: month, day: day, hour: 12)
        parts.calendar = calendar
        guard let date = calendar.date(from: parts) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        return (check.year == year && check.month == month && check.day == day) ? date : nil
    }

    private func endOfMonth(month: Int, year: Int) -> Date? {
        guard (1...12).contains(month),
              let firstOfMonth = makeDate(day: 1, month: month, year: year),
              let days = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count else { return nil }
        return makeDate(day: days, month: month, year: year)
    }

    /// From a year ago to ten years ahead. Anything else is probably a misread or a batch number.
    private func isPlausible(_ date: Date, now: Date) -> Bool {
        guard let earliest = calendar.date(byAdding: .year, value: -1, to: now),
              let latest = calendar.date(byAdding: .year, value: 10, to: now) else { return false }
        return date >= earliest && date <= latest
    }

    private static let months: [String: Int] = [
        "JAN": 1, "JANUARY": 1, "FEB": 2, "FEBRUARY": 2, "MAR": 3, "MARCH": 3, "APR": 4, "APRIL": 4,
        "MAY": 5, "JUN": 6, "JUNE": 6, "JUL": 7, "JULY": 7, "AUG": 8, "AUGUST": 8,
        "SEP": 9, "SEPT": 9, "SEPTEMBER": 9, "OCT": 10, "OCTOBER": 10,
        "NOV": 11, "NOVEMBER": 11, "DEC": 12, "DECEMBER": 12
    ]

    private static func monthNumber(_ word: String) -> Int? { months[word] }
}
