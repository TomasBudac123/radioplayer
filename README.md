# Rádio

Webová aplikácia (PWA) na počúvanie internetových rádií z celého sveta. Rádiá sa hľadajú cez
verejnú databázu [radio-browser.info](https://www.radio-browser.info), obľúbené sa ukladajú
v zariadení a sú na hlavnej obrazovke – ťuknutím sa hneď pustia.

- **Obľúbené** – mriežka obľúbených rádií, ťuknutie = prehrať / pozastaviť. „Upraviť“ umožní mazať a presúvať.
- **Hľadať** – podľa názvu, krajiny a žánru (výber zo zoznamu); predvolene celý svet a všetky žánre; bez zadania zobrazí najpopulárnejšie rádiá.
- **Nastavenia** – export/import zálohy obľúbených, ručné pridanie streamu cez URL.
- Ovládanie zo zamknutej obrazovky (Media Session), predchádzajúce/ďalšie = prepínanie obľúbených.

Bez build kroku a bez závislostí – čisté HTML/CSS/JS.

## Natívne aplikácie

| Platforma | Priečinok | Technológie | V aute |
| --- | --- | --- | --- |
| iOS | [`ios/`](ios/README.md) | SwiftUI, The Composable Architecture (Point-Free) | CarPlay |
| Android | [`android/`](android/README.md) | Kotlin, Jetpack Compose, Media3 | Android Auto |

Obe appky zdieľajú dizajnové tokeny ([`design/tokens.json`](design/tokens.json)) – neutrálnu paletu
pre svetlý aj tmavý režim, kde farbu prinášajú len logá rádií – a formát zálohy obľúbených,
takže súbor exportovaný z webu sa dá importovať v telefóne a naopak.

**Preklady:** angličtina, slovenčina, čeština, nemčina, španielčina, francúzština, taliančina, poľština,
maďarčina a portugalčina. Texty oboch appiek sú v jednej tabuľke
[`localization/strings.json`](localization/strings.json); po úprave pregeneruj zdroje pre iOS aj Android:

```bash
python3 tools/gen-strings.py
```

**Hlasové ovládanie:** „Siri, pusti Rádio Expres v Rádiu“ (iPhone aj CarPlay) a „Hey Google, pusti … v Rádiu“
(Android aj Android Auto). Hľadá sa najprv presný názov v obľúbených, potom žáner („pusti jazz“),
potom čiastočná zhoda s obľúbeným rádiom a nakoniec celá databáza.

## Lokálne spustenie

```bash
python3 -m http.server 5173
```

Potom otvor http://localhost:5173.

## Nasadenie (GitHub Pages)

1. Pushni repozitár na GitHub.
2. *Settings → Pages → Build and deployment*: Source = *Deploy from a branch*, Branch = `main`, priečinok `/ (root)`.
3. Aplikácia bude na `https://<user>.github.io/radioplayer/`.

## Inštalácia na iPhone

Otvor adresu v **Safari** → tlačidlo **Zdieľať** → **Pridať na plochu**. Aplikácia sa potom spúšťa na celú obrazovku
ako natívna appka a hrá aj na pozadí / pri zamknutom displeji.

## Poznámky

- Niektoré rádiá vysielajú len cez `http://`. Na stránke cez HTTPS ich Safari môže zablokovať (mixed content) –
  aplikácia najprv skúsi `https://` verziu streamu a potom pôvodnú adresu.
- Ikony sa generujú skriptom `node tools/make-icons.mjs`.

## Plagát

V priečinku `poster/` je plagát s krátkym popisom aplikácie a QR kódom (`poster/radio-plagat.png`, A4 pri 300 DPI).
Nanovo sa vyrenderuje (potrebuje Google Chrome a bežiaci lokálny server):

```bash
node poster/render.mjs
```
