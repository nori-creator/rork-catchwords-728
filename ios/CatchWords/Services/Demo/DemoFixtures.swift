#if DEBUG
import Foundation

/// Fixture content for the offline demo backend (`-uiDemo <learningLanguage>`), one pack per learning language.
///
/// GENERATED: the packs are written and checked outside the app (a port of LanguageRules / ChunkRules runs
/// over every reader-language text so the demo explanations pass the same reader filters as real cards).
/// Each pack is plain JSON in a raw string so the Swift type checker never sees a large literal.
///
/// Pack shape:
/// - words: headword, reading_zhuyin, pinyin, part_of_speech, category_key, level, example_sentence, emoji, key,
///   language, explain { <reader>: { meaning, example_translation, extras } }
///   (index 0-5 are seeded with photos, 6 without a photo, 7-8 are new words offered by the AI functions)
/// - variants: other names of a word (CandidatePickerView "other ways to say it")
/// - distinctions, wordbook, journal, prompts, patterns, synth (templates for unknown headwords),
///   places (lat / lng / name per reader), common (caption, generic feedback, display name)
nonisolated enum DemoFixtures {
    /// The parsed pack for a learning language ("zh-TW", "en", "ja"); empty when it cannot be read.
    static func pack(for language: String) -> [String: Any] {
        let raw: String
        switch language {
        case "en": raw = en
        case "ja": raw = ja
        default: raw = zhTW
        }
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any] else { return [:] }
        return dict
    }

    private static let zhTW: String = #"""
    {
     "words": [
      {
       "key": "mango",
       "headword": "芒果",
       "reading_zhuyin": "ㄇㄤˊ ㄍㄨㄛˇ",
       "pinyin": "mángguǒ",
       "part_of_speech": "N",
       "category_key": "fruit",
       "level": "TOCFL-2",
       "emoji": "🥭",
       "example_sentence": "夏天的芒果特別甜。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "マンゴー",
         "example_translation": "夏のマンゴーは特に甘い。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我想吃芒果冰。",
            "ja": "マンゴーかき氷が食べたい。",
            "scene": "かき氷屋で"
           },
           {
            "zh": "這顆芒果熟了沒？",
            "ja": "このマンゴー、もう熟してる？",
            "scene": "市場で"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "芒果",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "甜",
              "pos": "Vs",
              "ja": "甘い"
             }
            ],
            "ja": "マンゴーがとても甘い"
           },
           {
            "parts": [
             {
              "text": "切",
              "pos": "V"
             },
             {
              "text": "芒果",
              "pos": "N"
             }
            ],
            "ja": "マンゴーを切る"
           },
           {
            "parts": [
             {
              "text": "請",
              "pos": "V"
             },
             {
              "text": "朋友",
              "pos": "N",
              "slot": true,
              "ja": "友だち",
              "alts": [
               {
                "text": "家人",
                "ja": "家族"
               },
               {
                "text": "同事",
                "ja": "同僚"
               }
              ]
             },
             {
              "text": "吃",
              "pos": "V"
             },
             {
              "text": "芒果",
              "pos": "N"
             }
            ],
            "ja": "友だちにマンゴーをごちそうする"
           }
          ],
          "measure_words": [
           {
            "word": "顆",
            "zhuyin": "ㄎㄜ",
            "note": "丸ごと一つの果物を数える"
           },
           {
            "word": "盒",
            "zhuyin": "ㄏㄜˊ",
            "note": "箱入りで売っているとき"
           }
          ],
          "related_words": [
           {
            "word": "愛文芒果",
            "kind": "rel",
            "reading": "ㄞˋ ㄨㄣˊ ㄇㄤˊ ㄍㄨㄛˇ",
            "note": "台湾で人気の品種"
           },
           {
            "word": "鳳梨",
            "kind": "rel",
            "reading": "ㄈㄥˋ ㄌㄧˊ",
            "note": "同じく台湾の夏を代表する果物"
           }
          ],
          "pronunciation_tips": "「芒」は第2声で上がり、「果」は第3声で低く沈めます。",
          "etymology": "「芒果」は音を写した外来語で、英語の mango と同じく南アジアの言葉にさかのぼります。",
          "radicals": "芒：艹（くさかんむり）／果：木（き）",
          "mnemonic": "「マングオ」の音は「マンゴー」にそっくり。",
          "taiwan_note": "台湾の夏の定番は「芒果冰」（マンゴーかき氷）。台南の愛文マンゴーが有名です。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "mango",
         "example_translation": "Mangoes in summer are especially sweet.",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我想吃芒果冰。",
            "ja": "I want mango shaved ice.",
            "scene": "At a shaved-ice shop"
           },
           {
            "zh": "這顆芒果熟了沒？",
            "ja": "Is this mango ripe yet?",
            "scene": "At the market"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "芒果",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "甜",
              "pos": "Vs",
              "ja": "sweet"
             }
            ],
            "ja": "the mango is very sweet"
           },
           {
            "parts": [
             {
              "text": "切",
              "pos": "V"
             },
             {
              "text": "芒果",
              "pos": "N"
             }
            ],
            "ja": "cut a mango"
           },
           {
            "parts": [
             {
              "text": "請",
              "pos": "V"
             },
             {
              "text": "朋友",
              "pos": "N",
              "slot": true,
              "ja": "a friend",
              "alts": [
               {
                "text": "家人",
                "ja": "my family"
               },
               {
                "text": "同事",
                "ja": "a coworker"
               }
              ]
             },
             {
              "text": "吃",
              "pos": "V"
             },
             {
              "text": "芒果",
              "pos": "N"
             }
            ],
            "ja": "treat a friend to mango"
           }
          ],
          "measure_words": [
           {
            "word": "顆",
            "zhuyin": "ㄎㄜ",
            "note": "for one whole fruit"
           },
           {
            "word": "盒",
            "zhuyin": "ㄏㄜˊ",
            "note": "when sold in a box"
           }
          ],
          "related_words": [
           {
            "word": "愛文芒果",
            "kind": "rel",
            "reading": "ㄞˋ ㄨㄣˊ ㄇㄤˊ ㄍㄨㄛˇ",
            "note": "a popular variety in Taiwan"
           },
           {
            "word": "鳳梨",
            "kind": "rel",
            "reading": "ㄈㄥˋ ㄌㄧˊ",
            "note": "another classic Taiwanese summer fruit"
           }
          ],
          "pronunciation_tips": "“芒” is second tone (rising); “果” is third tone, so keep it low.",
          "etymology": "“芒果” is a loanword written for its sound; like English “mango”, it goes back to a South Asian language.",
          "radicals": "芒: 艹 (grass) / 果: 木 (tree)",
          "mnemonic": "Say “mángguǒ” fast and it sounds just like “mango”.",
          "taiwan_note": "Taiwan's classic summer treat is “芒果冰” (mango shaved ice). Mangoes from Tainan are famous.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "bubbletea",
       "headword": "珍珠奶茶",
       "reading_zhuyin": "ㄓㄣ ㄓㄨ ㄋㄞˇ ㄔㄚˊ",
       "pinyin": "zhēnzhū nǎichá",
       "part_of_speech": "N",
       "category_key": "drink",
       "level": "TOCFL-2",
       "emoji": "🧋",
       "example_sentence": "我每天下午都想喝一杯珍珠奶茶。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "タピオカミルクティー",
         "example_translation": "毎日午後になるとタピオカミルクティーが飲みたくなる。",
         "extras": {
          "frequency_level": 2,
          "register_scale": -1,
          "examples_extra": [
           {
            "zh": "珍珠奶茶半糖少冰，謝謝。",
            "ja": "タピオカミルクティー、甘さ半分・氷少なめでお願いします。",
            "scene": "ドリンクスタンドで注文"
           },
           {
            "zh": "這家的珍珠很有嚼勁。",
            "ja": "この店のタピオカは歯ごたえがある。",
            "scene": "友だちとの会話"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "點",
              "pos": "V"
             },
             {
              "text": "珍珠奶茶",
              "pos": "N"
             }
            ],
            "ja": "タピオカミルクティーを注文する"
           },
           {
            "parts": [
             {
              "text": "喝",
              "pos": "V"
             },
             {
              "text": "珍珠奶茶",
              "pos": "N"
             }
            ],
            "ja": "タピオカミルクティーを飲む"
           },
           {
            "parts": [
             {
              "text": "珍珠奶茶",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "好喝",
              "pos": "Vs",
              "ja": "おいしい"
             }
            ],
            "ja": "タピオカミルクティーがとてもおいしい"
           }
          ],
          "measure_words": [
           {
            "word": "杯",
            "zhuyin": "ㄅㄟ",
            "note": "カップ入りの飲み物を数える"
           }
          ],
          "related_words": [
           {
            "word": "波霸奶茶",
            "kind": "syn",
            "reading": "ㄅㄛ ㄅㄚˋ ㄋㄞˇ ㄔㄚˊ",
            "note": "大粒のタピオカ入りを指す言い方"
           },
           {
            "word": "紅茶",
            "kind": "rel",
            "reading": "ㄏㄨㄥˊ ㄔㄚˊ",
            "note": "ベースになる紅茶"
           }
          ],
          "pronunciation_tips": "「珍珠」はどちらも第1声で高く平らに。「奶」の第3声は低く抑えます。",
          "etymology": "「珍珠」は真珠のこと。丸いタピオカを真珠に見立てた名前です。",
          "radicals": "珍・珠：王（たまへん）／奶：女（おんなへん）／茶：艹（くさかんむり）",
          "mnemonic": "「真珠（珍珠）」が沈んだ「ミルクティー（奶茶）」と覚えよう。",
          "taiwan_note": "台湾では略して「珍奶」とも言います。注文では甘さと氷の量を選ぶのがふつうです。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "bubble tea",
         "example_translation": "Every afternoon I feel like having a bubble tea.",
         "extras": {
          "frequency_level": 2,
          "register_scale": -1,
          "examples_extra": [
           {
            "zh": "珍珠奶茶半糖少冰，謝謝。",
            "ja": "Bubble tea, half sugar, light ice, please.",
            "scene": "Ordering at a drink stand"
           },
           {
            "zh": "這家的珍珠很有嚼勁。",
            "ja": "The pearls here are nice and chewy.",
            "scene": "Chatting with a friend"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "點",
              "pos": "V"
             },
             {
              "text": "珍珠奶茶",
              "pos": "N"
             }
            ],
            "ja": "order a bubble tea"
           },
           {
            "parts": [
             {
              "text": "喝",
              "pos": "V"
             },
             {
              "text": "珍珠奶茶",
              "pos": "N"
             }
            ],
            "ja": "drink bubble tea"
           },
           {
            "parts": [
             {
              "text": "珍珠奶茶",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "好喝",
              "pos": "Vs",
              "ja": "good"
             }
            ],
            "ja": "the bubble tea is very good"
           }
          ],
          "measure_words": [
           {
            "word": "杯",
            "zhuyin": "ㄅㄟ",
            "note": "for a drink in a cup"
           }
          ],
          "related_words": [
           {
            "word": "波霸奶茶",
            "kind": "syn",
            "reading": "ㄅㄛ ㄅㄚˋ ㄋㄞˇ ㄔㄚˊ",
            "note": "the version with extra-large pearls"
           },
           {
            "word": "紅茶",
            "kind": "rel",
            "reading": "ㄏㄨㄥˊ ㄔㄚˊ",
            "note": "the black tea it is made from"
           }
          ],
          "pronunciation_tips": "Both syllables of “珍珠” are first tone: high and flat. Keep the third tone of “奶” low.",
          "etymology": "“珍珠” means “pearl”: the round tapioca balls are compared to pearls.",
          "radicals": "珍, 珠: 王 (jade) / 奶: 女 (woman) / 茶: 艹 (grass)",
          "mnemonic": "Picture pearls (珍珠) sinking into milk tea (奶茶).",
          "taiwan_note": "In Taiwan people often shorten it to “珍奶”. When ordering you usually choose the sugar and ice levels.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "umbrella",
       "headword": "雨傘",
       "reading_zhuyin": "ㄩˇ ㄙㄢˇ",
       "pinyin": "yǔsǎn",
       "part_of_speech": "N",
       "category_key": "accessory",
       "level": "TOCFL-2",
       "emoji": "☂️",
       "example_sentence": "外面在下雨，記得帶雨傘。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "雨傘、傘",
         "example_translation": "外は雨が降っているから、傘を持っていくのを忘れないで。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我的雨傘忘在捷運上了。",
            "ja": "傘をMRTに置き忘れた。",
            "scene": "落とし物をしたとき"
           },
           {
            "zh": "可以借我雨傘嗎？",
            "ja": "傘を貸してもらえますか？",
            "scene": "急に雨が降ってきたとき"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "撐",
              "pos": "V"
             },
             {
              "text": "雨傘",
              "pos": "N"
             }
            ],
            "ja": "傘をさす"
           },
           {
            "parts": [
             {
              "text": "帶",
              "pos": "V"
             },
             {
              "text": "雨傘",
              "pos": "N"
             }
            ],
            "ja": "傘を持っていく"
           },
           {
            "parts": [
             {
              "text": "借",
              "pos": "V"
             },
             {
              "text": "雨傘",
              "pos": "N"
             }
            ],
            "ja": "傘を借りる"
           }
          ],
          "measure_words": [
           {
            "word": "把",
            "zhuyin": "ㄅㄚˇ",
            "note": "柄のある道具を数える"
           }
          ],
          "related_words": [
           {
            "word": "陽傘",
            "kind": "rel",
            "reading": "ㄧㄤˊ ㄙㄢˇ",
            "note": "日差しをよける日傘"
           },
           {
            "word": "雨衣",
            "kind": "rel",
            "reading": "ㄩˇ ㄧ",
            "note": "バイクに乗るときによく使うレインコート"
           }
          ],
          "pronunciation_tips": "「雨」も「傘」も第3声。続くと前の「雨」は第2声のように上がります。",
          "etymology": "「傘」は広げた傘の形からできた字で、中に人が何人もいるように見えます。",
          "radicals": "雨：雨（あめ）／傘：人（ひと）",
          "mnemonic": "「傘」の字の中の「人」たちが雨宿りしていると覚えよう。",
          "taiwan_note": "台湾の夏は急な夕立が多く、日傘と雨傘を兼ねた「晴雨傘」を持ち歩く人がたくさんいます。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "umbrella",
         "example_translation": "It's raining outside, so remember to take an umbrella.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我的雨傘忘在捷運上了。",
            "ja": "I left my umbrella on the MRT.",
            "scene": "When you've lost something"
           },
           {
            "zh": "可以借我雨傘嗎？",
            "ja": "Could I borrow your umbrella?",
            "scene": "When it suddenly starts raining"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "撐",
              "pos": "V"
             },
             {
              "text": "雨傘",
              "pos": "N"
             }
            ],
            "ja": "hold up an umbrella"
           },
           {
            "parts": [
             {
              "text": "帶",
              "pos": "V"
             },
             {
              "text": "雨傘",
              "pos": "N"
             }
            ],
            "ja": "take an umbrella"
           },
           {
            "parts": [
             {
              "text": "借",
              "pos": "V"
             },
             {
              "text": "雨傘",
              "pos": "N"
             }
            ],
            "ja": "borrow an umbrella"
           }
          ],
          "measure_words": [
           {
            "word": "把",
            "zhuyin": "ㄅㄚˇ",
            "note": "for things with a handle"
           }
          ],
          "related_words": [
           {
            "word": "陽傘",
            "kind": "rel",
            "reading": "ㄧㄤˊ ㄙㄢˇ",
            "note": "a parasol for the sun"
           },
           {
            "word": "雨衣",
            "kind": "rel",
            "reading": "ㄩˇ ㄧ",
            "note": "a raincoat, common on scooters"
           }
          ],
          "pronunciation_tips": "Both “雨” and “傘” are third tone. Together, the first one rises like a second tone.",
          "etymology": "The character “傘” is a picture of an open umbrella, with little people sheltering under it.",
          "radicals": "雨: 雨 (rain) / 傘: 人 (person)",
          "mnemonic": "Spot the little 人 (people) hiding from the rain inside 傘.",
          "taiwan_note": "Taiwan's summers bring sudden afternoon showers, so many people carry a “晴雨傘” that works for both sun and rain.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "cat",
       "headword": "貓",
       "reading_zhuyin": "ㄇㄠ",
       "pinyin": "māo",
       "part_of_speech": "N",
       "category_key": "animal",
       "level": "TOCFL-1",
       "emoji": "🐈",
       "example_sentence": "我家的貓很喜歡睡覺。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "猫",
         "example_translation": "うちの猫は寝るのが大好きだ。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "巷子裡有一隻黑貓。",
            "ja": "路地に黒猫が一匹いる。",
            "scene": "散歩中に"
           },
           {
            "zh": "你養貓還是養狗？",
            "ja": "猫を飼ってる？それとも犬？",
            "scene": "ペットの話題"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "養",
              "pos": "V"
             },
             {
              "text": "貓",
              "pos": "N"
             }
            ],
            "ja": "猫を飼う"
           },
           {
            "parts": [
             {
              "text": "餵",
              "pos": "V"
             },
             {
              "text": "貓",
              "pos": "N"
             }
            ],
            "ja": "猫にえさをやる"
           },
           {
            "parts": [
             {
              "text": "貓",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "可愛",
              "pos": "Vs",
              "ja": "かわいい"
             }
            ],
            "ja": "猫がとてもかわいい"
           }
          ],
          "measure_words": [
           {
            "word": "隻",
            "zhuyin": "ㄓ",
            "note": "動物を数える"
           }
          ],
          "related_words": [
           {
            "word": "貓咪",
            "kind": "syn",
            "reading": "ㄇㄠ ㄇㄧ",
            "note": "親しみを込めた言い方"
           },
           {
            "word": "狗",
            "kind": "rel",
            "reading": "ㄍㄡˇ",
            "note": "犬"
           }
          ],
          "pronunciation_tips": "第1声で高く平らに伸ばします。「マオ」と一息で。",
          "etymology": "「貓」の左側は動物を表す部首で、右側の「苗」が音を表します。",
          "radicals": "貓：豸（むじなへん）",
          "mnemonic": "鳴き声の「ミャオ」が「マオ」に聞こえると覚えよう。",
          "taiwan_note": "台湾北部の猴硐（ホウトン）は猫がたくさんいる「猫村」として有名です。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "cat",
         "example_translation": "My cat loves to sleep.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "巷子裡有一隻黑貓。",
            "ja": "There's a black cat in the alley.",
            "scene": "On a walk"
           },
           {
            "zh": "你養貓還是養狗？",
            "ja": "Do you have a cat or a dog?",
            "scene": "Talking about pets"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "養",
              "pos": "V"
             },
             {
              "text": "貓",
              "pos": "N"
             }
            ],
            "ja": "keep a cat"
           },
           {
            "parts": [
             {
              "text": "餵",
              "pos": "V"
             },
             {
              "text": "貓",
              "pos": "N"
             }
            ],
            "ja": "feed the cat"
           },
           {
            "parts": [
             {
              "text": "貓",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "可愛",
              "pos": "Vs",
              "ja": "cute"
             }
            ],
            "ja": "the cat is very cute"
           }
          ],
          "measure_words": [
           {
            "word": "隻",
            "zhuyin": "ㄓ",
            "note": "for animals"
           }
          ],
          "related_words": [
           {
            "word": "貓咪",
            "kind": "syn",
            "reading": "ㄇㄠ ㄇㄧ",
            "note": "an affectionate way to say it"
           },
           {
            "word": "狗",
            "kind": "rel",
            "reading": "ㄍㄡˇ",
            "note": "dog"
           }
          ],
          "pronunciation_tips": "First tone: high and level. Say it in one smooth breath.",
          "etymology": "The left part of “貓” marks an animal, and the right part “苗” gives the sound.",
          "radicals": "貓: 豸 (beast)",
          "mnemonic": "A cat's “meow” sounds a lot like “māo”.",
          "taiwan_note": "Houtong in northern Taiwan is famous as a “cat village” full of friendly cats.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "mrt",
       "headword": "捷運",
       "reading_zhuyin": "ㄐㄧㄝˊ ㄩㄣˋ",
       "pinyin": "jiéyùn",
       "part_of_speech": "N",
       "category_key": "transport",
       "level": "TOCFL-3",
       "emoji": "🚇",
       "example_sentence": "我們搭捷運去淡水吧。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "MRT（都市高速鉄道）",
         "example_translation": "MRTに乗って淡水に行こうよ。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "捷運站就在前面。",
            "ja": "MRTの駅はすぐ先です。",
            "scene": "道案内"
           },
           {
            "zh": "在捷運上不能吃東西。",
            "ja": "MRTの中では飲食禁止です。",
            "scene": "マナーの説明"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "搭",
              "pos": "V"
             },
             {
              "text": "捷運",
              "pos": "N"
             }
            ],
            "ja": "MRTに乗る"
           },
           {
            "parts": [
             {
              "text": "坐",
              "pos": "V"
             },
             {
              "text": "捷運",
              "pos": "N"
             },
             {
              "text": "上班",
              "pos": "V",
              "ja": "通勤する"
             }
            ],
            "ja": "MRTで通勤する"
           },
           {
            "parts": [
             {
              "text": "轉",
              "pos": "V"
             },
             {
              "text": "捷運",
              "pos": "N"
             }
            ],
            "ja": "MRTに乗り換える"
           }
          ],
          "measure_words": [
           {
            "word": "條",
            "zhuyin": "ㄊㄧㄠˊ",
            "note": "路線を数える"
           }
          ],
          "related_words": [
           {
            "word": "地鐵",
            "kind": "syn",
            "reading": "ㄉㄧˋ ㄊㄧㄝˇ",
            "note": "中国大陸などでの言い方"
           },
           {
            "word": "悠遊卡",
            "kind": "rel",
            "reading": "ㄧㄡ ㄧㄡˊ ㄎㄚˇ",
            "note": "台北の交通系ICカード"
           }
          ],
          "pronunciation_tips": "「捷」は第2声で上がり、「運」は第4声で強く下げます。",
          "etymology": "「捷」は速い、「運」は運ぶという意味。速く人を運ぶ交通機関です。",
          "radicals": "捷：扌（てへん）／運：辶（しんにょう）",
          "mnemonic": "「速く（捷）運ぶ（運）」電車＝MRT。",
          "taiwan_note": "台北・新北・桃園・台中・高雄に捷運があります。車内での飲食は罰金の対象です。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "MRT, the metro",
         "example_translation": "Let's take the MRT to Tamsui.",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "捷運站就在前面。",
            "ja": "The MRT station is just ahead.",
            "scene": "Giving directions"
           },
           {
            "zh": "在捷運上不能吃東西。",
            "ja": "You can't eat on the MRT.",
            "scene": "Explaining the rules"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "搭",
              "pos": "V"
             },
             {
              "text": "捷運",
              "pos": "N"
             }
            ],
            "ja": "take the MRT"
           },
           {
            "parts": [
             {
              "text": "坐",
              "pos": "V"
             },
             {
              "text": "捷運",
              "pos": "N"
             },
             {
              "text": "上班",
              "pos": "V",
              "ja": "commute"
             }
            ],
            "ja": "commute by MRT"
           },
           {
            "parts": [
             {
              "text": "轉",
              "pos": "V"
             },
             {
              "text": "捷運",
              "pos": "N"
             }
            ],
            "ja": "transfer to the MRT"
           }
          ],
          "measure_words": [
           {
            "word": "條",
            "zhuyin": "ㄊㄧㄠˊ",
            "note": "for lines"
           }
          ],
          "related_words": [
           {
            "word": "地鐵",
            "kind": "syn",
            "reading": "ㄉㄧˋ ㄊㄧㄝˇ",
            "note": "the word used in mainland China"
           },
           {
            "word": "悠遊卡",
            "kind": "rel",
            "reading": "ㄧㄡ ㄧㄡˊ ㄎㄚˇ",
            "note": "Taipei's transit card"
           }
          ],
          "pronunciation_tips": "“捷” rises (second tone); “運” falls sharply (fourth tone).",
          "etymology": "“捷” means quick and “運” means to carry: transport that moves people quickly.",
          "radicals": "捷: 扌 (hand) / 運: 辶 (walk)",
          "mnemonic": "Quick (捷) + carry (運) = the MRT.",
          "taiwan_note": "Taipei, New Taipei, Taoyuan, Taichung and Kaohsiung all have an MRT. Eating or drinking on board can get you fined.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "bento",
       "headword": "便當",
       "reading_zhuyin": "ㄅㄧㄢˋ ㄉㄤ",
       "pinyin": "biàndāng",
       "part_of_speech": "N",
       "category_key": "food",
       "level": "TOCFL-2",
       "emoji": "🍱",
       "example_sentence": "中午我們去買便當吧。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "弁当",
         "example_translation": "お昼は弁当を買いに行こう。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我要一個排骨便當。",
            "ja": "排骨弁当を一つください。",
            "scene": "弁当屋で注文"
           },
           {
            "zh": "火車上賣的便當很有名。",
            "ja": "列車で売っている弁当は有名だ。",
            "scene": "旅行の話"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "買",
              "pos": "V"
             },
             {
              "text": "便當",
              "pos": "N"
             }
            ],
            "ja": "弁当を買う"
           },
           {
            "parts": [
             {
              "text": "帶",
              "pos": "V"
             },
             {
              "text": "便當",
              "pos": "N"
             }
            ],
            "ja": "弁当を持っていく"
           },
           {
            "parts": [
             {
              "text": "吃",
              "pos": "V"
             },
             {
              "text": "便當",
              "pos": "N"
             }
            ],
            "ja": "弁当を食べる"
           }
          ],
          "measure_words": [
           {
            "word": "個",
            "zhuyin": "ㄍㄜˋ",
            "note": "いちばん一般的な数え方"
           }
          ],
          "related_words": [
           {
            "word": "餐盒",
            "kind": "syn",
            "reading": "ㄘㄢ ㄏㄜˊ",
            "note": "やや改まった言い方"
           },
           {
            "word": "排骨",
            "kind": "rel",
            "reading": "ㄆㄞˊ ㄍㄨˇ",
            "note": "弁当の定番のおかず"
           }
          ],
          "pronunciation_tips": "「便」は第4声で鋭く下げ、「當」は第1声で高く平らに。",
          "etymology": "日本統治時代に日本語の「弁当」が伝わり、台湾で「便當」と書かれるようになりました。",
          "radicals": "便：亻（にんべん）／當：田（た）",
          "mnemonic": "日本語の「べんとう」とほぼ同じ音で覚えやすい。",
          "taiwan_note": "台湾鉄道の「台鐵便當」は駅弁として大人気。排骨や滷蛋がのっています。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "bento, a boxed meal",
         "example_translation": "Let's go and buy bento for lunch.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我要一個排骨便當。",
            "ja": "One pork chop bento, please.",
            "scene": "Ordering at a bento shop"
           },
           {
            "zh": "火車上賣的便當很有名。",
            "ja": "The bento sold on trains is famous.",
            "scene": "Talking about a trip"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "買",
              "pos": "V"
             },
             {
              "text": "便當",
              "pos": "N"
             }
            ],
            "ja": "buy a bento"
           },
           {
            "parts": [
             {
              "text": "帶",
              "pos": "V"
             },
             {
              "text": "便當",
              "pos": "N"
             }
            ],
            "ja": "bring a packed lunch"
           },
           {
            "parts": [
             {
              "text": "吃",
              "pos": "V"
             },
             {
              "text": "便當",
              "pos": "N"
             }
            ],
            "ja": "eat a bento"
           }
          ],
          "measure_words": [
           {
            "word": "個",
            "zhuyin": "ㄍㄜˋ",
            "note": "the everyday measure word"
           }
          ],
          "related_words": [
           {
            "word": "餐盒",
            "kind": "syn",
            "reading": "ㄘㄢ ㄏㄜˊ",
            "note": "a slightly more formal word"
           },
           {
            "word": "排骨",
            "kind": "rel",
            "reading": "ㄆㄞˊ ㄍㄨˇ",
            "note": "a classic bento topping"
           }
          ],
          "pronunciation_tips": "“便” falls sharply (fourth tone); “當” stays high and flat (first tone).",
          "etymology": "The word came from Japanese during the colonial period and was written “便當” in Taiwan.",
          "radicals": "便: 亻 (person) / 當: 田 (field)",
          "mnemonic": "It sounds almost like the Japanese word “bento”.",
          "taiwan_note": "The “台鐵便當” sold by Taiwan Railway is a beloved train lunch, topped with a pork chop and a braised egg.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "teppanmian",
       "headword": "鐵板麵",
       "reading_zhuyin": "ㄊㄧㄝˇ ㄅㄢˇ ㄇㄧㄢˋ",
       "pinyin": "tiěbǎnmiàn",
       "part_of_speech": "N",
       "category_key": "food",
       "level": "TOCFL-3",
       "emoji": "🍳",
       "example_sentence": "早餐店的鐵板麵加一顆蛋最好吃。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "鉄板麺（鉄板で焼いた麺）",
         "example_translation": "朝ごはん屋の鉄板麺は目玉焼きをのせるのがいちばんおいしい。",
         "extras": {
          "frequency_level": 3,
          "register_scale": -1,
          "examples_extra": [
           {
            "zh": "我要一份黑胡椒鐵板麵。",
            "ja": "黒胡椒の鉄板麺を一つください。",
            "scene": "朝ごはん屋で注文"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "點",
              "pos": "V"
             },
             {
              "text": "鐵板麵",
              "pos": "N"
             }
            ],
            "ja": "鉄板麺を注文する"
           },
           {
            "parts": [
             {
              "text": "鐵板麵",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "香",
              "pos": "Vs",
              "ja": "香ばしい"
             }
            ],
            "ja": "鉄板麺がとても香ばしい"
           }
          ],
          "measure_words": [
           {
            "word": "份",
            "zhuyin": "ㄈㄣˋ",
            "note": "一人前の料理を数える"
           }
          ],
          "related_words": [
           {
            "word": "炒麵",
            "kind": "rel",
            "reading": "ㄔㄠˇ ㄇㄧㄢˋ",
            "note": "炒めた麺料理"
           }
          ],
          "pronunciation_tips": "「鐵板」は第3声が二つ続くので、「鐵」は第2声のように上げます。",
          "etymology": "熱い鉄板（鐵板）にのせて出す麺（麵）なのでこの名前です。",
          "radicals": "鐵：金（かねへん）／麵：麥（ばくにょう）",
          "mnemonic": "ジュージュー鳴る鉄の板（鐵板）の上の麺（麵）。",
          "taiwan_note": "台湾の朝ごはん屋の定番。黒胡椒かマッシュルームのソースを選べる店が多いです。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "iron-plate noodles",
         "example_translation": "Breakfast-shop iron-plate noodles taste best with an egg on top.",
         "extras": {
          "frequency_level": 3,
          "register_scale": -1,
          "examples_extra": [
           {
            "zh": "我要一份黑胡椒鐵板麵。",
            "ja": "One black pepper iron-plate noodles, please.",
            "scene": "Ordering at a breakfast shop"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "點",
              "pos": "V"
             },
             {
              "text": "鐵板麵",
              "pos": "N"
             }
            ],
            "ja": "order iron-plate noodles"
           },
           {
            "parts": [
             {
              "text": "鐵板麵",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "香",
              "pos": "Vs",
              "ja": "fragrant"
             }
            ],
            "ja": "the noodles smell great"
           }
          ],
          "measure_words": [
           {
            "word": "份",
            "zhuyin": "ㄈㄣˋ",
            "note": "for one serving"
           }
          ],
          "related_words": [
           {
            "word": "炒麵",
            "kind": "rel",
            "reading": "ㄔㄠˇ ㄇㄧㄢˋ",
            "note": "stir-fried noodles"
           }
          ],
          "pronunciation_tips": "“鐵板” is two third tones in a row, so “鐵” rises like a second tone.",
          "etymology": "Noodles (麵) served on a hot iron plate (鐵板), hence the name.",
          "radicals": "鐵: 金 (metal) / 麵: 麥 (wheat)",
          "mnemonic": "Sizzling iron plate (鐵板) plus noodles (麵).",
          "taiwan_note": "A breakfast-shop staple in Taiwan; most shops let you pick black pepper or mushroom sauce.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "pineapple",
       "headword": "鳳梨",
       "reading_zhuyin": "ㄈㄥˋ ㄌㄧˊ",
       "pinyin": "fènglí",
       "part_of_speech": "N",
       "category_key": "fruit",
       "level": "TOCFL-3",
       "emoji": "🍍",
       "example_sentence": "台灣的鳳梨又香又甜。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "パイナップル",
         "example_translation": "台湾のパイナップルは香りがよくて甘い。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我買了一盒鳳梨酥當伴手禮。",
            "ja": "お土産にパイナップルケーキを一箱買った。",
            "scene": "お土産選び"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "切",
              "pos": "V"
             },
             {
              "text": "鳳梨",
              "pos": "N"
             }
            ],
            "ja": "パイナップルを切る"
           },
           {
            "parts": [
             {
              "text": "鳳梨",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "酸",
              "pos": "Vs",
              "ja": "酸っぱい"
             }
            ],
            "ja": "パイナップルがとても酸っぱい"
           }
          ],
          "measure_words": [
           {
            "word": "顆",
            "zhuyin": "ㄎㄜ",
            "note": "丸ごと一つを数える"
           }
          ],
          "related_words": [
           {
            "word": "鳳梨酥",
            "kind": "rel",
            "reading": "ㄈㄥˋ ㄌㄧˊ ㄙㄨ",
            "note": "台湾名物のパイナップルケーキ"
           },
           {
            "word": "菠蘿",
            "kind": "syn",
            "reading": "ㄅㄛ ㄌㄨㄛˊ",
            "note": "中国大陸でよく使う言い方"
           }
          ],
          "pronunciation_tips": "「鳳」は第4声で下げ、「梨」は第2声で上げます。",
          "mnemonic": "てっぺんの葉を鳳凰（鳳）の羽に見立てよう。",
          "taiwan_note": "台湾語の「旺來」（繁盛がやって来る）と音が近く、縁起のよい果物とされます。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "pineapple",
         "example_translation": "Taiwanese pineapples are fragrant and sweet.",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "我買了一盒鳳梨酥當伴手禮。",
            "ja": "I bought a box of pineapple cakes as a gift.",
            "scene": "Choosing souvenirs"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "切",
              "pos": "V"
             },
             {
              "text": "鳳梨",
              "pos": "N"
             }
            ],
            "ja": "cut a pineapple"
           },
           {
            "parts": [
             {
              "text": "鳳梨",
              "pos": "N"
             },
             {
              "text": "很",
              "pos": "Adv"
             },
             {
              "text": "酸",
              "pos": "Vs",
              "ja": "sour"
             }
            ],
            "ja": "the pineapple is very sour"
           }
          ],
          "measure_words": [
           {
            "word": "顆",
            "zhuyin": "ㄎㄜ",
            "note": "for a whole one"
           }
          ],
          "related_words": [
           {
            "word": "鳳梨酥",
            "kind": "rel",
            "reading": "ㄈㄥˋ ㄌㄧˊ ㄙㄨ",
            "note": "Taiwan's famous pineapple cake"
           },
           {
            "word": "菠蘿",
            "kind": "syn",
            "reading": "ㄅㄛ ㄌㄨㄛˊ",
            "note": "the word common in mainland China"
           }
          ],
          "pronunciation_tips": "“鳳” falls (fourth tone), then “梨” rises (second tone).",
          "mnemonic": "Imagine the leafy top as the feathers of a phoenix (鳳).",
          "taiwan_note": "Its Taiwanese name sounds like “旺來” (prosperity is coming), so it's a lucky fruit.",
          "explain_lang": "en"
         }
        }
       }
      },
      {
       "key": "scooter",
       "headword": "機車",
       "reading_zhuyin": "ㄐㄧ ㄔㄜ",
       "pinyin": "jīchē",
       "part_of_speech": "N",
       "category_key": "vehicle",
       "level": "TOCFL-3",
       "emoji": "🛵",
       "example_sentence": "我每天騎機車上班。",
       "language": "zh-TW",
       "explain": {
        "ja": {
         "meaning": "バイク、スクーター",
         "example_translation": "毎日バイクで通勤している。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "機車可以停在這裡嗎？",
            "ja": "バイクはここに停めてもいいですか？",
            "scene": "駐車場で"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "騎",
              "pos": "V"
             },
             {
              "text": "機車",
              "pos": "N"
             }
            ],
            "ja": "バイクに乗る"
           },
           {
            "parts": [
             {
              "text": "停",
              "pos": "V"
             },
             {
              "text": "機車",
              "pos": "N"
             }
            ],
            "ja": "バイクを停める"
           }
          ],
          "measure_words": [
           {
            "word": "台",
            "zhuyin": "ㄊㄞˊ",
            "note": "乗り物や機械を数える"
           }
          ],
          "related_words": [
           {
            "word": "腳踏車",
            "kind": "rel",
            "reading": "ㄐㄧㄠˇ ㄊㄚˋ ㄔㄜ",
            "note": "自転車"
           },
           {
            "word": "摩托車",
            "kind": "syn",
            "reading": "ㄇㄛˊ ㄊㄨㄛ ㄔㄜ",
            "note": "やや改まった言い方"
           }
          ],
          "pronunciation_tips": "どちらも第1声。高く平らなまま二音を続けます。",
          "mnemonic": "「機械の車」＝エンジン付きの二輪車。",
          "taiwan_note": "台湾は機車大国。朝の交差点にはバイク専用の待機エリアがあります。",
          "explain_lang": "ja"
         }
        },
        "en": {
         "meaning": "scooter, motorbike",
         "example_translation": "I ride my scooter to work every day.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "機車可以停在這裡嗎？",
            "ja": "Can I park my scooter here?",
            "scene": "At a parking area"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "騎",
              "pos": "V"
             },
             {
              "text": "機車",
              "pos": "N"
             }
            ],
            "ja": "ride a scooter"
           },
           {
            "parts": [
             {
              "text": "停",
              "pos": "V"
             },
             {
              "text": "機車",
              "pos": "N"
             }
            ],
            "ja": "park a scooter"
           }
          ],
          "measure_words": [
           {
            "word": "台",
            "zhuyin": "ㄊㄞˊ",
            "note": "for vehicles and machines"
           }
          ],
          "related_words": [
           {
            "word": "腳踏車",
            "kind": "rel",
            "reading": "ㄐㄧㄠˇ ㄊㄚˋ ㄔㄜ",
            "note": "bicycle"
           },
           {
            "word": "摩托車",
            "kind": "syn",
            "reading": "ㄇㄛˊ ㄊㄨㄛ ㄔㄜ",
            "note": "a more formal word"
           }
          ],
          "pronunciation_tips": "Both syllables are first tone: keep them high and level.",
          "mnemonic": "Machine (機) + vehicle (車) = a motorbike.",
          "taiwan_note": "Taiwan is scooter country: big crossings even have waiting boxes just for scooters.",
          "explain_lang": "en"
         }
        }
       }
      }
     ],
     "variants": [
      {
       "headword": "速克達",
       "reading_zhuyin": "ㄙㄨˋ ㄎㄜˋ ㄉㄚˊ",
       "pinyin": "sùkèdá",
       "of": "scooter",
       "register": "specific",
       "category_key": "vehicle",
       "meaning": {
        "ja": "スクーター（足元が平らなタイプ）",
        "en": "a step-through scooter"
       },
       "distinction": {
        "ja": "足を置く床が平らなタイプの名前",
        "en": "the name for the step-through type"
       }
      }
     ],
     "distinctions": {
      "scooter": {
       "ja": "台湾でふだん使う言い方",
       "en": "the everyday word in Taiwan"
      },
      "pineapple": {
       "ja": "ふだんの言い方",
       "en": "the everyday word"
      },
      "mango": {
       "ja": "ふだんの言い方",
       "en": "the everyday word"
      }
     },
     "wordbook": {
      "title": {
       "ja": "果物の単語",
       "en": "Fruit words"
      },
      "entries": [
       {
        "headword": "蘋果",
        "reading_zhuyin": "ㄆㄧㄥˊ ㄍㄨㄛˇ",
        "pinyin": "píngguǒ",
        "meaning": {
         "ja": "りんご",
         "en": "apple"
        }
       },
       {
        "headword": "香蕉",
        "reading_zhuyin": "ㄒㄧㄤ ㄐㄧㄠ",
        "pinyin": "xiāngjiāo",
        "meaning": {
         "ja": "バナナ",
         "en": "banana"
        }
       },
       {
        "headword": "西瓜",
        "reading_zhuyin": "ㄒㄧ ㄍㄨㄚ",
        "pinyin": "xīguā",
        "meaning": {
         "ja": "すいか",
         "en": "watermelon"
        }
       },
       {
        "headword": "葡萄",
        "reading_zhuyin": "ㄆㄨˊ ㄊㄠˊ",
        "pinyin": "pútáo",
        "meaning": {
         "ja": "ぶどう",
         "en": "grape"
        }
       },
       {
        "headword": "草莓",
        "reading_zhuyin": "ㄘㄠˇ ㄇㄟˊ",
        "pinyin": "cǎoméi",
        "meaning": {
         "ja": "いちご",
         "en": "strawberry"
        }
       },
       {
        "headword": "荔枝",
        "reading_zhuyin": "ㄌㄧˋ ㄓ",
        "pinyin": "lìzhī",
        "meaning": {
         "ja": "ライチ",
         "en": "lychee"
        }
       }
      ]
     },
     "journal": {
      "draft": "今天我去夜市和吃了芒果冰，很好吃。",
      "correction": "今天我去夜市吃了芒果冰，很好吃。",
      "body": {
       "ja": "今日は夜市に行ってマンゴーかき氷を食べた。とてもおいしかった。",
       "en": "Today I went to the night market and had mango shaved ice. It was delicious."
      },
      "feedback": {
       "ja": "「和」は名詞どうしをつなぐ言葉で、動作をつなぐときには使いません。「去夜市吃了芒果冰」のように動詞を続けて書けます。",
       "en": "“和” joins nouns, not actions. Just put the verbs one after another: “去夜市吃了芒果冰”."
      },
      "phrases": [
       {
        "zh": "這碗芒果冰超好吃的！",
        "ja": {
         "ja": "このマンゴーかき氷、めっちゃおいしい！",
         "en": "This mango shaved ice is so good!"
        },
        "note": {
         "ja": "感動を伝えるくだけた言い方",
         "en": "a casual way to share excitement"
        }
       },
       {
        "zh": "我們去夜市逛逛吧。",
        "ja": {
         "ja": "夜市をぶらぶらしに行こう。",
         "en": "Let's go and wander around the night market."
        },
        "note": {
         "ja": "「逛逛」は目的を決めずにぶらぶら歩くこと",
         "en": "“逛逛” means strolling around with no fixed plan"
        }
       }
      ]
     },
     "prompts": [
      {
       "zh": "你今天在哪裡看到芒果？",
       "ja": {
        "ja": "今日どこでマンゴーを見かけましたか？",
        "en": "Where did you see a mango today?"
       },
       "word": "mango"
      },
      {
       "zh": "你喜歡喝珍珠奶茶嗎？為什麼？",
       "ja": {
        "ja": "タピオカミルクティーは好きですか？なぜですか？",
        "en": "Do you like bubble tea? Why?"
       },
       "word": "bubbletea"
      }
     ],
     "patterns": [
      {
       "zh": "我今天在＿＿看到了＿＿。",
       "ja": {
        "ja": "今日、＿＿で＿＿を見かけた。",
        "en": "Today I saw ＿＿ at ＿＿."
       }
      },
      {
       "zh": "＿＿又＿＿又＿＿。",
       "ja": {
        "ja": "＿＿で、しかも＿＿だ。",
        "en": "It's both ＿＿ and ＿＿."
       }
      }
     ],
     "synth": {
      "level": "TOCFL-2",
      "pos": "N",
      "example": "我今天看到了{h}。",
      "ex_tr": {
       "ja": "今日「{h}」を見かけた。",
       "en": "Today I saw “{h}”."
      },
      "chunk_parts": [
       [
        "看",
        "V"
       ],
       [
        "{h}",
        "N"
       ]
      ],
      "chunk_tr": {
       "ja": "「{h}」を見る",
       "en": "see “{h}”"
      }
     },
     "places": [
      {
       "lat": 25.0339,
       "lng": 121.5645,
       "name": {
        "ja": "台北 信義区",
        "en": "Xinyi, Taipei",
        "zh-TW": "台北市信義區"
       }
      },
      {
       "lat": 25.0478,
       "lng": 121.517,
       "name": {
        "ja": "台北駅",
        "en": "Taipei Main Station",
        "zh-TW": "台北車站"
       }
      },
      {
       "lat": 25.169,
       "lng": 121.4405,
       "name": {
        "ja": "淡水",
        "en": "Tamsui",
        "zh-TW": "淡水"
       }
      }
     ],
     "common": {
      "caption": {
       "ja": "はじめて見つけた！",
       "en": "Spotted this today!",
       "zh-TW": "今天發現的！"
      },
      "feedback_generic": {
       "ja": "自然に書けています。この調子で続けましょう。",
       "en": "This reads naturally. Keep it up!",
       "zh-TW": "寫得很自然，繼續保持！"
      },
      "display_name": {
       "ja": "ミカ",
       "en": "Mika",
       "zh-TW": "米卡"
      }
     }
    }
    """#

    private static let en: String = #"""
    {
     "words": [
      {
       "key": "mango",
       "headword": "mango",
       "reading_zhuyin": "ˈmæŋɡoʊ",
       "pinyin": "ˈmæŋɡəʊ",
       "part_of_speech": "noun",
       "category_key": "fruit",
       "level": "A2",
       "emoji": "🥭",
       "example_sentence": "This mango is perfectly ripe.",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "マンゴー",
         "example_translation": "このマンゴーはちょうど食べごろだ。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Can you cut the mango into cubes?",
            "ja": "マンゴーを角切りにしてくれる？",
            "scene": "台所で"
           },
           {
            "zh": "I'll have a mango smoothie, please.",
            "ja": "マンゴースムージーをください。",
            "scene": "カフェで注文"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "a ripe",
              "pos": "A"
             },
             {
              "text": "mango",
              "pos": "N"
             }
            ],
            "ja": "熟したマンゴー"
           },
           {
            "parts": [
             {
              "text": "peel",
              "pos": "V"
             },
             {
              "text": "a mango",
              "pos": "N"
             }
            ],
            "ja": "マンゴーの皮をむく"
           },
           {
            "parts": [
             {
              "text": "a slice",
              "pos": "N",
              "slot": true,
              "ja": "ひと切れ",
              "alts": [
               {
                "text": "a piece",
                "ja": "ひとかけら"
               },
               {
                "text": "a bowl",
                "ja": "ひと皿"
               }
              ]
             },
             {
              "text": "of",
              "pos": "P"
             },
             {
              "text": "mango",
              "pos": "N"
             }
            ],
            "ja": "マンゴーひと切れ"
           }
          ],
          "forms": {
           "plural": "mangoes"
          },
          "countability": {
           "kind": "both",
           "article": "a mango",
           "note": "果物1個なら a mango。料理の材料や味として言うときは some mango のように数えません。"
          },
          "phrasal_verbs": [
           {
            "phrase": "cut up",
            "meaning": "細かく切る",
            "example": "Cut up the mango for the kids."
           },
           {
            "phrase": "peel off",
            "meaning": "（皮を）むく",
            "example": "Peel off the skin first."
           }
          ],
          "related_words": [
           {
            "word": "papaya",
            "kind": "rel",
            "reading": "",
            "note": "同じく熱帯の果物"
           },
           {
            "word": "tropical",
            "kind": "rel",
            "reading": "",
            "note": "熱帯の（tropical fruit で熱帯の果物）"
           }
          ],
          "stress": {
           "syllables": [
            "man",
            "go"
           ],
           "primary": 0,
           "note": "最初の MAN を強く読みます。"
          },
          "pronunciation_tips": "/ˈmæŋɡoʊ/。最初の a は口を横に開く「ア」と「エ」の中間の音です。",
          "etymology": "ポルトガル語の manga を経て、南インドのタミル語などにさかのぼる言葉です。",
          "mnemonic": "日本語の「マンゴー」とほぼ同じ。ただし強勢は最初の MAN に。",
          "culture_note": "インドでは「果物の王様」と呼ばれ、夏になると多くの品種が出回ります。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "芒果",
         "example_translation": "這顆芒果熟得剛剛好。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Can you cut the mango into cubes?",
            "ja": "可以把芒果切成丁嗎？",
            "scene": "在廚房"
           },
           {
            "zh": "I'll have a mango smoothie, please.",
            "ja": "請給我一杯芒果冰沙。",
            "scene": "在咖啡店點餐"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "a ripe",
              "pos": "A"
             },
             {
              "text": "mango",
              "pos": "N"
             }
            ],
            "ja": "熟透的芒果"
           },
           {
            "parts": [
             {
              "text": "peel",
              "pos": "V"
             },
             {
              "text": "a mango",
              "pos": "N"
             }
            ],
            "ja": "剝芒果皮"
           },
           {
            "parts": [
             {
              "text": "a slice",
              "pos": "N",
              "slot": true,
              "ja": "一片",
              "alts": [
               {
                "text": "a piece",
                "ja": "一塊"
               },
               {
                "text": "a bowl",
                "ja": "一碗"
               }
              ]
             },
             {
              "text": "of",
              "pos": "P"
             },
             {
              "text": "mango",
              "pos": "N"
             }
            ],
            "ja": "一片芒果"
           }
          ],
          "forms": {
           "plural": "mangoes"
          },
          "countability": {
           "kind": "both",
           "article": "a mango",
           "note": "一整顆是 a mango；當作食材或口味時不可數，例如 some mango。"
          },
          "phrasal_verbs": [
           {
            "phrase": "cut up",
            "meaning": "切成小塊",
            "example": "Cut up the mango for the kids."
           },
           {
            "phrase": "peel off",
            "meaning": "剝掉（皮）",
            "example": "Peel off the skin first."
           }
          ],
          "related_words": [
           {
            "word": "papaya",
            "kind": "rel",
            "reading": "",
            "note": "同樣是熱帶水果"
           },
           {
            "word": "tropical",
            "kind": "rel",
            "reading": "",
            "note": "熱帶的（tropical fruit 指熱帶水果）"
           }
          ],
          "stress": {
           "syllables": [
            "man",
            "go"
           ],
           "primary": 0,
           "note": "重音在第一個音節 MAN。"
          },
          "pronunciation_tips": "/ˈmæŋɡoʊ/。第一個 a 的嘴型要往兩邊拉開，介於「ㄚ」和「ㄝ」之間。",
          "etymology": "經由葡萄牙語 manga 傳入，源頭可以追溯到南印度的泰米爾語等語言。",
          "mnemonic": "跟中文的「芒果」發音很像，只要把重音放在 MAN。",
          "culture_note": "在印度，芒果被稱為「水果之王」，夏天會有許多品種上市。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "umbrella",
       "headword": "umbrella",
       "reading_zhuyin": "ʌmˈbrɛlə",
       "pinyin": "ʌmˈbrelə",
       "part_of_speech": "noun",
       "category_key": "accessory",
       "level": "A2",
       "emoji": "☂️",
       "example_sentence": "Don't forget your umbrella. It's going to rain.",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "傘",
         "example_translation": "傘を忘れないで。雨が降りそうだよ。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Can I share your umbrella?",
            "ja": "傘に入れてもらってもいい？",
            "scene": "急な雨のとき"
           },
           {
            "zh": "I left my umbrella on the train.",
            "ja": "電車に傘を忘れてきた。",
            "scene": "忘れ物"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "open",
              "pos": "V"
             },
             {
              "text": "an umbrella",
              "pos": "N"
             }
            ],
            "ja": "傘を開く"
           },
           {
            "parts": [
             {
              "text": "share",
              "pos": "V"
             },
             {
              "text": "an umbrella",
              "pos": "N"
             }
            ],
            "ja": "一本の傘に一緒に入る"
           },
           {
            "parts": [
             {
              "text": "a beach",
              "pos": "N",
              "slot": true,
              "ja": "ビーチ用",
              "alts": [
               {
                "text": "a golf",
                "ja": "ゴルフ用"
               },
               {
                "text": "a patio",
                "ja": "テラス用"
               }
              ]
             },
             {
              "text": "umbrella",
              "pos": "N"
             }
            ],
            "ja": "ビーチ用の傘"
           }
          ],
          "forms": {
           "plural": "umbrellas"
          },
          "countability": {
           "kind": "countable",
           "article": "an umbrella",
           "note": "母音で始まるので a ではなく an umbrella です。"
          },
          "phrasal_verbs": [
           {
            "phrase": "put up",
            "meaning": "（傘を）さす",
            "example": "She put up her umbrella."
           },
           {
            "phrase": "fold up",
            "meaning": "たたむ",
            "example": "Fold up your umbrella before you come in."
           }
          ],
          "related_words": [
           {
            "word": "parasol",
            "kind": "rel",
            "reading": "",
            "note": "日傘"
           },
           {
            "word": "raincoat",
            "kind": "rel",
            "reading": "",
            "note": "レインコート"
           }
          ],
          "stress": {
           "syllables": [
            "um",
            "brel",
            "la"
           ],
           "primary": 1,
           "note": "真ん中の BREL を強く読みます。"
          },
          "pronunciation_tips": "/ʌmˈbrelə/。最初の um は弱く短く、BREL をはっきり。",
          "etymology": "イタリア語 ombrella から。もとはラテン語の umbra（陰）で、日陰を作る道具でした。",
          "etymology_relatives": [
           {
            "word": "umbrage",
            "note": "（古くは）木陰。今は「腹立ち」の意味"
           },
           {
            "word": "penumbra",
            "note": "半影（日食などで薄く暗い部分）"
           }
          ],
          "mnemonic": "umbra（陰）を作るもの＝umbrella。",
          "culture_note": "イギリスでは天気が変わりやすく、晴れていても折りたたみ傘を持ち歩く人が多いです。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "雨傘",
         "example_translation": "別忘了帶傘，快要下雨了。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Can I share your umbrella?",
            "ja": "可以跟你一起撐傘嗎？",
            "scene": "突然下雨的時候"
           },
           {
            "zh": "I left my umbrella on the train.",
            "ja": "我把傘忘在火車上了。",
            "scene": "東西忘了拿"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "open",
              "pos": "V"
             },
             {
              "text": "an umbrella",
              "pos": "N"
             }
            ],
            "ja": "打開傘"
           },
           {
            "parts": [
             {
              "text": "share",
              "pos": "V"
             },
             {
              "text": "an umbrella",
              "pos": "N"
             }
            ],
            "ja": "一起撐一把傘"
           },
           {
            "parts": [
             {
              "text": "a beach",
              "pos": "N",
              "slot": true,
              "ja": "海灘",
              "alts": [
               {
                "text": "a golf",
                "ja": "高爾夫"
               },
               {
                "text": "a patio",
                "ja": "庭院"
               }
              ]
             },
             {
              "text": "umbrella",
              "pos": "N"
             }
            ],
            "ja": "海灘傘"
           }
          ],
          "forms": {
           "plural": "umbrellas"
          },
          "countability": {
           "kind": "countable",
           "article": "an umbrella",
           "note": "因為以母音開頭，要說 an umbrella，不是 a。"
          },
          "phrasal_verbs": [
           {
            "phrase": "put up",
            "meaning": "撐（傘）",
            "example": "She put up her umbrella."
           },
           {
            "phrase": "fold up",
            "meaning": "收起來",
            "example": "Fold up your umbrella before you come in."
           }
          ],
          "related_words": [
           {
            "word": "parasol",
            "kind": "rel",
            "reading": "",
            "note": "陽傘"
           },
           {
            "word": "raincoat",
            "kind": "rel",
            "reading": "",
            "note": "雨衣"
           }
          ],
          "stress": {
           "syllables": [
            "um",
            "brel",
            "la"
           ],
           "primary": 1,
           "note": "重音在中間的 BREL。"
          },
          "pronunciation_tips": "/ʌmˈbrelə/。開頭的 um 要輕而短，BREL 要清楚有力。",
          "etymology": "來自義大利語 ombrella，源自拉丁語 umbra（陰影），原本是用來遮陽的。",
          "etymology_relatives": [
           {
            "word": "umbrage",
            "note": "原指樹蔭，現在多指「不悅」"
           },
           {
            "word": "penumbra",
            "note": "半影（日食時半暗的部分）"
           }
          ],
          "mnemonic": "能製造 umbra（陰影）的東西就是 umbrella。",
          "culture_note": "英國天氣多變，就算是晴天，很多人也會隨身帶折疊傘。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "cat",
       "headword": "cat",
       "reading_zhuyin": "kæt",
       "pinyin": "kæt",
       "part_of_speech": "noun",
       "category_key": "animal",
       "level": "A1",
       "emoji": "🐈",
       "example_sentence": "Our cat sleeps on the sofa all afternoon.",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "猫",
         "example_translation": "うちの猫は午後ずっとソファで寝ている。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Do you have a cat or a dog?",
            "ja": "猫を飼ってる？それとも犬？",
            "scene": "ペットの話題"
           },
           {
            "zh": "A black cat crossed the road.",
            "ja": "黒猫が道を横切った。",
            "scene": "散歩中に"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "feed",
              "pos": "V"
             },
             {
              "text": "the cat",
              "pos": "N"
             }
            ],
            "ja": "猫にえさをやる"
           },
           {
            "parts": [
             {
              "text": "a stray",
              "pos": "A"
             },
             {
              "text": "cat",
              "pos": "N"
             }
            ],
            "ja": "野良猫"
           },
           {
            "parts": [
             {
              "text": "pet",
              "pos": "V"
             },
             {
              "text": "the cat",
              "pos": "N"
             }
            ],
            "ja": "猫をなでる"
           }
          ],
          "forms": {
           "plural": "cats"
          },
          "countability": {
           "kind": "countable",
           "article": "a cat",
           "note": "1匹なら a cat、飼い猫一般を言うなら cats と複数形にします。"
          },
          "phrasal_verbs": [
           {
            "phrase": "curl up",
            "meaning": "丸くなる",
            "example": "The cat curled up by the fire."
           },
           {
            "phrase": "chase after",
            "meaning": "追いかける",
            "example": "The cat chased after a bird."
           }
          ],
          "related_words": [
           {
            "word": "kitten",
            "kind": "rel",
            "reading": "",
            "note": "子猫"
           },
           {
            "word": "dog",
            "kind": "rel",
            "reading": "",
            "note": "犬（よく対にされる）"
           }
          ],
          "stress": {
           "syllables": [
            "cat"
           ],
           "primary": 0,
           "note": "1音節。a は口を横に開いて短く。"
          },
          "pronunciation_tips": "/kæt/。最後の t は軽く止めるだけで、はっきり破裂させなくても通じます。",
          "etymology": "古英語 catt から。後期ラテン語 cattus にさかのぼります。",
          "etymology_relatives": [
           {
            "word": "kitten",
            "note": "子猫（古フランス語経由）"
           }
          ],
          "mnemonic": "鳴き声ではなく、短く「キャッ」と言う感じで cat。",
          "culture_note": "英語には It's raining cats and dogs（土砂降りだ）という古い言い回しがあります。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "貓",
         "example_translation": "我們家的貓整個下午都在沙發上睡覺。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Do you have a cat or a dog?",
            "ja": "你養貓還是養狗？",
            "scene": "聊寵物"
           },
           {
            "zh": "A black cat crossed the road.",
            "ja": "一隻黑貓穿過馬路。",
            "scene": "散步的時候"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "feed",
              "pos": "V"
             },
             {
              "text": "the cat",
              "pos": "N"
             }
            ],
            "ja": "餵貓"
           },
           {
            "parts": [
             {
              "text": "a stray",
              "pos": "A"
             },
             {
              "text": "cat",
              "pos": "N"
             }
            ],
            "ja": "流浪貓"
           },
           {
            "parts": [
             {
              "text": "pet",
              "pos": "V"
             },
             {
              "text": "the cat",
              "pos": "N"
             }
            ],
            "ja": "摸摸貓"
           }
          ],
          "forms": {
           "plural": "cats"
          },
          "countability": {
           "kind": "countable",
           "article": "a cat",
           "note": "一隻是 a cat；泛指貓這種動物時用複數 cats。"
          },
          "phrasal_verbs": [
           {
            "phrase": "curl up",
            "meaning": "蜷成一團",
            "example": "The cat curled up by the fire."
           },
           {
            "phrase": "chase after",
            "meaning": "追著跑",
            "example": "The cat chased after a bird."
           }
          ],
          "related_words": [
           {
            "word": "kitten",
            "kind": "rel",
            "reading": "",
            "note": "小貓"
           },
           {
            "word": "dog",
            "kind": "rel",
            "reading": "",
            "note": "狗（常跟貓成對出現）"
           }
          ],
          "stress": {
           "syllables": [
            "cat"
           ],
           "primary": 0,
           "note": "單音節，a 嘴型往兩邊拉開、短促。"
          },
          "pronunciation_tips": "/kæt/。結尾的 t 輕輕停住就好，不一定要清楚爆破出來。",
          "etymology": "來自古英語 catt，可追溯到後期拉丁語 cattus。",
          "etymology_relatives": [
           {
            "word": "kitten",
            "note": "小貓（經由古法語）"
           }
          ],
          "mnemonic": "想像短促的一聲「ㄎㄚ」，就是 cat。",
          "culture_note": "英文有個老說法 It's raining cats and dogs，意思是「下傾盆大雨」。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "bicycle",
       "headword": "bicycle",
       "reading_zhuyin": "ˈbaɪsɪkəl",
       "pinyin": "ˈbaɪsɪkl̩",
       "part_of_speech": "noun",
       "category_key": "vehicle",
       "level": "A2",
       "emoji": "🚲",
       "example_sentence": "I ride my bicycle to school every day.",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "自転車",
         "example_translation": "毎日自転車で学校に行く。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Where can I park my bicycle?",
            "ja": "自転車はどこに停められますか？",
            "scene": "駅前で"
           },
           {
            "zh": "She goes to work by bicycle.",
            "ja": "彼女は自転車で通勤している。",
            "scene": "通勤の話"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "ride",
              "pos": "V"
             },
             {
              "text": "a bicycle",
              "pos": "N"
             }
            ],
            "ja": "自転車に乗る"
           },
           {
            "parts": [
             {
              "text": "by",
              "pos": "P"
             },
             {
              "text": "bicycle",
              "pos": "N"
             }
            ],
            "ja": "自転車で"
           },
           {
            "parts": [
             {
              "text": "lock",
              "pos": "V"
             },
             {
              "text": "your bicycle",
              "pos": "N"
             }
            ],
            "ja": "自転車に鍵をかける"
           }
          ],
          "forms": {
           "plural": "bicycles"
          },
          "countability": {
           "kind": "countable",
           "article": "a bicycle",
           "note": "移動手段を言う by bicycle には冠詞を付けません。"
          },
          "phrasal_verbs": [
           {
            "phrase": "get on",
            "meaning": "（自転車に）乗る",
            "example": "Get on your bicycle and go."
           },
           {
            "phrase": "get off",
            "meaning": "降りる",
            "example": "Get off your bicycle at the crossing."
           }
          ],
          "related_words": [
           {
            "word": "bike",
            "kind": "syn",
            "reading": "",
            "note": "会話でよく使う短い言い方"
           },
           {
            "word": "tricycle",
            "kind": "rel",
            "reading": "",
            "note": "三輪車"
           }
          ],
          "stress": {
           "syllables": [
            "bi",
            "cy",
            "cle"
           ],
           "primary": 0,
           "note": "最初の BI を強く読みます。"
          },
          "pronunciation_tips": "/ˈbaɪsɪkəl/。cy は「サイ」ではなく弱い「スィ」です。",
          "etymology": "bi-（二つの）＋ギリシャ語 kyklos（輪）から。車輪が二つの乗り物です。",
          "etymology_relatives": [
           {
            "word": "tricycle",
            "note": "tri-（三つ）＋輪＝三輪車"
           },
           {
            "word": "cyclone",
            "note": "ぐるぐる回る風＝サイクロン"
           }
          ],
          "mnemonic": "bi（2）＋cycle（輪）＝二輪車。",
          "culture_note": "オランダでは人口より自転車の数が多いと言われ、自転車専用の道路が整っています。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "腳踏車、自行車",
         "example_translation": "我每天騎腳踏車上學。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Where can I park my bicycle?",
            "ja": "腳踏車可以停在哪裡？",
            "scene": "在車站前"
           },
           {
            "zh": "She goes to work by bicycle.",
            "ja": "她騎腳踏車上班。",
            "scene": "聊通勤"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "ride",
              "pos": "V"
             },
             {
              "text": "a bicycle",
              "pos": "N"
             }
            ],
            "ja": "騎腳踏車"
           },
           {
            "parts": [
             {
              "text": "by",
              "pos": "P"
             },
             {
              "text": "bicycle",
              "pos": "N"
             }
            ],
            "ja": "騎腳踏車（交通方式）"
           },
           {
            "parts": [
             {
              "text": "lock",
              "pos": "V"
             },
             {
              "text": "your bicycle",
              "pos": "N"
             }
            ],
            "ja": "把腳踏車鎖好"
           }
          ],
          "forms": {
           "plural": "bicycles"
          },
          "countability": {
           "kind": "countable",
           "article": "a bicycle",
           "note": "表示交通方式的 by bicycle 不加冠詞。"
          },
          "phrasal_verbs": [
           {
            "phrase": "get on",
            "meaning": "騎上（腳踏車）",
            "example": "Get on your bicycle and go."
           },
           {
            "phrase": "get off",
            "meaning": "下車",
            "example": "Get off your bicycle at the crossing."
           }
          ],
          "related_words": [
           {
            "word": "bike",
            "kind": "syn",
            "reading": "",
            "note": "口語常用的簡短說法"
           },
           {
            "word": "tricycle",
            "kind": "rel",
            "reading": "",
            "note": "三輪車"
           }
          ],
          "stress": {
           "syllables": [
            "bi",
            "cy",
            "cle"
           ],
           "primary": 0,
           "note": "重音在第一個音節 BI。"
          },
          "pronunciation_tips": "/ˈbaɪsɪkəl/。cy 不唸「賽」，而是輕輕的 /sɪ/。",
          "etymology": "由 bi-（二）加上希臘語 kyklos（圓、輪子）組成，就是有兩個輪子的車。",
          "etymology_relatives": [
           {
            "word": "tricycle",
            "note": "tri-（三）＋輪子＝三輪車"
           },
           {
            "word": "cyclone",
            "note": "旋轉的風＝氣旋"
           }
          ],
          "mnemonic": "bi（二）＋cycle（輪子）＝兩輪車。",
          "culture_note": "據說荷蘭的腳踏車比人口還多，到處都有完善的自行車道。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "coffee",
       "headword": "coffee",
       "reading_zhuyin": "ˈkɔːfi",
       "pinyin": "ˈkɒfi",
       "part_of_speech": "noun",
       "category_key": "drink",
       "level": "A1",
       "emoji": "☕",
       "example_sentence": "Would you like a cup of coffee?",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "コーヒー",
         "example_translation": "コーヒーを一杯いかがですか？",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Two coffees to go, please.",
            "ja": "コーヒーを二つ、持ち帰りでお願いします。",
            "scene": "カフェで注文"
           },
           {
            "zh": "I can't wake up without coffee.",
            "ja": "コーヒーがないと目が覚めない。",
            "scene": "朝の会話"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "make",
              "pos": "V"
             },
             {
              "text": "coffee",
              "pos": "N"
             }
            ],
            "ja": "コーヒーをいれる"
           },
           {
            "parts": [
             {
              "text": "a cup",
              "pos": "N",
              "slot": true,
              "ja": "一杯",
              "alts": [
               {
                "text": "a mug",
                "ja": "マグカップ一杯"
               },
               {
                "text": "a pot",
                "ja": "ポット一杯"
               }
              ]
             },
             {
              "text": "of",
              "pos": "P"
             },
             {
              "text": "coffee",
              "pos": "N"
             }
            ],
            "ja": "コーヒー一杯"
           },
           {
            "parts": [
             {
              "text": "strong",
              "pos": "A"
             },
             {
              "text": "coffee",
              "pos": "N"
             }
            ],
            "ja": "濃いコーヒー"
           }
          ],
          "forms": {
           "plural": "coffees"
          },
          "countability": {
           "kind": "both",
           "article": "a coffee",
           "note": "飲み物としては数えませんが、注文では two coffees（2杯）のように数えます。"
          },
          "phrasal_verbs": [
           {
            "phrase": "cool down",
            "meaning": "冷める",
            "example": "Let your coffee cool down a little."
           },
           {
            "phrase": "pour out",
            "meaning": "注ぐ",
            "example": "She poured out two cups."
           }
          ],
          "related_words": [
           {
            "word": "café",
            "kind": "rel",
            "reading": "",
            "note": "カフェ（同じ語源）"
           },
           {
            "word": "tea",
            "kind": "rel",
            "reading": "",
            "note": "紅茶、お茶"
           }
          ],
          "stress": {
           "syllables": [
            "cof",
            "fee"
           ],
           "primary": 0,
           "note": "最初の COF を強く読みます。"
          },
          "pronunciation_tips": "/ˈkɔːfi/。「コーヒー」と伸ばさず、最初を強く短めに。",
          "etymology": "イタリア語 caffè、トルコ語 kahve を経て、アラビア語 qahwa にさかのぼります。",
          "etymology_relatives": [
           {
            "word": "caffeine",
            "note": "カフェイン"
           },
           {
            "word": "café",
            "note": "コーヒーを出す店"
           }
          ],
          "mnemonic": "強いのは最初だけ：COF-fee。",
          "culture_note": "アメリカでは大きなマグで薄めのコーヒーを何杯も飲む習慣があります。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "咖啡",
         "example_translation": "要不要來杯咖啡？",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Two coffees to go, please.",
            "ja": "兩杯咖啡外帶，謝謝。",
            "scene": "在咖啡店點餐"
           },
           {
            "zh": "I can't wake up without coffee.",
            "ja": "沒有咖啡我就醒不過來。",
            "scene": "早上的對話"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "make",
              "pos": "V"
             },
             {
              "text": "coffee",
              "pos": "N"
             }
            ],
            "ja": "泡咖啡"
           },
           {
            "parts": [
             {
              "text": "a cup",
              "pos": "N",
              "slot": true,
              "ja": "一杯",
              "alts": [
               {
                "text": "a mug",
                "ja": "一馬克杯"
               },
               {
                "text": "a pot",
                "ja": "一壺"
               }
              ]
             },
             {
              "text": "of",
              "pos": "P"
             },
             {
              "text": "coffee",
              "pos": "N"
             }
            ],
            "ja": "一杯咖啡"
           },
           {
            "parts": [
             {
              "text": "strong",
              "pos": "A"
             },
             {
              "text": "coffee",
              "pos": "N"
             }
            ],
            "ja": "濃咖啡"
           }
          ],
          "forms": {
           "plural": "coffees"
          },
          "countability": {
           "kind": "both",
           "article": "a coffee",
           "note": "當作飲料時不可數，但點餐時可以說 two coffees（兩杯）。"
          },
          "phrasal_verbs": [
           {
            "phrase": "cool down",
            "meaning": "變涼",
            "example": "Let your coffee cool down a little."
           },
           {
            "phrase": "pour out",
            "meaning": "倒出來",
            "example": "She poured out two cups."
           }
          ],
          "related_words": [
           {
            "word": "café",
            "kind": "rel",
            "reading": "",
            "note": "咖啡店（同一個字源）"
           },
           {
            "word": "tea",
            "kind": "rel",
            "reading": "",
            "note": "茶"
           }
          ],
          "stress": {
           "syllables": [
            "cof",
            "fee"
           ],
           "primary": 0,
           "note": "重音在第一個音節 COF。"
          },
          "pronunciation_tips": "/ˈkɔːfi/。重音放在前面，後面的 fee 輕輕帶過。",
          "etymology": "經由義大利語 caffè、土耳其語 kahve，可追溯到阿拉伯語 qahwa。",
          "etymology_relatives": [
           {
            "word": "caffeine",
            "note": "咖啡因"
           },
           {
            "word": "café",
            "note": "賣咖啡的店"
           }
          ],
          "mnemonic": "只有開頭用力：COF-fee。",
          "culture_note": "在美國，很多人習慣用大馬克杯喝好幾杯淡一點的咖啡。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "receipt",
       "headword": "receipt",
       "reading_zhuyin": "rɪˈsiːt",
       "pinyin": "rɪˈsiːt",
       "part_of_speech": "noun",
       "category_key": "document",
       "level": "B1",
       "emoji": "🧾",
       "example_sentence": "Could I have a receipt, please?",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "レシート、領収書",
         "example_translation": "レシートをいただけますか？",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Keep the receipt in case you need to return it.",
            "ja": "返品するかもしれないので、レシートは取っておいて。",
            "scene": "買い物のあと"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "keep",
              "pos": "V"
             },
             {
              "text": "the receipt",
              "pos": "N"
             }
            ],
            "ja": "レシートを取っておく"
           },
           {
            "parts": [
             {
              "text": "ask for",
              "pos": "V"
             },
             {
              "text": "a receipt",
              "pos": "N"
             }
            ],
            "ja": "レシートをもらう（頼む）"
           }
          ],
          "forms": {
           "plural": "receipts"
          },
          "countability": {
           "kind": "countable",
           "article": "a receipt",
           "note": "1枚なら a receipt。"
          },
          "phrasal_verbs": [
           {
            "phrase": "hold on to",
            "meaning": "取っておく",
            "example": "Hold on to your receipt."
           },
           {
            "phrase": "hand over",
            "meaning": "手渡す",
            "example": "He handed over the receipt."
           }
          ],
          "related_words": [
           {
            "word": "invoice",
            "kind": "rel",
            "reading": "",
            "note": "請求書"
           },
           {
            "word": "receive",
            "kind": "rel",
            "reading": "",
            "note": "受け取る（同じ語源）"
           }
          ],
          "stress": {
           "syllables": [
            "re",
            "ceipt"
           ],
           "primary": 1,
           "note": "後ろの CEIPT を強く読みます。"
          },
          "pronunciation_tips": "/rɪˈsiːt/。p は読みません（黙字）。",
          "etymology": "古フランス語 receite から。p はラテン語 recepta に合わせて後から綴りに足されました。",
          "etymology_relatives": [
           {
            "word": "receive",
            "note": "受け取る"
           },
           {
            "word": "reception",
            "note": "受付、歓迎会"
           }
          ],
          "mnemonic": "p は書くけれど読まない。receive（受け取る）の仲間。",
          "culture_note": "アメリカでは経費精算のためにレシートの写真を撮っておく人が多いです。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "收據、發票",
         "example_translation": "可以給我收據嗎？",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "Keep the receipt in case you need to return it.",
            "ja": "收據要留著，以防需要退貨。",
            "scene": "買完東西後"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "keep",
              "pos": "V"
             },
             {
              "text": "the receipt",
              "pos": "N"
             }
            ],
            "ja": "把收據留著"
           },
           {
            "parts": [
             {
              "text": "ask for",
              "pos": "V"
             },
             {
              "text": "a receipt",
              "pos": "N"
             }
            ],
            "ja": "索取收據"
           }
          ],
          "forms": {
           "plural": "receipts"
          },
          "countability": {
           "kind": "countable",
           "article": "a receipt",
           "note": "一張是 a receipt。"
          },
          "phrasal_verbs": [
           {
            "phrase": "hold on to",
            "meaning": "留著不丟",
            "example": "Hold on to your receipt."
           },
           {
            "phrase": "hand over",
            "meaning": "交出去",
            "example": "He handed over the receipt."
           }
          ],
          "related_words": [
           {
            "word": "invoice",
            "kind": "rel",
            "reading": "",
            "note": "請款單"
           },
           {
            "word": "receive",
            "kind": "rel",
            "reading": "",
            "note": "收到（同一個字源）"
           }
          ],
          "stress": {
           "syllables": [
            "re",
            "ceipt"
           ],
           "primary": 1,
           "note": "重音在後面的 CEIPT。"
          },
          "pronunciation_tips": "/rɪˈsiːt/。p 不發音。",
          "etymology": "來自古法語 receite；p 是後來為了配合拉丁語 recepta 才加進拼字的。",
          "etymology_relatives": [
           {
            "word": "receive",
            "note": "收到"
           },
           {
            "word": "reception",
            "note": "接待處、歡迎會"
           }
          ],
          "mnemonic": "p 只寫不唸；跟 receive（收到）是一家人。",
          "culture_note": "在美國，很多人會把收據拍照存起來，方便報帳。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "sunflower",
       "headword": "sunflower",
       "reading_zhuyin": "ˈsʌnˌflaʊər",
       "pinyin": "ˈsʌnˌflaʊə",
       "part_of_speech": "noun",
       "category_key": "flower",
       "level": "B1",
       "emoji": "🌻",
       "example_sentence": "The sunflowers in the field are taller than me.",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "ひまわり",
         "example_translation": "畑のひまわりは私より背が高い。",
         "extras": {
          "frequency_level": 3,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "We planted sunflower seeds in May.",
            "ja": "5月にひまわりの種をまいた。",
            "scene": "庭仕事"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "a field of",
              "pos": "N"
             },
             {
              "text": "sunflowers",
              "pos": "N"
             }
            ],
            "ja": "一面のひまわり畑"
           },
           {
            "parts": [
             {
              "text": "sunflower",
              "pos": "N"
             },
             {
              "text": "seeds",
              "pos": "N"
             }
            ],
            "ja": "ひまわりの種"
           }
          ],
          "forms": {
           "plural": "sunflowers"
          },
          "countability": {
           "kind": "countable",
           "article": "a sunflower",
           "note": "1本なら a sunflower。"
          },
          "phrasal_verbs": [
           {
            "phrase": "shoot up",
            "meaning": "ぐんぐん伸びる",
            "example": "Sunflowers shoot up in summer."
           },
           {
            "phrase": "come up",
            "meaning": "芽を出す",
            "example": "The sunflowers have come up."
           }
          ],
          "related_words": [
           {
            "word": "daisy",
            "kind": "rel",
            "reading": "",
            "note": "同じキク科の花"
           }
          ],
          "stress": {
           "syllables": [
            "sun",
            "flow",
            "er"
           ],
           "primary": 0,
           "note": "最初の SUN を強く読みます。"
          },
          "pronunciation_tips": "/ˈsʌnflaʊər/。flower は「フラワー」より「フラウア」に近い音です。",
          "etymology": "sun（太陽）＋flower（花）。花が太陽のほうを向くことから。",
          "etymology_relatives": [
           {
            "word": "sunrise",
            "note": "日の出"
           }
          ],
          "mnemonic": "太陽（sun）を追いかける花（flower）。",
          "culture_note": "ウクライナの国花で、平和の象徴として描かれることもあります。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "向日葵",
         "example_translation": "田裡的向日葵比我還高。",
         "extras": {
          "frequency_level": 3,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "We planted sunflower seeds in May.",
            "ja": "我們五月種了向日葵的種子。",
            "scene": "整理花園"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "a field of",
              "pos": "N"
             },
             {
              "text": "sunflowers",
              "pos": "N"
             }
            ],
            "ja": "一整片向日葵花田"
           },
           {
            "parts": [
             {
              "text": "sunflower",
              "pos": "N"
             },
             {
              "text": "seeds",
              "pos": "N"
             }
            ],
            "ja": "葵花子"
           }
          ],
          "forms": {
           "plural": "sunflowers"
          },
          "countability": {
           "kind": "countable",
           "article": "a sunflower",
           "note": "一朵是 a sunflower。"
          },
          "phrasal_verbs": [
           {
            "phrase": "shoot up",
            "meaning": "長得很快",
            "example": "Sunflowers shoot up in summer."
           },
           {
            "phrase": "come up",
            "meaning": "發芽冒出來",
            "example": "The sunflowers have come up."
           }
          ],
          "related_words": [
           {
            "word": "daisy",
            "kind": "rel",
            "reading": "",
            "note": "同為菊科的花"
           }
          ],
          "stress": {
           "syllables": [
            "sun",
            "flow",
            "er"
           ],
           "primary": 0,
           "note": "重音在第一個音節 SUN。"
          },
          "pronunciation_tips": "/ˈsʌnflaʊər/。flower 的音比較接近 /flaʊər/。",
          "etymology": "sun（太陽）＋flower（花），因為花會朝向太陽。",
          "etymology_relatives": [
           {
            "word": "sunrise",
            "note": "日出"
           }
          ],
          "mnemonic": "追著太陽（sun）跑的花（flower）。",
          "culture_note": "向日葵是烏克蘭的國花，有時也被當作和平的象徵。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "pineapple",
       "headword": "pineapple",
       "reading_zhuyin": "ˈpaɪnˌæpəl",
       "pinyin": "ˈpaɪnˌæpl̩",
       "part_of_speech": "noun",
       "category_key": "fruit",
       "level": "A2",
       "emoji": "🍍",
       "example_sentence": "Pineapple on pizza is a hot topic.",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "パイナップル",
         "example_translation": "ピザにパイナップルをのせるかどうかは、よく議論になる。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "This pineapple is really sweet.",
            "ja": "このパイナップル、すごく甘い。",
            "scene": "試食で"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "fresh",
              "pos": "A"
             },
             {
              "text": "pineapple",
              "pos": "N"
             }
            ],
            "ja": "新鮮なパイナップル"
           },
           {
            "parts": [
             {
              "text": "cut",
              "pos": "V"
             },
             {
              "text": "a pineapple",
              "pos": "N"
             }
            ],
            "ja": "パイナップルを切る"
           }
          ],
          "forms": {
           "plural": "pineapples"
          },
          "countability": {
           "kind": "both",
           "article": "a pineapple",
           "note": "丸ごと1個は a pineapple、切った果肉は数えません。"
          },
          "related_words": [
           {
            "word": "pine cone",
            "kind": "rel",
            "reading": "",
            "note": "松ぼっくり（名前の由来）"
           }
          ],
          "stress": {
           "syllables": [
            "pine",
            "ap",
            "ple"
           ],
           "primary": 0,
           "note": "最初の PINE を強く読みます。"
          },
          "pronunciation_tips": "/ˈpaɪnæpəl/。最後の ple は軽く添えるだけ。",
          "etymology": "もとは「松ぼっくり」を指す言葉でした。形が似ているので果物の名前になりました。",
          "mnemonic": "pine（松）＋apple（果物）＝松ぼっくりみたいな果物。",
          "culture_note": "ハワイの名産として知られ、おもてなしの象徴とされることもあります。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "鳳梨",
         "example_translation": "披薩上放鳳梨一直是熱門話題。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "This pineapple is really sweet.",
            "ja": "這顆鳳梨好甜。",
            "scene": "試吃的時候"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "fresh",
              "pos": "A"
             },
             {
              "text": "pineapple",
              "pos": "N"
             }
            ],
            "ja": "新鮮鳳梨"
           },
           {
            "parts": [
             {
              "text": "cut",
              "pos": "V"
             },
             {
              "text": "a pineapple",
              "pos": "N"
             }
            ],
            "ja": "切鳳梨"
           }
          ],
          "forms": {
           "plural": "pineapples"
          },
          "countability": {
           "kind": "both",
           "article": "a pineapple",
           "note": "整顆是 a pineapple，切好的果肉不可數。"
          },
          "related_words": [
           {
            "word": "pine cone",
            "kind": "rel",
            "reading": "",
            "note": "松果（名稱的由來）"
           }
          ],
          "stress": {
           "syllables": [
            "pine",
            "ap",
            "ple"
           ],
           "primary": 0,
           "note": "重音在第一個音節 PINE。"
          },
          "pronunciation_tips": "/ˈpaɪnæpəl/。最後的 ple 輕輕帶過就好。",
          "etymology": "原本是「松果」的意思，因為外型相似才成了水果的名字。",
          "mnemonic": "pine（松樹）＋apple（水果）＝長得像松果的水果。",
          "culture_note": "鳳梨是夏威夷的名產，有時也象徵熱情款待。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "scooter",
       "headword": "scooter",
       "reading_zhuyin": "ˈskuːtər",
       "pinyin": "ˈskuːtə",
       "part_of_speech": "noun",
       "category_key": "vehicle",
       "level": "B1",
       "emoji": "🛵",
       "example_sentence": "He rides a scooter to work.",
       "language": "en",
       "explain": {
        "ja": {
         "meaning": "スクーター",
         "example_translation": "彼はスクーターで通勤している。",
         "extras": {
          "frequency_level": 3,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "You need a helmet to ride a scooter.",
            "ja": "スクーターに乗るにはヘルメットが必要です。",
            "scene": "交通ルール"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "ride",
              "pos": "V"
             },
             {
              "text": "a scooter",
              "pos": "N"
             }
            ],
            "ja": "スクーターに乗る"
           },
           {
            "parts": [
             {
              "text": "park",
              "pos": "V"
             },
             {
              "text": "the scooter",
              "pos": "N"
             }
            ],
            "ja": "スクーターを停める"
           }
          ],
          "forms": {
           "plural": "scooters"
          },
          "countability": {
           "kind": "countable",
           "article": "a scooter",
           "note": "1台なら a scooter。"
          },
          "related_words": [
           {
            "word": "moped",
            "kind": "syn",
            "reading": "",
            "note": "小型のスクーター、原付"
           },
           {
            "word": "motorbike",
            "kind": "rel",
            "reading": "",
            "note": "バイク全般"
           }
          ],
          "stress": {
           "syllables": [
            "scoo",
            "ter"
           ],
           "primary": 0,
           "note": "最初の SCOO を強く読みます。"
          },
          "pronunciation_tips": "/ˈskuːtər/。sc は「ス」と「ク」を続けて一気に。",
          "etymology": "「すばやく動く」という意味の動詞 scoot から。",
          "mnemonic": "scoot（すっと走る）乗り物＝scooter。",
          "culture_note": "イギリス英語では子ども用のキックボードも scooter と呼びます。",
          "explain_lang": "ja"
         }
        },
        "zh-TW": {
         "meaning": "機車、速克達",
         "example_translation": "他騎機車上班。",
         "extras": {
          "frequency_level": 3,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "You need a helmet to ride a scooter.",
            "ja": "騎機車要戴安全帽。",
            "scene": "交通規則"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "ride",
              "pos": "V"
             },
             {
              "text": "a scooter",
              "pos": "N"
             }
            ],
            "ja": "騎機車"
           },
           {
            "parts": [
             {
              "text": "park",
              "pos": "V"
             },
             {
              "text": "the scooter",
              "pos": "N"
             }
            ],
            "ja": "停機車"
           }
          ],
          "forms": {
           "plural": "scooters"
          },
          "countability": {
           "kind": "countable",
           "article": "a scooter",
           "note": "一台是 a scooter。"
          },
          "related_words": [
           {
            "word": "moped",
            "kind": "syn",
            "reading": "",
            "note": "小型機車"
           },
           {
            "word": "motorbike",
            "kind": "rel",
            "reading": "",
            "note": "泛指摩托車"
           }
          ],
          "stress": {
           "syllables": [
            "scoo",
            "ter"
           ],
           "primary": 0,
           "note": "重音在第一個音節 SCOO。"
          },
          "pronunciation_tips": "/ˈskuːtər/。sc 的 s 跟 k 要連在一起唸。",
          "etymology": "來自動詞 scoot（快速移動）。",
          "mnemonic": "能 scoot（咻一下跑走）的車＝scooter。",
          "culture_note": "在英式英語裡，小朋友玩的滑板車也叫 scooter。",
          "explain_lang": "zh-TW"
         }
        }
       }
      }
     ],
     "variants": [
      {
       "headword": "moped",
       "reading_zhuyin": "ˈmoʊpɛd",
       "pinyin": "ˈməʊped",
       "of": "scooter",
       "register": "specific",
       "category_key": "vehicle",
       "meaning": {
        "ja": "原付（小型のバイク）",
        "zh-TW": "輕型機車"
       },
       "distinction": {
        "ja": "排気量の小さいタイプの名前",
        "zh-TW": "排氣量較小的車種"
       }
      }
     ],
     "distinctions": {
      "scooter": {
       "ja": "ふだんの言い方",
       "zh-TW": "最常用的說法"
      },
      "pineapple": {
       "ja": "ふだんの言い方",
       "zh-TW": "最常用的說法"
      },
      "mango": {
       "ja": "ふだんの言い方",
       "zh-TW": "最常用的說法"
      }
     },
     "wordbook": {
      "title": {
       "ja": "果物の単語",
       "zh-TW": "水果單字"
      },
      "entries": [
       {
        "headword": "apple",
        "reading_zhuyin": null,
        "pinyin": null,
        "meaning": {
         "ja": "りんご",
         "zh-TW": "蘋果"
        }
       },
       {
        "headword": "banana",
        "reading_zhuyin": null,
        "pinyin": null,
        "meaning": {
         "ja": "バナナ",
         "zh-TW": "香蕉"
        }
       },
       {
        "headword": "watermelon",
        "reading_zhuyin": null,
        "pinyin": null,
        "meaning": {
         "ja": "すいか",
         "zh-TW": "西瓜"
        }
       },
       {
        "headword": "grape",
        "reading_zhuyin": null,
        "pinyin": null,
        "meaning": {
         "ja": "ぶどう",
         "zh-TW": "葡萄"
        }
       },
       {
        "headword": "strawberry",
        "reading_zhuyin": null,
        "pinyin": null,
        "meaning": {
         "ja": "いちご",
         "zh-TW": "草莓"
        }
       },
       {
        "headword": "lychee",
        "reading_zhuyin": null,
        "pinyin": null,
        "meaning": {
         "ja": "ライチ",
         "zh-TW": "荔枝"
        }
       }
      ]
     },
     "journal": {
      "draft": "Today I go to a cafe and drink a coffee. It was very delicious.",
      "correction": "Today I went to a café and had a coffee. It was delicious.",
      "body": {
       "ja": "今日はカフェに行ってコーヒーを飲んだ。おいしかった。",
       "zh-TW": "今天我去了咖啡店，喝了一杯咖啡，很好喝。"
      },
      "feedback": {
       "ja": "過去のことなので go は went に。delicious は「とてもおいしい」という意味を含むので very は付けません。",
       "zh-TW": "因為是過去的事，go 要改成 went。delicious 本身就有「非常好吃」的意思，不加 very。"
      },
      "phrases": [
       {
        "zh": "This coffee really hits the spot.",
        "ja": {
         "ja": "このコーヒー、まさに飲みたかった味。",
         "zh-TW": "這杯咖啡正是我想要的。"
        },
        "note": {
         "ja": "ちょうど欲しかったものに使う決まり文句",
         "zh-TW": "形容剛好滿足需求的慣用說法"
        }
       },
       {
        "zh": "I grabbed a coffee on the way.",
        "ja": {
         "ja": "途中でコーヒーを買っていった。",
         "zh-TW": "我順路買了杯咖啡。"
        },
        "note": {
         "ja": "grab で「さっと手に入れる」感じが出ます",
         "zh-TW": "用 grab 表示「順手買」的感覺"
        }
       }
      ]
     },
     "prompts": [
      {
       "zh": "Where did you see a mango today?",
       "ja": {
        "ja": "今日どこでマンゴーを見かけましたか？",
        "zh-TW": "你今天在哪裡看到芒果？"
       },
       "word": "mango"
      },
      {
       "zh": "How do you take your coffee?",
       "ja": {
        "ja": "コーヒーはどうやって飲むのが好きですか？",
        "zh-TW": "你喜歡怎麼喝咖啡？"
       },
       "word": "coffee"
      }
     ],
     "patterns": [
      {
       "zh": "Today I saw ___ at ___.",
       "ja": {
        "ja": "今日、＿＿で＿＿を見かけた。",
        "zh-TW": "今天我在＿＿看到了＿＿。"
       }
      },
      {
       "zh": "It was so ___ that I ___.",
       "ja": {
        "ja": "とても＿＿だったので＿＿した。",
        "zh-TW": "因為太＿＿了，所以我＿＿。"
       }
      }
     ],
     "synth": {
      "level": "A2",
      "pos": "noun",
      "example": "I saw a {h} today.",
      "ex_tr": {
       "ja": "今日「{h}」を見かけた。",
       "zh-TW": "今天看到了「{h}」。"
      },
      "chunk_parts": [
       [
        "see",
        "V"
       ],
       [
        "a {h}",
        "N"
       ]
      ],
      "chunk_tr": {
       "ja": "「{h}」を見る",
       "zh-TW": "看到「{h}」"
      }
     },
     "places": [
      {
       "lat": 51.5194,
       "lng": -0.127,
       "name": {
        "ja": "大英博物館",
        "en": "British Museum",
        "zh-TW": "大英博物館"
       }
      },
      {
       "lat": 51.5055,
       "lng": -0.0754,
       "name": {
        "ja": "ロンドン塔",
        "en": "Tower of London",
        "zh-TW": "倫敦塔"
       }
      },
      {
       "lat": 51.5313,
       "lng": -0.1233,
       "name": {
        "ja": "キングス・クロス駅",
        "en": "King's Cross",
        "zh-TW": "國王十字車站"
       }
      }
     ],
     "common": {
      "caption": {
       "ja": "はじめて見つけた！",
       "en": "Spotted this today!",
       "zh-TW": "今天發現的！"
      },
      "feedback_generic": {
       "ja": "自然に書けています。この調子で続けましょう。",
       "en": "This reads naturally. Keep it up!",
       "zh-TW": "寫得很自然，繼續保持！"
      },
      "display_name": {
       "ja": "ミカ",
       "en": "Mika",
       "zh-TW": "米卡"
      }
     }
    }
    """#

    private static let ja: String = #"""
    {
     "words": [
      {
       "key": "umbrella",
       "headword": "傘",
       "reading_zhuyin": "かさ",
       "pinyin": "kasa",
       "part_of_speech": "名詞",
       "category_key": "accessory",
       "level": "JLPT-N5",
       "emoji": "☂️",
       "example_sentence": "雨が降ってきたので、傘をさしました。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "umbrella",
         "example_translation": "It started to rain, so I put up my umbrella.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "傘を貸してもらえますか。",
            "ja": "Could you lend me an umbrella?",
            "scene": "When it starts to rain"
           },
           {
            "zh": "駅に傘を忘れてしまった。",
            "ja": "I left my umbrella at the station.",
            "scene": "Lost property"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "傘",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "さす",
              "pos": "V"
             }
            ],
            "ja": "put up an umbrella"
           },
           {
            "parts": [
             {
              "text": "傘",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "忘れる",
              "pos": "V"
             }
            ],
            "ja": "leave your umbrella behind"
           },
           {
            "parts": [
             {
              "text": "ビニール",
              "pos": "N",
              "slot": true,
              "ja": "plastic",
              "alts": [
               {
                "text": "折りたたみ",
                "ja": "folding"
               }
              ]
             },
             {
              "text": "傘",
              "pos": "N"
             }
            ],
            "ja": "a plastic umbrella"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "傘",
            "meaning": "umbrella",
            "on": "サン",
            "kun": "かさ"
           }
          ],
          "conjugation": [
           {
            "form": "plain",
            "text": "傘だ"
           },
           {
            "form": "polite",
            "text": "傘です"
           },
           {
            "form": "negative",
            "text": "傘じゃない"
           },
           {
            "form": "past",
            "text": "傘だった"
           }
          ],
          "politeness": "傘 itself has no polite form; to ask politely, say 傘をお持ちですか (Do you have an umbrella?).",
          "counters": [
           {
            "word": "一本",
            "reading": "いっぽん",
            "note": "Long, thin things, umbrellas included, are counted with 本."
           }
          ],
          "related_words": [
           {
            "word": "日傘",
            "kind": "rel",
            "reading": "ひがさ",
            "note": "a parasol for the sun"
           },
           {
            "word": "雨具",
            "kind": "rel",
            "reading": "あまぐ",
            "note": "rain gear in general"
           }
          ],
          "pitch_accent": "Head-high (1): か↘さ. The pitch drops right after the first beat.",
          "pronunciation_tips": "Two short, even beats: ka-sa. Don't stretch either vowel.",
          "word_origin": "Native Japanese word (wago).",
          "etymology": "The kanji 傘 is a picture of an open umbrella with people sheltering under it.",
          "mnemonic": "Spot the four little 人 (people) under the roof of 傘.",
          "japan_note": "Clear plastic umbrellas from convenience stores are everywhere in Japan, and many shops have an umbrella stand at the door.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "傘、雨傘",
         "example_translation": "因為開始下雨了，所以我撐了傘。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "傘を貸してもらえますか。",
            "ja": "可以借我一把傘嗎？",
            "scene": "突然下雨的時候"
           },
           {
            "zh": "駅に傘を忘れてしまった。",
            "ja": "我把傘忘在車站了。",
            "scene": "東西忘了拿"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "傘",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "さす",
              "pos": "V"
             }
            ],
            "ja": "撐傘"
           },
           {
            "parts": [
             {
              "text": "傘",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "忘れる",
              "pos": "V"
             }
            ],
            "ja": "忘了拿傘"
           },
           {
            "parts": [
             {
              "text": "ビニール",
              "pos": "N",
              "slot": true,
              "ja": "透明塑膠",
              "alts": [
               {
                "text": "折りたたみ",
                "ja": "折疊"
               }
              ]
             },
             {
              "text": "傘",
              "pos": "N"
             }
            ],
            "ja": "透明塑膠傘"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "傘",
            "meaning": "雨傘",
            "on": "サン",
            "kun": "かさ"
           }
          ],
          "conjugation": [
           {
            "form": "常體",
            "text": "傘だ"
           },
           {
            "form": "敬體",
            "text": "傘です"
           },
           {
            "form": "否定形",
            "text": "傘じゃない"
           },
           {
            "form": "過去形",
            "text": "傘だった"
           }
          ],
          "politeness": "「傘」本身沒有敬語形式；要客氣地問人時，可以說「傘をお持ちですか」。",
          "counters": [
           {
            "word": "一本",
            "reading": "いっぽん",
            "note": "細長的東西用「本」來數，傘也是。"
           }
          ],
          "related_words": [
           {
            "word": "日傘",
            "kind": "rel",
            "reading": "ひがさ",
            "note": "陽傘"
           },
           {
            "word": "雨具",
            "kind": "rel",
            "reading": "あまぐ",
            "note": "雨具的總稱"
           }
          ],
          "pitch_accent": "頭高型（1）：か↘さ，第一拍高，之後下降。",
          "pronunciation_tips": "兩拍，短而平均：ka-sa，母音不要拉長。",
          "word_origin": "和語（日本固有的詞）。",
          "etymology": "「傘」字就像一把撐開的傘，底下有好幾個人在躲雨。",
          "mnemonic": "「傘」字裡藏著四個「人」在躲雨。",
          "japan_note": "在日本，便利商店賣的透明塑膠傘隨處可見，很多店門口也會放傘架。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "cat",
       "headword": "猫",
       "reading_zhuyin": "ねこ",
       "pinyin": "neko",
       "part_of_speech": "名詞",
       "category_key": "animal",
       "level": "JLPT-N5",
       "emoji": "🐈",
       "example_sentence": "うちの猫は一日中寝ています。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "cat",
         "example_translation": "Our cat sleeps all day long.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "駅前に猫がいた。",
            "ja": "There was a cat in front of the station.",
            "scene": "On a walk"
           },
           {
            "zh": "猫を飼っていますか。",
            "ja": "Do you have a cat?",
            "scene": "Talking about pets"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "猫",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "飼う",
              "pos": "V"
             }
            ],
            "ja": "keep a cat"
           },
           {
            "parts": [
             {
              "text": "猫",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "なでる",
              "pos": "V"
             }
            ],
            "ja": "pet a cat"
           },
           {
            "parts": [
             {
              "text": "黒",
              "pos": "N",
              "slot": true,
              "ja": "black",
              "alts": [
               {
                "text": "白",
                "ja": "white"
               },
               {
                "text": "三毛",
                "ja": "calico"
               }
              ]
             },
             {
              "text": "猫",
              "pos": "N"
             }
            ],
            "ja": "a black cat"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "猫",
            "meaning": "cat",
            "on": "ビョウ",
            "kun": "ねこ"
           }
          ],
          "conjugation": [
           {
            "form": "plain",
            "text": "猫だ"
           },
           {
            "form": "polite",
            "text": "猫です"
           },
           {
            "form": "negative",
            "text": "猫じゃない"
           },
           {
            "form": "past",
            "text": "猫だった"
           }
          ],
          "politeness": "No special polite form. Talking about someone else's cat, people often say 猫ちゃん to sound warm.",
          "counters": [
           {
            "word": "一匹",
            "reading": "いっぴき",
            "note": "Small animals such as cats and dogs are counted with 匹."
           }
          ],
          "related_words": [
           {
            "word": "子猫",
            "kind": "rel",
            "reading": "こねこ",
            "note": "kitten"
           },
           {
            "word": "犬",
            "kind": "rel",
            "reading": "いぬ",
            "note": "dog"
           }
          ],
          "pitch_accent": "Head-high (1): ね↘こ. High on the first beat, then low.",
          "pronunciation_tips": "Keep it short: ne-ko, two even beats.",
          "word_origin": "Native Japanese word (wago).",
          "etymology": "One theory says ねこ comes from 寝子, a “sleeping child”, because cats sleep so much.",
          "mnemonic": "Picture a cat curled up on your NECK: ne-ko.",
          "japan_note": "Japan has several “cat islands”, and the beckoning cat 招き猫 is a lucky charm for shops.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "貓",
         "example_translation": "我家的貓整天都在睡覺。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "駅前に猫がいた。",
            "ja": "車站前有一隻貓。",
            "scene": "散步的時候"
           },
           {
            "zh": "猫を飼っていますか。",
            "ja": "你有養貓嗎？",
            "scene": "聊寵物"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "猫",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "飼う",
              "pos": "V"
             }
            ],
            "ja": "養貓"
           },
           {
            "parts": [
             {
              "text": "猫",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "なでる",
              "pos": "V"
             }
            ],
            "ja": "摸貓"
           },
           {
            "parts": [
             {
              "text": "黒",
              "pos": "N",
              "slot": true,
              "ja": "黑",
              "alts": [
               {
                "text": "白",
                "ja": "白"
               },
               {
                "text": "三毛",
                "ja": "三花"
               }
              ]
             },
             {
              "text": "猫",
              "pos": "N"
             }
            ],
            "ja": "黑貓"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "猫",
            "meaning": "貓",
            "on": "ビョウ",
            "kun": "ねこ"
           }
          ],
          "conjugation": [
           {
            "form": "常體",
            "text": "猫だ"
           },
           {
            "form": "敬體",
            "text": "猫です"
           },
           {
            "form": "否定形",
            "text": "猫じゃない"
           },
           {
            "form": "過去形",
            "text": "猫だった"
           }
          ],
          "politeness": "沒有特別的敬語形式。提到別人家的貓時，常說「猫ちゃん」，聽起來比較親切。",
          "counters": [
           {
            "word": "一匹",
            "reading": "いっぴき",
            "note": "貓、狗等小動物用「匹」來數。"
           }
          ],
          "related_words": [
           {
            "word": "子猫",
            "kind": "rel",
            "reading": "こねこ",
            "note": "小貓"
           },
           {
            "word": "犬",
            "kind": "rel",
            "reading": "いぬ",
            "note": "狗"
           }
          ],
          "pitch_accent": "頭高型（1）：ね↘こ，第一拍高，之後下降。",
          "pronunciation_tips": "短短的兩拍：ne-ko。",
          "word_origin": "和語（日本固有的詞）。",
          "etymology": "有一說認為「ねこ」來自「寝子」（愛睡覺的孩子），因為貓很愛睡。",
          "mnemonic": "想像貓咪窩在你的脖子（neck）上：ne-ko。",
          "japan_note": "日本有好幾座「貓島」，「招き猫」（招財貓）則是店家招來好運的吉祥物。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "bicycle",
       "headword": "自転車",
       "reading_zhuyin": "じてんしゃ",
       "pinyin": "jitensha",
       "part_of_speech": "名詞",
       "category_key": "vehicle",
       "level": "JLPT-N5",
       "emoji": "🚲",
       "example_sentence": "毎日自転車で学校に通っています。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "bicycle",
         "example_translation": "I go to school by bicycle every day.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "自転車はどこに止めればいいですか。",
            "ja": "Where should I park my bicycle?",
            "scene": "At the station"
           },
           {
            "zh": "自転車に乗れますか。",
            "ja": "Can you ride a bike?",
            "scene": "Making plans"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "自転車",
              "pos": "N"
             },
             {
              "text": "に",
              "pos": "P"
             },
             {
              "text": "乗る",
              "pos": "V"
             }
            ],
            "ja": "ride a bicycle"
           },
           {
            "parts": [
             {
              "text": "自転車",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "止める",
              "pos": "V"
             }
            ],
            "ja": "park a bicycle"
           },
           {
            "parts": [
             {
              "text": "自転車",
              "pos": "N"
             },
             {
              "text": "で",
              "pos": "P"
             },
             {
              "text": "行く",
              "pos": "V"
             }
            ],
            "ja": "go by bicycle"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "自",
            "meaning": "self",
            "on": "ジ、シ",
            "kun": "みずか(ら)"
           },
           {
            "kanji": "転",
            "meaning": "to turn, to roll",
            "on": "テン",
            "kun": "ころ(がる)"
           },
           {
            "kanji": "車",
            "meaning": "vehicle, wheel",
            "on": "シャ",
            "kun": "くるま"
           }
          ],
          "conjugation": [
           {
            "form": "plain",
            "text": "自転車だ"
           },
           {
            "form": "polite",
            "text": "自転車です"
           },
           {
            "form": "negative",
            "text": "自転車じゃない"
           },
           {
            "form": "past",
            "text": "自転車だった"
           }
          ],
          "politeness": "No special polite form; 自転車 works in any situation.",
          "counters": [
           {
            "word": "一台",
            "reading": "いちだい",
            "note": "Vehicles and machines are counted with 台."
           }
          ],
          "related_words": [
           {
            "word": "チャリ",
            "kind": "syn",
            "reading": "ちゃり",
            "note": "a casual word for a bike"
           },
           {
            "word": "バイク",
            "kind": "rel",
            "reading": "ばいく",
            "note": "motorbike"
           }
          ],
          "pitch_accent": "Both flat (0) and middle-high (2: じて↘んしゃ) are heard.",
          "pronunciation_tips": "しゃ is a single beat and ん is a full beat: ji-te-n-sha.",
          "word_origin": "Sino-Japanese word (kango), read with Chinese-style readings.",
          "etymology": "Literally “a vehicle that turns by itself”: 自 (self) + 転 (turn) + 車 (vehicle).",
          "mnemonic": "自 + 転 + 車: you make the wheels turn yourself.",
          "japan_note": "In Japan every bicycle must be registered, and a bike parked in the wrong place can be towed away.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "腳踏車、自行車",
         "example_translation": "我每天騎腳踏車上學。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "自転車はどこに止めればいいですか。",
            "ja": "腳踏車要停在哪裡比較好？",
            "scene": "在車站"
           },
           {
            "zh": "自転車に乗れますか。",
            "ja": "你會騎腳踏車嗎？",
            "scene": "約出去玩"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "自転車",
              "pos": "N"
             },
             {
              "text": "に",
              "pos": "P"
             },
             {
              "text": "乗る",
              "pos": "V"
             }
            ],
            "ja": "騎腳踏車"
           },
           {
            "parts": [
             {
              "text": "自転車",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "止める",
              "pos": "V"
             }
            ],
            "ja": "停腳踏車"
           },
           {
            "parts": [
             {
              "text": "自転車",
              "pos": "N"
             },
             {
              "text": "で",
              "pos": "P"
             },
             {
              "text": "行く",
              "pos": "V"
             }
            ],
            "ja": "騎腳踏車去"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "自",
            "meaning": "自己",
            "on": "ジ、シ",
            "kun": "みずか(ら)"
           },
           {
            "kanji": "転",
            "meaning": "轉動",
            "on": "テン",
            "kun": "ころ(がる)"
           },
           {
            "kanji": "車",
            "meaning": "車",
            "on": "シャ",
            "kun": "くるま"
           }
          ],
          "conjugation": [
           {
            "form": "常體",
            "text": "自転車だ"
           },
           {
            "form": "敬體",
            "text": "自転車です"
           },
           {
            "form": "否定形",
            "text": "自転車じゃない"
           },
           {
            "form": "過去形",
            "text": "自転車だった"
           }
          ],
          "politeness": "沒有特別的敬語形式，「自転車」在任何場合都能用。",
          "counters": [
           {
            "word": "一台",
            "reading": "いちだい",
            "note": "車輛和機器用「台」來數。"
           }
          ],
          "related_words": [
           {
            "word": "チャリ",
            "kind": "syn",
            "reading": "ちゃり",
            "note": "腳踏車的口語說法"
           },
           {
            "word": "バイク",
            "kind": "rel",
            "reading": "ばいく",
            "note": "機車"
           }
          ],
          "pitch_accent": "平板型（0）和中高型（2：じて↘んしゃ）都有人說。",
          "pronunciation_tips": "「しゃ」算一拍，「ん」也要占一拍：ji-te-n-sha。",
          "word_origin": "漢語（用音讀組成的詞）。",
          "etymology": "字面意思是「自己轉動的車」：自（自己）＋転（轉動）＋車。",
          "mnemonic": "自己（自）踩著讓輪子轉（転）的車（車）。",
          "japan_note": "在日本，腳踏車都要做防盜登記，亂停還可能被拖走。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "bento",
       "headword": "弁当",
       "reading_zhuyin": "べんとう",
       "pinyin": "bentō",
       "part_of_speech": "名詞",
       "category_key": "food",
       "level": "JLPT-N4",
       "emoji": "🍱",
       "example_sentence": "母が毎朝お弁当を作ってくれます。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "bento, a boxed lunch",
         "example_translation": "My mother makes me a bento every morning.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "コンビニで弁当を買いました。",
            "ja": "I bought a bento at a convenience store.",
            "scene": "Lunchtime"
           },
           {
            "zh": "お弁当を温めますか。",
            "ja": "Would you like your bento heated?",
            "scene": "At the convenience store counter"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "弁当",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "作る",
              "pos": "V"
             }
            ],
            "ja": "make a bento"
           },
           {
            "parts": [
             {
              "text": "弁当",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "温める",
              "pos": "V"
             }
            ],
            "ja": "heat up a bento"
           },
           {
            "parts": [
             {
              "text": "弁当",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "食べる",
              "pos": "V"
             }
            ],
            "ja": "eat a bento"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "弁",
            "meaning": "to handle; to tell apart",
            "on": "ベン",
            "kun": ""
           },
           {
            "kanji": "当",
            "meaning": "to hit; to be fitting",
            "on": "トウ",
            "kun": "あ(たる)"
           }
          ],
          "conjugation": [
           {
            "form": "plain",
            "text": "弁当だ"
           },
           {
            "form": "polite",
            "text": "弁当です"
           },
           {
            "form": "negative",
            "text": "弁当じゃない"
           },
           {
            "form": "past",
            "text": "弁当だった"
           }
          ],
          "politeness": "With お in front (お弁当) it sounds softer, and it is what most people say.",
          "counters": [
           {
            "word": "一個",
            "reading": "いっこ",
            "note": "Bento are usually counted with 個, or simply ひとつ."
           }
          ],
          "related_words": [
           {
            "word": "駅弁",
            "kind": "rel",
            "reading": "えきべん",
            "note": "a bento sold at stations and on trains"
           },
           {
            "word": "給食",
            "kind": "rel",
            "reading": "きゅうしょく",
            "note": "school lunch"
           }
          ],
          "pitch_accent": "Middle-high (3): べんと↘う.",
          "pronunciation_tips": "The final vowel is long: ben-tō, four beats in all.",
          "word_origin": "Sino-Japanese word (kango), read with Chinese-style readings.",
          "etymology": "One theory traces it to an old Chinese word meaning “convenient”. Taiwan's 便當 was later borrowed back from Japanese.",
          "mnemonic": "A bento is convenient food you carry with you.",
          "japan_note": "Ekiben, the bento sold at stations, are one of the joys of train travel in Japan.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "便當",
         "example_translation": "媽媽每天早上都幫我做便當。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "コンビニで弁当を買いました。",
            "ja": "我在便利商店買了便當。",
            "scene": "午餐時間"
           },
           {
            "zh": "お弁当を温めますか。",
            "ja": "便當要加熱嗎？",
            "scene": "便利商店結帳時"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "弁当",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "作る",
              "pos": "V"
             }
            ],
            "ja": "做便當"
           },
           {
            "parts": [
             {
              "text": "弁当",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "温める",
              "pos": "V"
             }
            ],
            "ja": "加熱便當"
           },
           {
            "parts": [
             {
              "text": "弁当",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "食べる",
              "pos": "V"
             }
            ],
            "ja": "吃便當"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "弁",
            "meaning": "處理、辨別",
            "on": "ベン",
            "kun": ""
           },
           {
            "kanji": "当",
            "meaning": "當、適當",
            "on": "トウ",
            "kun": "あ(たる)"
           }
          ],
          "conjugation": [
           {
            "form": "常體",
            "text": "弁当だ"
           },
           {
            "form": "敬體",
            "text": "弁当です"
           },
           {
            "form": "否定形",
            "text": "弁当じゃない"
           },
           {
            "form": "過去形",
            "text": "弁当だった"
           }
          ],
          "politeness": "加上「お」說成「お弁当」，聽起來比較柔和，日常最常這樣說。",
          "counters": [
           {
            "word": "一個",
            "reading": "いっこ",
            "note": "便當一般用「個」來數，也可以說「ひとつ」。"
           }
          ],
          "related_words": [
           {
            "word": "駅弁",
            "kind": "rel",
            "reading": "えきべん",
            "note": "車站或火車上賣的便當"
           },
           {
            "word": "給食",
            "kind": "rel",
            "reading": "きゅうしょく",
            "note": "學校的營養午餐"
           }
          ],
          "pitch_accent": "中高型（3）：べんと↘う。",
          "pronunciation_tips": "「とう」是長音：ben-tō，總共四拍。",
          "word_origin": "漢語（用音讀組成的詞）。",
          "etymology": "一說源自古代中文裡表示「方便」的詞；台灣的「便當」則是後來從日語再傳回來的。",
          "mnemonic": "便當就是方便帶著走的飯。",
          "japan_note": "在日本，車站賣的「駅弁」是搭火車旅行的一大樂趣。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "station",
       "headword": "駅",
       "reading_zhuyin": "えき",
       "pinyin": "eki",
       "part_of_speech": "名詞",
       "category_key": "transport",
       "level": "JLPT-N5",
       "emoji": "🚉",
       "example_sentence": "駅まで歩いて十分です。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "station",
         "example_translation": "It's a ten-minute walk to the station.",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "次の駅で降ります。",
            "ja": "I'm getting off at the next station.",
            "scene": "On the train"
           },
           {
            "zh": "駅で待ち合わせしよう。",
            "ja": "Let's meet at the station.",
            "scene": "Making plans"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "駅",
              "pos": "N"
             },
             {
              "text": "で",
              "pos": "P"
             },
             {
              "text": "降りる",
              "pos": "V"
             }
            ],
            "ja": "get off at the station"
           },
           {
            "parts": [
             {
              "text": "駅",
              "pos": "N"
             },
             {
              "text": "まで",
              "pos": "P"
             },
             {
              "text": "歩く",
              "pos": "V"
             }
            ],
            "ja": "walk to the station"
           },
           {
            "parts": [
             {
              "text": "東京",
              "pos": "N",
              "slot": true,
              "ja": "Tokyo",
              "alts": [
               {
                "text": "新宿",
                "ja": "Shinjuku"
               },
               {
                "text": "大阪",
                "ja": "Osaka"
               }
              ]
             },
             {
              "text": "駅",
              "pos": "N"
             }
            ],
            "ja": "Tokyo Station"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "駅",
            "meaning": "station",
            "on": "エキ",
            "kun": ""
           }
          ],
          "conjugation": [
           {
            "form": "plain",
            "text": "駅だ"
           },
           {
            "form": "polite",
            "text": "駅です"
           },
           {
            "form": "negative",
            "text": "駅じゃない"
           },
           {
            "form": "past",
            "text": "駅だった"
           }
          ],
          "politeness": "No special polite form. Station staff say お客様 to passengers, but 駅 itself stays the same.",
          "counters": [
           {
            "word": "一駅",
            "reading": "ひとえき",
            "note": "Stops are counted with 駅 itself: one stop is 一駅, two stops 二駅."
           }
          ],
          "related_words": [
           {
            "word": "電車",
            "kind": "rel",
            "reading": "でんしゃ",
            "note": "train"
           },
           {
            "word": "改札",
            "kind": "rel",
            "reading": "かいさつ",
            "note": "ticket gate"
           }
          ],
          "pitch_accent": "Head-high (1): え↘き. High on the first beat, then low.",
          "pronunciation_tips": "Two short beats, e-ki. The final i can be almost silent.",
          "word_origin": "Sino-Japanese word (kango), read with Chinese-style readings.",
          "etymology": "駅 has the horse radical 馬: it once meant a post station where travellers changed horses.",
          "mnemonic": "The horse 馬 inside 駅 reminds you of the old post stations.",
          "japan_note": "Big stations such as Shinjuku have dozens of exits, so friends agree on which exit to meet at.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "車站",
         "example_translation": "走到車站要十分鐘。",
         "extras": {
          "frequency_level": 1,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "次の駅で降ります。",
            "ja": "我在下一站下車。",
            "scene": "在電車上"
           },
           {
            "zh": "駅で待ち合わせしよう。",
            "ja": "我們在車站碰面吧。",
            "scene": "約見面"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "駅",
              "pos": "N"
             },
             {
              "text": "で",
              "pos": "P"
             },
             {
              "text": "降りる",
              "pos": "V"
             }
            ],
            "ja": "在車站下車"
           },
           {
            "parts": [
             {
              "text": "駅",
              "pos": "N"
             },
             {
              "text": "まで",
              "pos": "P"
             },
             {
              "text": "歩く",
              "pos": "V"
             }
            ],
            "ja": "走到車站"
           },
           {
            "parts": [
             {
              "text": "東京",
              "pos": "N",
              "slot": true,
              "ja": "東京",
              "alts": [
               {
                "text": "新宿",
                "ja": "新宿"
               },
               {
                "text": "大阪",
                "ja": "大阪"
               }
              ]
             },
             {
              "text": "駅",
              "pos": "N"
             }
            ],
            "ja": "東京車站"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "駅",
            "meaning": "車站",
            "on": "エキ",
            "kun": ""
           }
          ],
          "conjugation": [
           {
            "form": "常體",
            "text": "駅だ"
           },
           {
            "form": "敬體",
            "text": "駅です"
           },
           {
            "form": "否定形",
            "text": "駅じゃない"
           },
           {
            "form": "過去形",
            "text": "駅だった"
           }
          ],
          "politeness": "沒有特別的敬語形式。站務員會稱乘客為「お客様」，但「駅」這個詞不變。",
          "counters": [
           {
            "word": "一駅",
            "reading": "ひとえき",
            "note": "站數直接用「駅」來數：一站是「一駅」，兩站是「二駅」。"
           }
          ],
          "related_words": [
           {
            "word": "電車",
            "kind": "rel",
            "reading": "でんしゃ",
            "note": "電車"
           },
           {
            "word": "改札",
            "kind": "rel",
            "reading": "かいさつ",
            "note": "剪票口"
           }
          ],
          "pitch_accent": "頭高型（1）：え↘き，第一拍高，之後下降。",
          "pronunciation_tips": "短短兩拍 e-ki，結尾的 i 有時幾乎聽不到。",
          "word_origin": "漢語（用音讀組成的詞）。",
          "etymology": "「駅」的部首是「馬」，原本指旅人換馬的驛站。",
          "mnemonic": "看到「駅」裡的「馬」，就想到古代換馬的驛站。",
          "japan_note": "新宿等大車站有幾十個出口，約見面時通常會講好在哪個出口。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "autumnleaves",
       "headword": "紅葉",
       "reading_zhuyin": "こうよう",
       "pinyin": "kōyō",
       "part_of_speech": "名詞",
       "category_key": "plant",
       "level": "JLPT-N2",
       "emoji": "🍁",
       "example_sentence": "秋になると山の紅葉がきれいです。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "autumn leaves, autumn colours",
         "example_translation": "In autumn the leaves on the mountains turn beautiful colours.",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "週末、京都へ紅葉を見に行きます。",
            "ja": "This weekend I'm going to Kyoto to see the autumn leaves.",
            "scene": "Weekend plans"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "紅葉",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "見る",
              "pos": "V"
             }
            ],
            "ja": "look at the autumn leaves"
           },
           {
            "parts": [
             {
              "text": "紅葉",
              "pos": "N"
             },
             {
              "text": "が",
              "pos": "P"
             },
             {
              "text": "きれい",
              "pos": "A"
             }
            ],
            "ja": "the autumn leaves are beautiful"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "紅",
            "meaning": "crimson",
            "on": "コウ",
            "kun": "べに"
           },
           {
            "kanji": "葉",
            "meaning": "leaf",
            "on": "ヨウ",
            "kun": "は"
           }
          ],
          "conjugation": [
           {
            "form": "plain",
            "text": "紅葉だ"
           },
           {
            "form": "polite",
            "text": "紅葉です"
           },
           {
            "form": "negative",
            "text": "紅葉じゃない"
           },
           {
            "form": "past",
            "text": "紅葉だった"
           }
          ],
          "politeness": "No special polite form. In letters, 紅葉の季節となりました is a polite seasonal greeting.",
          "counters": [
           {
            "word": "一枚",
            "reading": "いちまい",
            "note": "A single leaf is counted with 枚, the counter for flat things."
           }
          ],
          "related_words": [
           {
            "word": "もみじ",
            "kind": "syn",
            "reading": "もみじ",
            "note": "another reading of 紅葉; it also means “maple”"
           },
           {
            "word": "紅葉狩り",
            "kind": "rel",
            "reading": "もみじがり",
            "note": "going out to view autumn leaves"
           }
          ],
          "pitch_accent": "Flat (0): こうよう, with no drop.",
          "pronunciation_tips": "Two long vowels: kō-yō, four beats in all.",
          "word_origin": "Sino-Japanese word (kango); read もみじ, it is a native Japanese word.",
          "etymology": "こうよう is the Chinese-style reading of 紅 (red) + 葉 (leaf); もみじ comes from an old verb meaning “to turn red or yellow”.",
          "mnemonic": "紅 red + 葉 leaf = red leaves.",
          "japan_note": "TV forecasts track the autumn colours as they move south from Hokkaido, just like the cherry blossom forecast in spring.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "紅葉、秋天變色的葉子",
         "example_translation": "到了秋天，山上的紅葉很漂亮。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "週末、京都へ紅葉を見に行きます。",
            "ja": "這個週末我要去京都賞楓。",
            "scene": "週末計畫"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "紅葉",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "見る",
              "pos": "V"
             }
            ],
            "ja": "賞楓"
           },
           {
            "parts": [
             {
              "text": "紅葉",
              "pos": "N"
             },
             {
              "text": "が",
              "pos": "P"
             },
             {
              "text": "きれい",
              "pos": "A"
             }
            ],
            "ja": "紅葉很漂亮"
           }
          ],
          "kanji_breakdown": [
           {
            "kanji": "紅",
            "meaning": "紅色",
            "on": "コウ",
            "kun": "べに"
           },
           {
            "kanji": "葉",
            "meaning": "葉子",
            "on": "ヨウ",
            "kun": "は"
           }
          ],
          "conjugation": [
           {
            "form": "常體",
            "text": "紅葉だ"
           },
           {
            "form": "敬體",
            "text": "紅葉です"
           },
           {
            "form": "否定形",
            "text": "紅葉じゃない"
           },
           {
            "form": "過去形",
            "text": "紅葉だった"
           }
          ],
          "politeness": "沒有特別的敬語形式。書信中常用「紅葉の季節となりました」當作季節問候。",
          "counters": [
           {
            "word": "一枚",
            "reading": "いちまい",
            "note": "一片葉子用「枚」來數，這是數扁平物品的量詞。"
           }
          ],
          "related_words": [
           {
            "word": "もみじ",
            "kind": "syn",
            "reading": "もみじ",
            "note": "「紅葉」的另一個讀法，也指楓樹"
           },
           {
            "word": "紅葉狩り",
            "kind": "rel",
            "reading": "もみじがり",
            "note": "到郊外賞楓"
           }
          ],
          "pitch_accent": "平板型（0）：こうよう，不下降。",
          "pronunciation_tips": "兩個長音：kō-yō，總共四拍。",
          "word_origin": "漢語；讀作「もみじ」時則是和語。",
          "etymology": "「こうよう」是紅（紅色）加葉（葉子）的音讀；「もみじ」則來自古語中表示「變紅、變黃」的動詞。",
          "mnemonic": "紅色的葉子，字面就是意思。",
          "japan_note": "日本電視會播報紅葉預報，追蹤紅葉從北海道一路往南，就像春天的櫻花預報。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "mango",
       "headword": "マンゴー",
       "reading_zhuyin": "マンゴー",
       "pinyin": "mangō",
       "part_of_speech": "名詞",
       "category_key": "fruit",
       "level": "JLPT-N3",
       "emoji": "🥭",
       "example_sentence": "宮崎のマンゴーはとても甘いです。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "mango",
         "example_translation": "Mangoes from Miyazaki are very sweet.",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "マンゴーを切ってデザートにしよう。",
            "ja": "Let's cut up a mango for dessert.",
            "scene": "In the kitchen"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "マンゴー",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "切る",
              "pos": "V"
             }
            ],
            "ja": "cut a mango"
           },
           {
            "parts": [
             {
              "text": "完熟",
              "pos": "N",
              "slot": true,
              "ja": "fully ripe",
              "alts": [
               {
                "text": "冷凍",
                "ja": "frozen"
               }
              ]
             },
             {
              "text": "マンゴー",
              "pos": "N"
             }
            ],
            "ja": "a fully ripe mango"
           }
          ],
          "conjugation": [
           {
            "form": "plain",
            "text": "マンゴーだ"
           },
           {
            "form": "polite",
            "text": "マンゴーです"
           },
           {
            "form": "negative",
            "text": "マンゴーじゃない"
           },
           {
            "form": "past",
            "text": "マンゴーだった"
           }
          ],
          "politeness": "No special polite form; マンゴー works in any situation.",
          "counters": [
           {
            "word": "一個",
            "reading": "いっこ",
            "note": "Fruit is counted with 個, or simply ひとつ."
           }
          ],
          "related_words": [
           {
            "word": "パイナップル",
            "kind": "rel",
            "reading": "ぱいなっぷる",
            "note": "pineapple, another tropical fruit"
           },
           {
            "word": "果物",
            "kind": "rel",
            "reading": "くだもの",
            "note": "fruit in general"
           }
          ],
          "pitch_accent": "Head-high (1): マ↘ンゴー.",
          "pronunciation_tips": "The last vowel is long: man-gō, four beats in all.",
          "word_origin": "Loanword (gairaigo) from English “mango”.",
          "etymology": "From English mango, which came through Portuguese from a language of southern India.",
          "mnemonic": "Just “mango” with a long ō at the end.",
          "japan_note": "Miyazaki and Okinawa grow luxury mangoes; the top grade from Miyazaki is a popular, pricey gift.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "芒果",
         "example_translation": "宮崎的芒果非常甜。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "マンゴーを切ってデザートにしよう。",
            "ja": "我們把芒果切一切當甜點吧。",
            "scene": "在廚房"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "マンゴー",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "切る",
              "pos": "V"
             }
            ],
            "ja": "切芒果"
           },
           {
            "parts": [
             {
              "text": "完熟",
              "pos": "N",
              "slot": true,
              "ja": "熟透的",
              "alts": [
               {
                "text": "冷凍",
                "ja": "冷凍"
               }
              ]
             },
             {
              "text": "マンゴー",
              "pos": "N"
             }
            ],
            "ja": "熟透的芒果"
           }
          ],
          "conjugation": [
           {
            "form": "常體",
            "text": "マンゴーだ"
           },
           {
            "form": "敬體",
            "text": "マンゴーです"
           },
           {
            "form": "否定形",
            "text": "マンゴーじゃない"
           },
           {
            "form": "過去形",
            "text": "マンゴーだった"
           }
          ],
          "politeness": "沒有特別的敬語形式，「マンゴー」在任何場合都能用。",
          "counters": [
           {
            "word": "一個",
            "reading": "いっこ",
            "note": "水果用「個」來數，也可以說「ひとつ」。"
           }
          ],
          "related_words": [
           {
            "word": "パイナップル",
            "kind": "rel",
            "reading": "ぱいなっぷる",
            "note": "鳳梨，同樣是熱帶水果"
           },
           {
            "word": "果物",
            "kind": "rel",
            "reading": "くだもの",
            "note": "水果的總稱"
           }
          ],
          "pitch_accent": "頭高型（1）：マ↘ンゴー。",
          "pronunciation_tips": "最後是長音：man-gō，總共四拍。",
          "word_origin": "外來語，來自英語的 mango。",
          "etymology": "來自英語的 mango；英語則是經由葡萄牙語，從南印度的語言借來的。",
          "mnemonic": "就是英語的 mango，最後拉長音。",
          "japan_note": "宮崎和沖繩出產高級芒果，宮崎的頂級芒果是很受歡迎的高價禮品。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "pineapple",
       "headword": "パイナップル",
       "reading_zhuyin": "パイナップル",
       "pinyin": "painappuru",
       "part_of_speech": "名詞",
       "category_key": "fruit",
       "level": "JLPT-N3",
       "emoji": "🍍",
       "example_sentence": "沖縄でパイナップルを食べました。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "pineapple",
         "example_translation": "I ate pineapple in Okinawa.",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "このパイナップル、すごく甘い！",
            "ja": "This pineapple is really sweet!",
            "scene": "Tasting"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "パイナップル",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "切る",
              "pos": "V"
             }
            ],
            "ja": "cut a pineapple"
           },
           {
            "parts": [
             {
              "text": "パイナップル",
              "pos": "N"
             },
             {
              "text": "が",
              "pos": "P"
             },
             {
              "text": "甘い",
              "pos": "A"
             }
            ],
            "ja": "the pineapple is sweet"
           }
          ],
          "counters": [
           {
            "word": "一個",
            "reading": "いっこ",
            "note": "Counted with 個."
           }
          ],
          "related_words": [
           {
            "word": "パイン",
            "kind": "syn",
            "reading": "ぱいん",
            "note": "a short form"
           }
          ],
          "pitch_accent": "Middle-high (3): パイナ↘ップル.",
          "pronunciation_tips": "The small ッ is a short pause: pa-i-na-p-pu-ru.",
          "word_origin": "Loanword (gairaigo) from English “pineapple”.",
          "etymology": "From English pineapple, which first meant “pine cone”.",
          "mnemonic": "English “pineapple” said in Japanese beats.",
          "japan_note": "Most pineapples grown in Japan come from Okinawa.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "鳳梨",
         "example_translation": "我在沖繩吃了鳳梨。",
         "extras": {
          "frequency_level": 2,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "このパイナップル、すごく甘い！",
            "ja": "這顆鳳梨好甜！",
            "scene": "試吃的時候"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "パイナップル",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "切る",
              "pos": "V"
             }
            ],
            "ja": "切鳳梨"
           },
           {
            "parts": [
             {
              "text": "パイナップル",
              "pos": "N"
             },
             {
              "text": "が",
              "pos": "P"
             },
             {
              "text": "甘い",
              "pos": "A"
             }
            ],
            "ja": "鳳梨很甜"
           }
          ],
          "counters": [
           {
            "word": "一個",
            "reading": "いっこ",
            "note": "用「個」來數。"
           }
          ],
          "related_words": [
           {
            "word": "パイン",
            "kind": "syn",
            "reading": "ぱいん",
            "note": "簡稱"
           }
          ],
          "pitch_accent": "中高型（3）：パイナ↘ップル。",
          "pronunciation_tips": "「ッ」是促音，要停頓一拍：pa-i-na-p-pu-ru。",
          "word_origin": "外來語，來自英語的 pineapple。",
          "etymology": "來自英語的 pineapple，原本是「松果」的意思。",
          "mnemonic": "把英語 pineapple 用日語的節拍唸出來。",
          "japan_note": "日本產的鳳梨大多來自沖繩。",
          "explain_lang": "zh-TW"
         }
        }
       }
      },
      {
       "key": "scooter",
       "headword": "スクーター",
       "reading_zhuyin": "スクーター",
       "pinyin": "sukūtā",
       "part_of_speech": "名詞",
       "category_key": "vehicle",
       "level": "JLPT-N2",
       "emoji": "🛵",
       "example_sentence": "スクーターで近所のスーパーに行きます。",
       "language": "ja",
       "explain": {
        "en": {
         "meaning": "scooter",
         "example_translation": "I ride my scooter to the local supermarket.",
         "extras": {
          "frequency_level": 3,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "スクーターに乗るときはヘルメットをかぶります。",
            "ja": "You wear a helmet when you ride a scooter.",
            "scene": "Traffic rules"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "スクーター",
              "pos": "N"
             },
             {
              "text": "に",
              "pos": "P"
             },
             {
              "text": "乗る",
              "pos": "V"
             }
            ],
            "ja": "ride a scooter"
           },
           {
            "parts": [
             {
              "text": "スクーター",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "止める",
              "pos": "V"
             }
            ],
            "ja": "park a scooter"
           }
          ],
          "counters": [
           {
            "word": "一台",
            "reading": "いちだい",
            "note": "Vehicles are counted with 台."
           }
          ],
          "related_words": [
           {
            "word": "原付",
            "kind": "syn",
            "reading": "げんつき",
            "note": "a moped of up to 50 cc"
           },
           {
            "word": "バイク",
            "kind": "rel",
            "reading": "ばいく",
            "note": "motorbike in general"
           }
          ],
          "pitch_accent": "Middle-high (2): スク↘ーター.",
          "pronunciation_tips": "Two long vowels: su-kū-tā, five beats in all.",
          "word_origin": "Loanword (gairaigo) from English “scooter”.",
          "mnemonic": "English “scooter” with a long ū and a long ā.",
          "japan_note": "In Japan, a car driving licence also lets you ride a 50 cc scooter.",
          "explain_lang": "en"
         }
        },
        "zh-TW": {
         "meaning": "機車、速克達",
         "example_translation": "我騎機車去附近的超市。",
         "extras": {
          "frequency_level": 3,
          "register_scale": 0,
          "examples_extra": [
           {
            "zh": "スクーターに乗るときはヘルメットをかぶります。",
            "ja": "騎機車的時候要戴安全帽。",
            "scene": "交通規則"
           }
          ],
          "usage_chunks": [
           {
            "parts": [
             {
              "text": "スクーター",
              "pos": "N"
             },
             {
              "text": "に",
              "pos": "P"
             },
             {
              "text": "乗る",
              "pos": "V"
             }
            ],
            "ja": "騎機車"
           },
           {
            "parts": [
             {
              "text": "スクーター",
              "pos": "N"
             },
             {
              "text": "を",
              "pos": "P"
             },
             {
              "text": "止める",
              "pos": "V"
             }
            ],
            "ja": "停機車"
           }
          ],
          "counters": [
           {
            "word": "一台",
            "reading": "いちだい",
            "note": "車輛用「台」來數。"
           }
          ],
          "related_words": [
           {
            "word": "原付",
            "kind": "syn",
            "reading": "げんつき",
            "note": "50cc 以下的輕型機車"
           },
           {
            "word": "バイク",
            "kind": "rel",
            "reading": "ばいく",
            "note": "機車的總稱"
           }
          ],
          "pitch_accent": "中高型（2）：スク↘ーター。",
          "pronunciation_tips": "兩個長音：su-kū-tā，總共五拍。",
          "word_origin": "外來語，來自英語的 scooter。",
          "mnemonic": "英語的 scooter，ū 和 ā 都拉長。",
          "japan_note": "在日本，有汽車駕照就可以騎 50cc 的機車。",
          "explain_lang": "zh-TW"
         }
        }
       }
      }
     ],
     "variants": [
      {
       "headword": "原付",
       "reading_zhuyin": "げんつき",
       "pinyin": "gentsuki",
       "of": "scooter",
       "register": "specific",
       "category_key": "vehicle",
       "meaning": {
        "en": "moped (up to 50 cc)",
        "zh-TW": "輕型機車"
       },
       "distinction": {
        "en": "the name for small 50 cc bikes",
        "zh-TW": "50cc 以下小型機車的名稱"
       }
      }
     ],
     "distinctions": {
      "scooter": {
       "en": "the everyday word",
       "zh-TW": "最常用的說法"
      },
      "pineapple": {
       "en": "the everyday word",
       "zh-TW": "最常用的說法"
      },
      "cat": {
       "en": "the everyday word",
       "zh-TW": "最常用的說法"
      }
     },
     "wordbook": {
      "title": {
       "en": "Fruit words",
       "zh-TW": "水果單字"
      },
      "entries": [
       {
        "headword": "りんご",
        "reading_zhuyin": "りんご",
        "pinyin": "ringo",
        "meaning": {
         "en": "apple",
         "zh-TW": "蘋果"
        }
       },
       {
        "headword": "バナナ",
        "reading_zhuyin": "バナナ",
        "pinyin": "banana",
        "meaning": {
         "en": "banana",
         "zh-TW": "香蕉"
        }
       },
       {
        "headword": "すいか",
        "reading_zhuyin": "すいか",
        "pinyin": "suika",
        "meaning": {
         "en": "watermelon",
         "zh-TW": "西瓜"
        }
       },
       {
        "headword": "ぶどう",
        "reading_zhuyin": "ぶどう",
        "pinyin": "budō",
        "meaning": {
         "en": "grape",
         "zh-TW": "葡萄"
        }
       },
       {
        "headword": "いちご",
        "reading_zhuyin": "いちご",
        "pinyin": "ichigo",
        "meaning": {
         "en": "strawberry",
         "zh-TW": "草莓"
        }
       },
       {
        "headword": "もも",
        "reading_zhuyin": "もも",
        "pinyin": "momo",
        "meaning": {
         "en": "peach",
         "zh-TW": "桃子"
        }
       }
      ]
     },
     "journal": {
      "draft": "今日は駅の前で猫を見ました。とてもかわいいでした。",
      "correction": "今日は駅の前で猫を見ました。とてもかわいかったです。",
      "body": {
       "en": "Today I saw a cat in front of the station. It was really cute.",
       "zh-TW": "今天在車站前看到一隻貓，非常可愛。"
      },
      "feedback": {
       "en": "An い-adjective changes itself for the past: say “かわいかったです”, not “かわいいでした”.",
       "zh-TW": "い形容詞的過去式要直接變化：要說「かわいかったです」，不說「かわいいでした」。"
      },
      "phrases": [
       {
        "zh": "駅前で猫に会った。",
        "ja": {
         "en": "I came across a cat in front of the station.",
         "zh-TW": "在車站前遇到一隻貓。"
        },
        "note": {
         "en": "会う makes it sound like a friendly encounter.",
         "zh-TW": "用「会う」聽起來像是跟朋友不期而遇。"
        }
       },
       {
        "zh": "めっちゃかわいかった！",
        "ja": {
         "en": "It was super cute!",
         "zh-TW": "超可愛的！"
        },
        "note": {
         "en": "めっちゃ is a casual way to say “very”.",
         "zh-TW": "「めっちゃ」是「非常」的口語說法。"
        }
       }
      ]
     },
     "prompts": [
      {
       "zh": "今日、どこで猫を見ましたか。",
       "ja": {
        "en": "Where did you see a cat today?",
        "zh-TW": "你今天在哪裡看到貓？"
       },
       "word": "cat"
      },
      {
       "zh": "お弁当には何が入っていましたか。",
       "ja": {
        "en": "What was in your bento?",
        "zh-TW": "你的便當裡有什麼？"
       },
       "word": "bento"
      }
     ],
     "patterns": [
      {
       "zh": "今日、＿＿で＿＿を見ました。",
       "ja": {
        "en": "Today I saw ___ at ___.",
        "zh-TW": "今天我在＿＿看到了＿＿。"
       }
      },
      {
       "zh": "＿＿がとても＿＿かったです。",
       "ja": {
        "en": "The ___ was very ___.",
        "zh-TW": "＿＿非常＿＿。"
       }
      }
     ],
     "synth": {
      "level": "JLPT-N4",
      "pos": "名詞",
      "example": "今日、{h}を見ました。",
      "ex_tr": {
       "en": "Today I saw “{h}”.",
       "zh-TW": "今天看到了「{h}」。"
      },
      "chunk_parts": [
       [
        "{h}",
        "N"
       ],
       [
        "を",
        "P"
       ],
       [
        "見る",
        "V"
       ]
      ],
      "chunk_tr": {
       "en": "see “{h}”",
       "zh-TW": "看到「{h}」"
      }
     },
     "places": [
      {
       "lat": 35.6812,
       "lng": 139.7671,
       "name": {
        "ja": "東京駅",
        "en": "Tokyo Station",
        "zh-TW": "東京車站"
       }
      },
      {
       "lat": 35.6595,
       "lng": 139.7005,
       "name": {
        "ja": "渋谷",
        "en": "Shibuya",
        "zh-TW": "澀谷"
       }
      },
      {
       "lat": 35.7148,
       "lng": 139.7967,
       "name": {
        "ja": "浅草",
        "en": "Asakusa",
        "zh-TW": "淺草"
       }
      }
     ],
     "common": {
      "caption": {
       "ja": "はじめて見つけた！",
       "en": "Spotted this today!",
       "zh-TW": "今天發現的！"
      },
      "feedback_generic": {
       "ja": "自然に書けています。この調子で続けましょう。",
       "en": "This reads naturally. Keep it up!",
       "zh-TW": "寫得很自然，繼續保持！"
      },
      "display_name": {
       "ja": "ミカ",
       "en": "Mika",
       "zh-TW": "米卡"
      }
     }
    }
    """#
}
#endif
