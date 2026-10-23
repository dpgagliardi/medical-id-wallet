# Istruzioni per Copilot: Medical ID Wallet

Widget Garmin Connect IQ in Monkey C che mostra sull'orologio i dati medici di emergenza inseriti dall'utente in Garmin Connect Mobile, senza rete. Pubblicato sul Connect IQ Store e mantenuto da Daniele nel tempo libero. Funzioni, compatibilità e licenza sono nel [README](../README.md).

## Struttura
- `source/`: codice Monkey C (app, vista, delegato, modello, codici a barre, impaginazione del testo)
- `resources/` e `resources-<lingua>/`: risorse e le 20 traduzioni di `strings/strings.xml`
- `resources-launcher/`: icone del launcher per dimensione, generate da `store/icon/build_icons.py`
- `manifest.xml`: versione pubblicata, dispositivi supportati, permessi (nessuno)
- `manifest-edge.xml` e `monkey-edge.jungle`: device app per gli Edge che non accettano widget (540, 840, 1040 e successivi), stesso codice, ID app e scheda Store separati
- `store/`: materiale per la scheda dello store

## Comandi
```bash
python3 .github/scripts/check_resources.py   # XML, traduzioni, versione manifest = CHANGELOG
SDK="/path/to/connectiq-sdk"                 # SDK Connect IQ 9.2.0 installato in locale
java -jar "${SDK}/bin/monkeybrains.jar" \
  -o bin/medicalidwallet.prg \
  -f monkey.jungle -y medicalidwallet_key.der \
  -d fr955_sim -l 0
```
La CI non compila (l'SDK richiede di accettare la licenza Garmin a mano): esegue solo il controllo delle risorse e i controlli di igiene. L'unica verifica di compilazione è quella locale.

## Build e firma
- La chiave di firma è `medicalidwallet_key.der` nella radice (esclusa da git). È obbligatoria per i pacchetti Store (`-e`): Garmin rifiuta una versione firmata con un'altra chiave ("Controllo firma non riuscito"). Le chiavi `saferunner_*` sono legacy: non usarle.
- Compila per più di un dispositivo prima di dire che una modifica funziona, almeno: `fr235` (sotto API 3.1.0, niente `Application.Properties` né `Storage`, e l'errore di simbolo non è catturabile), `fr55` e `instinct2` (widget da 64 KB, i più installati), `fr955_sim`, `edge530` (Edge vecchio, widget) e `edge1040` con `-f monkey-edge.jungle`.
- Le differenze tra widget e device app Edge stanno nelle annotazioni `(:widgetApp)`/`(:deviceApp)` e `(:watchOpenHint)`/`(:edgeOpenHint)` escluse dai jungle. Le versioni dei due manifest restano uguali.
- Nel simulatore la build si chiama sempre `medicalidwallet.prg`, mai `<dispositivo>.prg`: altrimenti l'App Settings Editor cerca `<DEVICE>-settings.json` e fallisce con "No settings file found", e si ripara solo cancellando `$TMPDIR/com.garmin.connectiq`. Per build per più dispositivi, una cartella ciascuno con lo stesso nome di file.
- Dopo aver aggiunto un dispositivo al manifest o modificato le icone, esegui `python3 store/icon/build_icons.py` (serve `brew install librsvg imagemagick`). Lo script riscrive il blocco icone in `monkey.jungle` e `monkey-edge.jungle`: non modificarlo a mano.

## Regole del progetto
- Nessuna richiesta di rete, mai: `manifest.xml` non dichiara permessi e così deve restare. È la promessa dell'app e il motivo della licenza GPL con i termini di NOTICE.
- Non è un dispositivo medico: non aggiungere funzioni che interpretano, validano o suggeriscono qualcosa sui dati inseriti.
- Ogni nuovo testo visibile va aggiunto in tutti e 20 i file `strings.xml` (`resources/` e `resources-<lingua>/`). Una traduzione automatica non riletta è peggio del fallback inglese: se la usi, dillo.
- I nuovi file sorgente portano la stessa intestazione degli esistenti, compresa la riga che rimanda a NOTICE.
- `PRIVACY.md` resta solo in inglese, per scelta: non proporre traduzioni. Il contatto del progetto in ogni documento è dpgagliardi.dev@gmail.com.
- Il vecchio nome "SafeRunner ICE Wallet" non deve ricomparire in classi, file o documenti.
- Dalla 1.1.0 la schermata principale usa un layout compatto ("ETICHETTA: valore" su una riga; telefoni, ID e date mai spezzati tra due righe) e lo scroll si ferma all'inizio di ogni campo. Una tabella vera a due colonne è stata scartata: sugli schermi rotondi etichetta o valore finiscono sotto la lunetta.
- Le chiavi di firma `.der` e `.pem` nella radice sono escluse da git e vanno conservate: non leggerle, non spostarle, non cancellarle, non aggiungerle a un commit.
- `TEST_MATRIX.md` (escluso da git) contiene solo dati finti e deve restare così: niente dati personali veri nei test.

## Versioni e git
- Mai tag git né GitHub release, nemmeno come proposta. Una release è: aumento della versione in `manifest.xml`, nuova voce in `CHANGELOG.md` (Keep a Changelog, SemVer), build `.iq`, e basta. Il controllo delle risorse fallisce se i due numeri non coincidono.
- La versione cambia solo quando Daniele lo chiede.
- Commit e push solo se Daniele lo chiede. Mai righe `Co-Authored-By` o riferimenti ad assistenti di programmazione nei commit o nei file del repo: un hook `commit-msg` rifiuta il commit, e non si aggira con `--no-verify`.
- Non eseguire comandi git che riscrivono i file (`checkout`, `restore`, `reset`, `stash`, `clean`): possono cancellare lavoro non committato.

## Regole generali
- Rispondi in italiano. Codice, commenti, messaggi di commit e stringhe dell'app in inglese (le altre lingue solo nelle risorse tradotte).
- Niente trattino lungo né medio, puntino centrale, frecce o tilde per "circa" nei testi; niente emoji nel codice e nei testi.
- Non leggere, stampare o committare segreti (chiavi di firma `.der` e `.pem`, `.env`, `.p8`).
- Se un'informazione manca o non hai accesso a qualcosa, dillo: non inventare.
