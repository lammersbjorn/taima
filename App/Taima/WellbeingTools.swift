import SwiftUI
import TaimaCore

/// Harm-reduction tips after Trimbos (the Dutch institute for mental health
/// and addiction), bundled so they work offline. General information, not
/// medical advice.
struct SaferUseView: View {
    private let tips: [(symbol: String, title: String, detail: String)] = [
        ("gauge.with.dots.needle.33percent", String(localized: "Start low"), String(localized: "Strong bags are common in the Netherlands. Take less, or a lower THC, when you're new, after a break or with a new strain.")),
        ("wind", String(localized: "Vaping over smoking"), String(localized: "A dry-herb vaporiser spares your lungs the smoke. Smoking is the most harmful way to use.")),
        ("nosign", String(localized: "Leave out the tobacco"), String(localized: "Nicotine is very addictive, and mixing it in makes stopping harder. Tobacco-free joints or a vaporiser avoid it.")),
        ("lungs", String(localized: "Don't hold it in"), String(localized: "Inhaling deeply or holding smoke adds tar, not effect.")),
        ("timer", String(localized: "Edibles: wait"), String(localized: "Effects take 30 to 90 minutes and last longer. Wait before taking more; the edible timer can help.")),
        ("car", String(localized: "Don't drive"), String(localized: "Don't drive or use machinery after using. THC slows reactions, and Dutch law sets strict limits.")),
        ("wineglass", String(localized: "Don't mix"), String(localized: "Alcohol and other drugs make the effects stronger and harder to predict.")),
        ("pause.circle", String(localized: "Take breaks"), String(localized: "Breaks keep your tolerance down. Using every day is a sign to look at your use.")),
        ("figure.and.child.holdinghands", String(localized: "Pregnancy"), String(localized: "Don't use when pregnant or breastfeeding."))
    ]

    var body: some View {
        List {
            Section {
                ForEach(tips, id: \.title) { tip in
                    HStack(alignment: .top, spacing: 14) {
                        TintedIconTile(systemImage: tip.symbol, hue: Theme.leafMid, size: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tip.title).font(.headline)
                            Text(tip.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } footer: {
                Text("After Trimbos guidance. General information, not medical advice.")
            }
            HelpSection()
        }
        .scrollContentBackground(.hidden)
    }
}

/// Dutch help lines, anonymous and free to call apart from local rates.
struct HelpSection: View {
    var body: some View {
        Section {
            Link(destination: URL(string: "tel:09001995")!) {
                Label("Drugs Infolijn: 0900-1995", systemImage: "phone")
            }
            SafeLinkButton(title: "drugsinfo.nl", systemImage: "globe", address: "https://www.drugsinfo.nl", detail: String(localized: "Opens the Trimbos drug information site in Safari."))
            SafeLinkButton(title: String(localized: "Trimbos cannabis tips (PDF)"), systemImage: "doc.text", address: "https://www.trimbos.nl/wp-content/uploads/2021/11/PM0662-Tips-Cannabis-Nederlands.pdf", detail: String(localized: "Opens the Trimbos leaflet in Safari."))
        } header: {
            Text("Questions or worries")
        } footer: {
            Text("The Drugs Infolijn is run by Trimbos and answers anonymously.")
        }
    }
}

/// The CUDIT-R questions, answered privately; only the score and date are kept.
struct SelfCheckView: View {
    @State private var answers = Array(repeating: -1, count: SelfCheck.questions.count)
    @State private var result: Int?
    @State private var history = SelfCheckHistory.load()

    var body: some View {
        Form {
            if let result {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(result) of 32").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(SelfCheck.summary(for: result)).font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    Button("Start again", systemImage: "arrow.counterclockwise") {
                        withAnimation { self.result = nil; answers = Array(repeating: -1, count: answers.count) }
                    }
                } footer: {
                    Text("A short screen, not a diagnosis. It looks at the past 6 months.")
                }
                HelpSection()
            } else {
                Section {
                    Text("Eight questions about the past 6 months. Your answers stay on this iPhone; only the score is kept so you can compare later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(SelfCheck.questions.enumerated()), id: \.offset) { index, question in
                    Section {
                        Picker(question.text, selection: $answers[index]) {
                            Text("Choose").tag(-1)
                            ForEach(Array(question.answers.enumerated()), id: \.offset) { option, answer in
                                Text(answer.label).tag(option)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } header: {
                        Text("\(index + 1) of \(SelfCheck.questions.count)")
                    } footer: {
                        Text(question.text)
                    }
                }
                Section {
                    Button("See result", systemImage: "checkmark") {
                        let score = SelfCheck.score(answers)
                        history.insert(SelfCheck.Result(score: score), at: 0)
                        SelfCheckHistory.save(history)
                        withAnimation { result = score }
                    }
                    .disabled(answers.contains(-1))
                }
            }
            if !history.isEmpty {
                Section("Earlier") {
                    ForEach(history.prefix(6)) { item in
                        LabeledContent(item.date.formatted(date: .abbreviated, time: .omitted), value: String(localized: "\(item.score) of 32"))
                    }
                    .onDelete { offsets in
                        history.remove(atOffsets: offsets)
                        SelfCheckHistory.save(history)
                    }
                }
            }
            Section {
            } footer: {
                Text("CUDIT-R: Adamson et al., Drug and Alcohol Dependence, 2010.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

enum SelfCheckHistory {
    static let key = "selfcheck.history"

    static func load() -> [SelfCheck.Result] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SelfCheck.Result].self, from: data)) ?? []
    }

    static func save(_ results: [SelfCheck.Result]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(results), forKey: key)
    }
}
