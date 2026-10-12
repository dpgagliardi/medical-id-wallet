# Istruzioni per Copilot: Medical ID Wallet (SafeRunner ICE Wallet)

Widget Garmin Connect IQ in Monkey C che mostra sull'orologio i dati medici di emergenza inseriti dall'utente in Garmin Connect Mobile, senza rete. Pubblicato sul Connect IQ Store e mantenuto da Daniele nel tempo libero. Funzioni, compatibilità e licenza sono nel [README](../README.md).

## Struttura
- `source/`: codice Monkey C (app, vista, delegato, modello, codici a barre, impaginazione del testo)
- `resources/` e `resources-<lingua>/`: risorse e le 20 traduzioni di `strings/strings.xml`
- `resources-<forma>-<risoluzione>/`: risorse per forma e dimensione dello schermo
- `manifest.xml`: versione pubblicata, dispositivi supportati, permessi (nessuno)
- `store/`: materiale per la scheda dello store

## Comandi
```bash
python3 .github/scripts/check_resources.py   # XML, traduzioni, versione manifest = CHANGELOG
SDK="/path/to/connectiq-sdk"
java -jar "${SDK}/bin/monkeybrains.jar" \
  -o bin/medicalidwallet.prg \
  -f monkey.jungle -y <chiave_sviluppatore>.der \
  -d fr955_sim -l 0
```
La CI non compila (l'SDK richiede di accettare la licenza Garmin a mano): esegue solo il controllo delle risorse.

## Regole del progetto
- Nessuna richiesta di rete, mai: `manifest.xml` non dichiara permessi e così deve restare. È la promessa dell'app e il motivo della licenza GPL con i termini di NOTICE.
- Non è un dispositivo medico: non aggiungere funzioni che interpretano, validano o suggeriscono qualcosa sui dati inseriti.
- Ogni nuovo testo visibile va aggiunto in tutti e venti i file `resources-*/strings/strings.xml`. Una traduzione automatica non riletta è peggio del fallback inglese: se la usi, dillo.
- Compila per più di un dispositivo prima di dire che una modifica funziona: i guasti che passano sono specifici del dispositivo (per esempio `fr235` è sotto API 3.1.0 e non ha `Application.Properties`; alcuni modelli hanno 64 KB di memoria per i widget).
- Nel simulatore la build si chiama sempre `medicalidwallet.prg`, mai con il nome del dispositivo: altrimenti l'editor delle impostazioni cerca il file sbagliato. Per build per dispositivo, una cartella ciascuna con lo stesso nome di file.
- I nuovi file sorgente portano la stessa intestazione degli esistenti, compresa la riga che rimanda a NOTICE.
- `PRIVACY.md` resta solo in inglese, per scelta: non proporre traduzioni. Il contatto del progetto in ogni documento è dpgagliardi.dev@gmail.com.
- Il layout a tabella della schermata principale (meno scorrimenti con molti campi lunghi) è un'idea rimandata a una futura versione: proponila, non implementarla senza richiesta.
- Le chiavi di firma `.der` e `.pem` nella radice sono escluse da git e vanno conservate: non leggerle, non spostarle, non cancellarle, non aggiungerle a un commit.
- I dati in `TEST_MATRIX.md` sono finti e devono restarlo: niente dati personali veri nei test.

## Regole generali
- Rispondi in italiano. Codice, commenti, messaggi di commit e testi dell'app in inglese (le altre lingue solo nelle risorse tradotte).
- Commit e push solo se Daniele lo chiede. Mai tag git di versione né GitHub release, nemmeno come proposta: la versione vive solo in `manifest.xml` e `CHANGELOG.md`. Mai righe `Co-Authored-By` o riferimenti a Copilot/Claude/AI nei commit o nei file del repo: un hook rifiuta il commit, e non si aggira con `--no-verify`.
- Non eseguire comandi git che riscrivono i file (`checkout`, `restore`, `reset`, `stash`, `clean`): possono cancellare lavoro non committato.
- Niente trattino lungo né medio, puntino centrale, frecce o tilde per "circa" nei testi; niente emoji nel codice e nei testi.
- Non leggere, stampare o committare segreti (chiavi di firma `.der` e `.pem`, `.env`, `.p8`).
- Versione cambia solo quando Daniele lo chiede: si aggiornano insieme `manifest.xml` e una nuova voce in `CHANGELOG.md` (Keep a Changelog, SemVer), poi la build `.iq`. Il controllo delle risorse fallisce se i due numeri non coincidono.
- Se un'informazione manca o non hai accesso a qualcosa, dillo: non inventare.
