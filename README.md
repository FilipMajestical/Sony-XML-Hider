# Sony XML Hider for macOS

Besplatan Majestical utility za Sony korisnike. Kada macOS detektuje Sony karticu sa folderom `PRIVATE/M4ROOT/CLIP`, aplikacija:

- sakrije `.XML` sidecar fajlove pomoću macOS `hidden` file flag-a;
- automatski otvori `CLIP` folder u Finderu;
- radi u pozadini;
- prepoznaje i zamenu kartice dok čitač ostaje priključen;
- ne briše niti menja sadržaj video/XML fajlova.

## Build bez Mac računara

1. Napravi prazan GitHub repository.
2. Uploaduj sadržaj ovog foldera u repo.
3. Otvori **Actions → Build macOS app → Run workflow**.
4. Kada build završi, skini artifact **Sony-XML-Hider-macOS**.
5. U njemu je `Sony_XML_Hider_macOS_v1.0.0.zip` sa gotovim `.app` fajlom.

Ne treba ti Apple Developer nalog za ovaj build.

## Gatekeeper

Pošto aplikacija nije potpisana Apple Developer ID sertifikatom niti notarizovana, korisnik će pri prvom pokretanju verovatno dobiti upozorenje. Najnormalniji način je:

- pokušati da otvori aplikaciju jednom;
- zatim **System Settings → Privacy & Security → Open Anyway**;
- potvrditi otvaranje.

Alternativno, na nekim verzijama macOS-a radi **Control-click / Right-click → Open**.

## Instalacija

Pokreni app i klikni **Install**. Aplikacija se kopira u:

`~/Applications/Sony XML Hider.app`

i pravi LaunchAgent:

`~/Library/LaunchAgents/com.majestical.sonyxmlhider.plist`

Za uninstall ponovo pokreni installer app i klikni **Uninstall**.

## Važno za testiranje

Ovaj projekat je pripremljen bez fizičkog Mac računara i Sony SD kartice, pa prvi macOS build treba tretirati kao beta dok ga neko ne testira na stvarnom Mac-u i Sony kartici (posebno exFAT kartici).
