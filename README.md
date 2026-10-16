# Rádio

Webová aplikácia (PWA) na počúvanie internetových rádií z celého sveta. Rádiá sa hľadajú cez
verejnú databázu [radio-browser.info](https://www.radio-browser.info), obľúbené sa ukladajú
v zariadení a sú na hlavnej obrazovke – ťuknutím sa hneď pustia.

- **Obľúbené** – mriežka obľúbených rádií, ťuknutie = prehrať / pozastaviť. „Upraviť“ umožní mazať a presúvať.
- **Hľadať** – podľa názvu, krajiny a žánru (výber zo zoznamu); bez zadania zobrazí najpopulárnejšie rádiá zvolenej krajiny.
- **Nastavenia** – export/import zálohy obľúbených, ručné pridanie streamu cez URL.
- Ovládanie zo zamknutej obrazovky (Media Session), predchádzajúce/ďalšie = prepínanie obľúbených.

Bez build kroku a bez závislostí – čisté HTML/CSS/JS.

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
