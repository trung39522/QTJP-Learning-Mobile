// Rules and examples ported from the QTJP React grammar reference tables.
const verbFormTables = <Map<String, dynamic>>[
  {
    "id": "dictionary",
    "number": 1,
    "label": "Thể từ điển",
    "japanese": "辞書形",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đưa âm cuối của thân ます từ hàng い về hàng う.",
        "example": "書きます → 書く",
      },
      {
        "name": "Nhóm II（一段）",
        "rule": "Bỏ ます, thêm る.",
        "example": "食べます → 食べる",
      },
      {
        "name": "Nhóm III（不規則）",
        "rule": ["します → する", "来ます → 来る"],
        "example": ["勉強します → 勉強する", "来ます → 来る"],
      },
    ],
  },
  {
    "id": "negative",
    "number": 2,
    "label": "Thể phủ định",
    "japanese": "ない形",
    "note": "Riêng động từ nhóm I kết thúc bằng う: đổi う → わ rồi thêm ない.",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng あ + ない.",
        "example": ["書く → 書かない", "会う → 会わない"],
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + ない.", "example": "食べる → 食べない"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → しない", "来る → 来ない"],
        "example": ["勉強する → 勉強しない", "来る → 来ない"],
      },
    ],
  },
  {
    "id": "te",
    "number": 3,
    "label": "Thể て",
    "japanese": "て形",
    "note": "Ngoại lệ cần nhớ: 行く → 行って.",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": ["う・つ・る → って", "む・ぶ・ぬ → んで", "く → いて", "ぐ → いで", "す → して"],
        "example": ["会う → 会って", "遊ぶ → 遊んで", "書く → 書いて", "泳ぐ → 泳いで", "話す → 話して"],
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + て.", "example": "食べる → 食べて"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → して", "来る → 来て"],
        "example": ["勉強する → 勉強して", "来る → 来て"],
      },
    ],
  },
  {
    "id": "ta",
    "number": 4,
    "label": "Thể た",
    "japanese": "た形",
    "note": "Quy tắc giống thể て: て → た và で → だ.",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": ["う・つ・る → った", "む・ぶ・ぬ → んだ", "く → いた", "ぐ → いだ", "す → した"],
        "example": ["書く → 書いた", "遊ぶ → 遊んだ"],
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + た.", "example": "食べる → 食べた"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → した", "来る → 来た"],
        "example": ["勉強する → 勉強した", "来る → 来た"],
      },
    ],
  },
  {
    "id": "volitional",
    "number": 5,
    "label": "Thể ý chí",
    "japanese": "意向形",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng お + う.",
        "example": "行く → 行こう",
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + よう.", "example": "食べる → 食べよう"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → しよう", "来る → 来よう"],
        "example": ["勉強する → 勉強しよう", "来る → 来よう"],
      },
    ],
  },
  {
    "id": "potential",
    "number": 6,
    "label": "Thể khả năng",
    "japanese": "可能形",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng え + る.",
        "example": "書く → 書ける",
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + られる.", "example": "食べる → 食べられる"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → できる", "来る → 来られる"],
        "example": ["勉強する → 勉強できる", "来る → 来られる"],
      },
    ],
  },
  {
    "id": "conditional",
    "number": 7,
    "label": "Thể điều kiện",
    "japanese": "条件形（～ば）",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng え + ば.",
        "example": "行く → 行けば",
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + れば.", "example": "食べる → 食べれば"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → すれば", "来る → 来れば"],
        "example": ["勉強する → 勉強すれば", "来る → 来れば"],
      },
    ],
  },
  {
    "id": "imperative",
    "number": 8,
    "label": "Thể mệnh lệnh",
    "japanese": "命令形",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng え.",
        "example": "行く → 行け",
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + ろ.", "example": "食べる → 食べろ"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → しろ／せよ", "来る → 来い"],
        "example": ["勉強する → 勉強しろ", "来る → 来い"],
      },
    ],
  },
  {
    "id": "prohibitive",
    "number": 9,
    "label": "Thể cấm chỉ",
    "japanese": "禁止形（辞書形＋な）",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Giữ nguyên thể từ điển + な.",
        "example": "行く → 行くな",
      },
      {
        "name": "Nhóm II（一段）",
        "rule": "Giữ nguyên thể từ điển + な.",
        "example": "食べる → 食べるな",
      },
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する + な", "来る + な"],
        "example": ["する → するな", "来る → 来るな"],
      },
    ],
  },
  {
    "id": "passive",
    "number": 10,
    "label": "Thể bị động",
    "japanese": "受身形",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng あ + れる.",
        "example": ["書く → 書かれる", "会う → 会われる"],
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + られる.", "example": "食べる → 食べられる"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → される", "来る → 来られる"],
        "example": ["勉強する → 勉強される", "来る → 来られる"],
      },
    ],
  },
  {
    "id": "causative",
    "number": 11,
    "label": "Thể sai khiến",
    "japanese": "使役形",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng あ + せる.",
        "example": "書く → 書かせる",
      },
      {"name": "Nhóm II（一段）", "rule": "Bỏ る + させる.", "example": "食べる → 食べさせる"},
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → させる", "来る → 来させる"],
        "example": ["勉強する → 勉強させる", "来る → 来させる"],
      },
    ],
  },
  {
    "id": "causative-passive",
    "number": 12,
    "label": "Thể sai khiến bị động",
    "japanese": "使役受身形",
    "groups": [
      {
        "name": "Nhóm I（五段）",
        "rule": "Đổi âm cuối hàng う → hàng あ + される／させられる.",
        "example": "書く → 書かされる／書かせられる",
      },
      {
        "name": "Nhóm II（一段）",
        "rule": "Bỏ る + させられる.",
        "example": "食べる → 食べさせられる",
      },
      {
        "name": "Nhóm III（不規則）",
        "rule": ["する → させられる", "来る → 来させられる"],
        "example": ["勉強する → 勉強させられる", "来る → 来させられる"],
      },
    ],
  },
];
