@testable import TaimaCore

/// Vision output captured from real bag photos on 2026-10-27 (text and boxes only).
// PRD identifiers are synthetic; OCR mistakes and box geometry are retained.
enum Fixtures {
    static let motorbreath = (
        lines: [
            RecognizedLine("THC", x: 0.3561, y: 0.5329, width: 0.0407, height: 0.0446),
            RecognizedLine("THC 24%", x: 0.3225, y: 0.4603, width: 0.0889, height: 0.0250),
            RecognizedLine("CBD <1%", x: 0.3227, y: 0.4341, width: 0.0916, height: 0.0252),
            RecognizedLine("1 gr.", x: 0.3430, y: 0.4019, width: 0.0437, height: 0.0315),
            RecognizedLine(":R&D Exclusive", x: 0.4404, y: 0.5756, width: 0.2180, height: 0.0311),
            RecognizedLine("Motorbreath", x: 0.4520, y: 0.5252, width: 0.1672, height: 0.0329),
            RecognizedLine("Tel: +31 181 72 91 31", x: 0.5451, y: 0.4767, width: 0.1308, height: 0.0158),
            RecognizedLine("12.05.2026 - 22.06.2026 / 23.09.2026", x: 0.5449, y: 0.4375, width: 0.2256, height: 0.0216),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000107", x: 0.5435, y: 0.4065, width: 0.2227, height: 0.0227),
            RecognizedLine("721098 004528", x: 0.7819, y: 0.4607, width: 0.0167, height: 0.1272),
        ],
        codes: [
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000107"),
        ] as [DetectedCode]
    )
    static let girlScoutCookie = (
        lines: [
            RecognizedLine("₫77c", x: 0.1598, y: 0.8115, width: 0.0342, height: 0.0297),
            RecognizedLine("reik van kinderen", x: -0.0045, y: 0.7320, width: 0.1297, height: 0.0766),
            RecognizedLine("Girl Scout Cookie", x: 0.3563, y: 0.6080, width: 0.1744, height: 0.0488),
            RecognizedLine("THC 24%", x: 0.3552, y: 0.5837, width: 0.0540, height: 0.0216),
            RecognizedLine("CBD", x: 0.3532, y: 0.5678, width: 0.0233, height: 0.0155),
            RecognizedLine("<1%", x: 0.3881, y: 0.5659, width: 0.0203, height: 0.0116),
            RecognizedLine("Gewicht: 5 gram", x: 0.5602, y: 0.5593, width: 0.0801, height: 0.0240),
            RecognizedLine("Geoogst: 02-07-2026", x: 0.5607, y: 0.5380, width: 0.0966, height: 0.0173),
            RecognizedLine("Verpakt:", x: 0.5562, y: 0.5201, width: 0.0417, height: 0.0186),
            RecognizedLine("28-09-2026", x: 0.6057, y: 0.5190, width: 0.0517, height: 0.0149),
            RecognizedLine("Bijsluiter", x: 0.6148, y: 0.4185, width: 0.0364, height: 0.0118),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000109", x: 0.3499, y: 0.3872, width: 0.1985, height: 0.0275),
        ],
        codes: [
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000110"),
        ] as [DetectedCode]
    )
    static let amnesiaS5 = (
        lines: [
            RecognizedLine("Amnesia S5 - Hand Trim", x: 0.2698, y: 0.6321, width: 0.3230, height: 0.0649),
            RecognizedLine("THC 28 %", x: 0.2790, y: 0.5672, width: 0.1295, height: 0.0380),
            RecognizedLine("CBD <1 %", x: 0.2805, y: 0.5155, width: 0.1337, height: 0.0487),
            RecognizedLine("Gewicht: 1 gram", x: 0.5814, y: 0.5850, width: 0.1875, height: 0.0352),
            RecognizedLine("Geoogst: 22-07-2026", x: 0.6245, y: 0.4450, width: 0.1786, height: 0.0403),
            RecognizedLine("'Verpakt: 08-09-2026", x: 0.6248, y: 0.4078, width: 0.1808, height: 0.0384),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000105", x: 0.4313, y: 0.3105, width: 0.3584, height: 0.0362),
        ],
        codes: [
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000105"),
        ] as [DetectedCode]
    )
    static let selectionIndica = (
        lines: [
            RecognizedLine("THC", x: 0.3052, y: 0.5678, width: 0.0422, height: 0.0543),
            RecognizedLine("THC 24%", x: 0.2732, y: 0.4978, width: 0.0916, height: 0.0256),
            RecognizedLine("CBD <1%", x: 0.2761, y: 0.4686, width: 0.0931, height: 0.0259),
            RecognizedLine("1 gr.", x: 0.2958, y: 0.4380, width: 0.0466, height: 0.0278),
            RecognizedLine("COG", x: 0.4070, y: 0.6163, width: 0.0901, height: 0.0349),
            RecognizedLine("Selection Indica", x: 0.4113, y: 0.5675, width: 0.2224, height: 0.0333),
            RecognizedLine("omro", x: 0.4157, y: 0.5310, width: 0.0799, height: 0.0233),
            RecognizedLine("Tel: +31 181 72 91 31", x: 0.5044, y: 0.5155, width: 0.1308, height: 0.0178),
            RecognizedLine("19.05.2026 - 04.06.2026 / 28.09.2026", x: 0.5058, y: 0.4806, width: 0.2297, height: 0.0177),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000104", x: 0.5058, y: 0.4477, width: 0.2282, height: 0.0174),
            RecognizedLine("8 721098 003880", x: 0.7483, y: 0.5037, width: 0.0137, height: 0.1477),
        ],
        codes: [
            DetectedCode(kind: .ean, payload: "8721098003880"),
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000104"),
        ] as [DetectedCode]
    )
    static let caliMix = (
        lines: [
            RecognizedLine("THC", x: 0.0547, y: 0.9013, width: 0.0272, height: 0.0237),
            RecognizedLine("d77c", x: 0.1642, y: 0.8713, width: 0.0329, height: 0.0285),
            RecognizedLine("eik van kinderen", x: -0.0032, y: 0.8147, width: 0.1291, height: 0.0615),
            RecognizedLine("Cali Mix", x: 0.3805, y: 0.4290, width: 0.1080, height: 0.0377),
            RecognizedLine("THC", x: 0.4709, y: 0.3992, width: 0.0233, height: 0.0155),
            RecognizedLine("CBD", x: 0.4709, y: 0.3798, width: 0.0262, height: 0.0174),
            RecognizedLine("Gewicht", x: 0.4709, y: 0.3605, width: 0.0451, height: 0.0174),
            RecognizedLine("Geoogst", x: 0.4738, y: 0.3428, width: 0.0437, height: 0.0160),
            RecognizedLine("Verpakt", x: 0.4724, y: 0.3217, width: 0.0422, height: 0.0174),
            RecognizedLine("24%", x: 0.5930, y: 0.4050, width: 0.0262, height: 0.0155),
            RecognizedLine("<1%", x: 0.5945, y: 0.3857, width: 0.0262, height: 0.0174),
            RecognizedLine("5 gram", x: 0.5797, y: 0.3638, width: 0.0410, height: 0.0192),
            RecognizedLine("28-07-2026", x: 0.5607, y: 0.3481, width: 0.0616, height: 0.0171),
            RecognizedLine("12-10-2026", x: 0.5610, y: 0.3289, width: 0.0627, height: 0.0186),
            RecognizedLine("Track & Trace", x: 0.3852, y: 0.3040, width: 0.0669, height: 0.0140),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000103", x: 0.3848, y: 0.2780, width: 0.2114, height: 0.0264),
            RecognizedLine("LB-CALIMIX-05", x: 0.4937, y: 0.2162, width: 0.0867, height: 0.0217),
        ],
        codes: [
            DetectedCode(kind: .code128, payload: "LB-CALIMIX-05"),
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000103"),
        ] as [DetectedCode]
    )
    static let phenoHunt = (
        lines: [
            RecognizedLine("THC", x: 0.1366, y: 0.9109, width: 0.0218, height: 0.0174),
            RecognizedLine("ud buiten bereik van kinderen", x: -0.0043, y: 0.7892, width: 0.2074, height: 0.0982),
            RecognizedLine("аттс", x: 0.2369, y: 0.8857, width: 0.0262, height: 0.0174),
            RecognizedLine("Pheno Hunt Miix 5 grarn", x: 0.3757, y: 0.5481, width: 0.3025, height: 0.0534),
            RecognizedLine("HС: 25%", x: 0.5492, y: 0.5115, width: 0.1139, height: 0.0241),
            RecognizedLine("BD: <1%", x: 0.5493, y: 0.4811, width: 0.1152, height: 0.0281),
            RecognizedLine("Geoogst op 08/05/202€", x: 0.4794, y: 0.4409, width: 0.1895, height: 0.0284),
            RecognizedLine("Verpakt op 14/09/2026", x: 0.4792, y: 0.4118, width: 0.1899, height: 0.0326),
            RecognizedLine("Track en Trace", x: 0.3820, y: 0.3985, width: 0.0834, height: 0.0173),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000112", x: 0.3704, y: 0.3621, width: 0.2170, height: 0.0222),
            RecognizedLine("PHMX-FLW-50G", x: 0.5883, y: 0.3574, width: 0.0822, height: 0.0194),
        ],
        codes: [
            DetectedCode(kind: .code128, payload: "PHMX-FLW-50G"),
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000111"),
        ] as [DetectedCode]
    )
    static let speakSpecial = (
        lines: [
            RecognizedLine("THC: 26%", x: 0.2717, y: 0.5210, width: 0.0771, height: 0.0220),
            RecognizedLine("CBD: <1%", x: 0.2747, y: 0.4805, width: 0.0683, height: 0.0196),
            RecognizedLine("Speak Special", x: 0.4066, y: 0.5879, width: 0.2362, height: 0.0587),
            RecognizedLine("Hand Trimmed", x: 0.4535, y: 0.5600, width: 0.1395, height: 0.0275),
            RecognizedLine("Geoogst: 27-03-2026 Verpakt:28-08-2026", x: 0.3647, y: 0.5159, width: 0.3113, height: 0.0327),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000114", x: 0.3939, y: 0.4787, width: 0.2500, height: 0.0194),
            RecognizedLine("2.5 gram", x: 0.6942, y: 0.5920, width: 0.0766, height: 0.0276),
            RecognizedLine("TST", x: 0.7456, y: 0.5736, width: 0.0247, height: 0.0155),
        ],
        codes: [
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000114"),
        ] as [DetectedCode]
    )
    static let amnesiaHaze = (
        lines: [
            RecognizedLine("THC", x: 0.4084, y: 0.5426, width: 0.0276, height: 0.0155),
            RecognizedLine("HC 24%", x: 0.3892, y: 0.4901, width: 0.0602, height: 0.0204),
            RecognizedLine("CBD <1%", x: 0.3866, y: 0.4667, width: 0.0640, height: 0.0178),
            RecognizedLine("S pr", x: 0.3976, y: 0.4380, width: 0.0287, height: 0.0204),
            RecognizedLine("C Q G Amnesia", x: 0.4838, y: 0.5574, width: 0.1646, height: 0.0292),
            RecognizedLine("Haze Master Cut", x: 0.4824, y: 0.5264, width: 0.1807, height: 0.0311),
            RecognizedLine("Te. +51 181 72 91 31", x: 0.5505, y: 0.4814, width: 0.0995, height: 0.0209),
            RecognizedLine("09 08 2026 - 19.06 2.8", x: 0.5492, y: 0.4607, width: 0.1153, height: 0.0193),
            RecognizedLine("40 L8 2026", x: 0.6642, y: 0.4608, width: 0.0610, height: 0.0120),
            RecognizedLine("PRD-00000000-0000-4000", x: 0.5506, y: 0.4404, width: 0.0993, height: 0.0163),
            RecognizedLine("0: 00/00000000", x: 0.6584, y: 0.4399, width: 0.0654, height: 0.0117),
            RecognizedLine("002081", x: 0.7311, y: 0.4787, width: 0.0058, height: 0.0407),
        ],
        codes: [
        ] as [DetectedCode]
    )
    static let whiteWidow = (
        lines: [
            RecognizedLine("BIO Sunkissed White Widow 5g", x: 0.3277, y: 0.6989, width: 0.3772, height: 0.0817),
            RecognizedLine("Aardachtig Organics", x: 0.3350, y: 0.6561, width: 0.1500, height: 0.0357),
            RecognizedLine("THC %", x: 0.3605, y: 0.6200, width: 0.0422, height: 0.0176),
            RecognizedLine("CBD %", x: 0.3590, y: 0.5950, width: 0.0422, height: 0.0175),
            RecognizedLine("20%", x: 0.4520, y: 0.6279, width: 0.0276, height: 0.0174),
            RecognizedLine("<1%", x: 0.4512, y: 0.6018, width: 0.0292, height: 0.0198),
            RecognizedLine("Frack en Trace", x: 0.3877, y: 0.5611, width: 0.0809, height: 0.0206),
            RecognizedLine("Geoogst: 21-05-2026", x: 0.5615, y: 0.6338, width: 0.1271, height: 0.0372),
            RecognizedLine("Verpakt: 07-07-2026", x: 0.5617, y: 0.6106, width: 0.1312, height: 0.0338),
            RecognizedLine("Bijsluiter", x: 0.6026, y: 0.5765, width: 0.0520, height: 0.0235),
            RecognizedLine("www.aardachtig.nl", x: 0.3354, y: 0.3053, width: 0.1082, height: 0.0232),
            RecognizedLine("PRD-00000000-0000-4000-8000-000000000108", x: 0.3962, y: 0.3523, width: 0.2802, height: 0.0369),
            RecognizedLine("contact@aardachtig.ni", x: 0.4677, y: 0.3112, width: 0.1403, height: 0.0264),
            RecognizedLine("Tel: 085-2738149", x: 0.6289, y: 0.3227, width: 0.1115, height: 0.0248),
            RecognizedLine("ГНС", x: 0.6134, y: 0.2171, width: 0.0218, height: 0.0155),
            RecognizedLine("Houd buiten bereik van kinderen", x: 0.4197, y: 0.1398, width: 0.2491, height: 0.0290),
            RecognizedLine("d77c", x: 0.7151, y: 0.1570, width: 0.0334, height: 0.0174),
        ],
        codes: [
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000108"),
            DetectedCode(kind: .qr, payload: "https://open.overheid.nl/documenten/75c79be3-b473-4c6c-9d79-736e7c30cfb7/file"),
        ] as [DetectedCode]
    )
}
