@testable import TaimaCore

/// Vision output from published photos of regulated Dutch experiment
/// products (Omroep Brabant 2024, holigram.nl), text and boxes only.
// PRD identifiers are synthetic; OCR mistakes and box geometry are retained.
enum WebFixtures {
    static let fytaSourDelight = (
        lines: [
            RecognizedLine("Sour Delight", x: 0.1160, y: 0.6846, width: 0.0850, height: 0.0530),
            RecognizedLine("Geoogst op 20/05/2024", x: 0.1249, y: 0.6151, width: 0.1112, height: 0.0592),
            RecognizedLine("Verpakt op 12/12/2024", x: 0.1277, y: 0.5920, width: 0.1100, height: 0.0591),
            RecognizedLine("FYTA Company B.V.", x: 0.1903, y: 0.5495, width: 0.0713, height: 0.0460),
            RecognizedLine("www.fyta.group", x: 0.1935, y: 0.5349, width: 0.0566, height: 0.0367),
            RecognizedLine("0416 - 237000", x: 0.1948, y: 0.5183, width: 0.0524, height: 0.0379),
            RecognizedLine("k ven k", x: 0.2506, y: 0.5195, width: 0.0207, height: 0.0172),
            RecognizedLine("1 gram", x: 0.2607, y: 0.6953, width: 0.0458, height: 0.0437),
            RecognizedLine("20% THC", x: 0.2654, y: 0.6716, width: 0.0417, height: 0.0384),
            RecognizedLine("<1% C8D", x: 0.2650, y: 0.6482, width: 0.0423, height: 0.0388),
        ],
        codes: [
            DetectedCode(kind: .other, payload: "PRD-00000000-0000-4000-8000-000000000106"),
        ] as [DetectedCode]
    )
    static let aardachtigJar = (
        lines: [
            RecognizedLine("Bio Gmo x Zki", x: 0.3599, y: 0.6128, width: 0.0758, height: 0.0451),
            RecognizedLine("5gi", x: 0.4666, y: 0.6305, width: 0.0145, height: 0.0207),
            RecognizedLine("ardachtig Organics", x: 0.3637, y: 0.5981, width: 0.0732, height: 0.0342),
            RecognizedLine("THC%", x: 0.3619, y: 0.5943, width: 0.0218, height: 0.0181),
            RecognizedLine("C80%", x: 0.3614, y: 0.5753, width: 0.0252, height: 0.0266),
            RecognizedLine("17 89%", x: 0.4157, y: 0.5840, width: 0.0305, height: 0.0132),
            RecognizedLine("<1%", x: 0.4273, y: 0.5711, width: 0.0189, height: 0.0129),
            RecognizedLine("Gogstdatum", x: 0.3645, y: 0.5473, width: 0.0391, height: 0.0312),
            RecognizedLine("17-05-2024", x: 0.4181, y: 0.5474, width: 0.0418, height: 0.0221),
            RecognizedLine("Herpalkingsdtatum 28-10-2024", x: 0.3673, y: 0.5344, width: 0.0937, height: 0.0292),
            RecognizedLine("Het Butfen bereik van kinderen", x: 0.3671, y: 0.5158, width: 0.0997, height: 0.0325),
            RecognizedLine("eu@sardachtig.nt", x: 0.3644, y: 0.4991, width: 0.0625, height: 0.0409),
            RecognizedLine("www.aardachtig.ni", x: 0.4273, y: 0.5017, width: 0.0584, height: 0.0378),
        ],
        codes: [
        ] as [DetectedCode]
    )
    static let holiFresh = (
        lines: [
            RecognizedLine("Busluite", x: 0.2191, y: 0.5591, width: 0.0484, height: 0.0176),
            RecognizedLine("Holi Fresh", x: 0.3644, y: 0.5718, width: 0.2215, height: 0.0568),
            RecognizedLine("Geproduceerd 13-01-2026", x: 0.4281, y: 0.5206, width: 0.2060, height: 0.0270),
            RecognizedLine("Verpakt 22-05-2026", x: 0.4747, y: 0.4976, width: 0.1637, height: 0.0252),
            RecognizedLine("•PTLT: PRD-O0000000-0000-4000-8000-000000000113", x: 0.2280, y: 0.4662, width: 0.4261, height: 0.0416),
            RecognizedLine("0.5 Gram", x: 0.6457, y: 0.5568, width: 0.0868, height: 0.0254),
            RecognizedLine("Track & Trace", x: 0.6496, y: 0.5357, width: 0.0947, height: 0.0299),
            RecognizedLine("Houd buiten bereik van kinderen.", x: 0.3911, y: 0.3556, width: 0.1844, height: 0.0133),
            RecognizedLine("Holigram", x: 0.4200, y: 0.3289, width: 0.0822, height: 0.0222),
            RecognizedLine("Holi Fresh", x: 0.4178, y: 0.3022, width: 0.1000, height: 0.0222),
        ],
        codes: [
        ] as [DetectedCode]
    )
    static let zunami = (
        lines: [
            RecognizedLine("Zunami", x: 0.1817, y: 0.5218, width: 0.1712, height: 0.0220),
            RecognizedLine("Geoogst op 25/08/2026", x: 0.3299, y: 0.4918, width: 0.3089, height: 0.0174),
            RecognizedLine("Verpakt op 14/10/2026", x: 0.3333, y: 0.4709, width: 0.3050, height: 0.0131),
            RecognizedLine("Track en Trace", x: 0.1887, y: 0.4460, width: 0.1289, height: 0.0090),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000102", x: 0.1851, y: 0.4326, width: 0.4033, height: 0.0142),
            RecognizedLine("1 gram", x: 0.6823, y: 0.5202, width: 0.1449, height: 0.0207),
            RecognizedLine("THC: 24%", x: 0.6820, y: 0.4957, width: 0.1486, height: 0.0143),
            RecognizedLine("CBD: <1%", x: 0.6852, y: 0.4723, width: 0.1454, height: 0.0141),
            RecognizedLine("ZUNA-FLW-10G", x: 0.7075, y: 0.4375, width: 0.1289, height: 0.0087)
        ],
        codes: [DetectedCode(kind: .code128, payload: "ZUNA-FLW-10G"), DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000102")]
    )
}
