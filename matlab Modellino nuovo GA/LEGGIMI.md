# Fiscal footprints in MATLAB

## Per iniziare

1. Apri MATLAB e seleziona questa cartella (`matlab`) come **Current Folder**.
2. Apri **simulate_ss.m** e premi **Run**.
3. Compariranno il grafico a quattro pannelli e una tabella con i risultati.

Non occorrono Python o toolbox aggiuntivi. I file usano funzioni disponibili in MATLAB R2021a e successivi; sono stati eseguiti e verificati localmente con R2024b Update 5.

## Per cambiare i parametri

Apri **parametri_ss.m**, cambia il valore desiderato, salva e premi nuovamente Run in **simulate_ss.m**. Tutti i parametri economici sono raccolti in quel file, con commenti in italiano. Non è necessario modificare il risolutore.

Esempio: `p.PHI = 0.3;` cambia la risposta della politica monetaria. Il codice ricalcola automaticamente radice stabile, riferimenti senza notizia, correzioni e inflazione di equilibrio.

| Parametro | Significato | Valore iniziale |
|---|---|---:|
| BETA | Fattore di sconto annuo | 0.96 |
| SIGMA | Curvatura dell'utilità del consumo | 1 |
| NU | Curvatura della disutilità del lavoro | 1 |
| THETA | Probabilità di non modificare il prezzo | 0.6 |
| PHI | Risposta monetaria all'inflazione, tra 0 e 1 escluso | 0.5 |
| LOWER | Soglia delle riserve | 8 |
| INITIAL_RESERVES | Riserve ereditate alla fine dell'anno -1 | 10.6 |
| INITIAL_PUBLIC_DEBT | Debito detenuto dal pubblico alla fine dell'anno -1 | 60 |
| AMPLE_TAU | Saldo previdenziale di riferimento, caso ampio | 0.6 |
| DEPLETION_TAU | Saldo previdenziale di riferimento, caso esaurimento | -0.7 |
| J | Orizzonte della proiezione attuariale | 10 |
| REVISION_PER_YEAR | Incremento annuo del peggioramento dei saldi | 0.015 |
| H | Orizzonte numerico per i valori attuali | 800 |
| SHOW | Ultimo anno mostrato nel grafico | 25 |
| P_Y, V_O | Contributo per giovane e beneficio per anziano | 12, 24 |

Un periodo è un anno. Tutti i saldi fiscali e le riserve sono in percentuale del **PIL di riferimento**, fissato a 100. Il saldo corrente non cambia a data 0: la notizia riguarda gli anni successivi. La revisione terminale `-REVISION_PER_YEAR*J` resta permanente dopo J.

Cambiare J mantenendo REVISION_PER_YEAR fisso cambia anche la dimensione finale dello shock. P_Y e V_O servono a interpretare i saldi in termini demografici: i saldi sono impostati direttamente, quindi cambiare soltanto P_Y o V_O non cambia le risposte macroeconomiche.

## Come leggere i risultati in MATLAB

Dopo Run, nel Workspace trovi:

- `p`: parametri utilizzati;
- `risultati`: soluzione completa, con tutti gli anni da 0 a H;
- `ample` e `poor`: scenari con notizia;
- `ample_base` e `poor_base`: corrispondenti riferimenti senza notizia;
- `anni`: anni da 0 a H;
- `riepilogo`: tabella dei risultati;
- `verifica`: tabella dei controlli ex post, con residui massimi e anni critici;
- `figura`: grafico modificabile.

**Gli indici MATLAB iniziano da 1:** `poor.reserves(1)` indica l'anno 0, `poor.reserves(8)` l'anno 7. Invece `poor.breach` e `poor.first_correction` contengono direttamente l'anno del modello. `NaN` indica che non si verifica l'evento entro H.

Esempi da scrivere nella Command Window:

```matlab
100*ample.inflation(1)    % Inflazione iniziale, punti percentuali
100*ample.output(1)       % Output iniziale, percentuale
poor.first_correction    % Anno della prima correzione
poor.reserves(8)          % Riserve nell'anno 7
poor.extra_correction    % Correzione aggiuntiva rispetto al riferimento
ample.public_debt        % Debito detenuto dal pubblico, anni 0,...,H
ample.public_debt_reference % Debito del riferimento senza notizia
risultati.validation.public_debt.ample % Diagnostica della coda e trasversalita
```

Le variabili `inflation` e `output` interne sono deviazioni logaritmiche: la moltiplicazione per 100 corrisponde alla convenzione dei grafici Python. `tau_base` è il saldo senza notizia; `tau_report` quello dopo la notizia. `real_return(1)` è un valore convenzionale r come nel Python: la rivalutazione iniziale è gestita separatamente in `revaluation(1)`.

`terminal_old_share_increase` è l'aumento terminale della quota di anziani (moltiplicare per 100 per i punti percentuali). Il campo storico `initial_old_share`, mantenuto per equivalenza con Python, è calcolato da `tau` all'anno 1: il suo nome non va interpretato come quota all'anno 0.

## File prodotti

La versione principale salva in `output/principale/`; quella precedente in `output/levels/`.

| File | Contenuto |
|---|---|
| `results.mat` | Soluzione completa `result` e tabella `summary`, riapribili con doppio clic o `load` |
| `riepilogo.csv` | Tabella sintetica, apribile anche in Excel |
| `sentieri_riserve_ampie.csv` | Tutti gli anni 0,...,H per il primo scenario |
| `sentieri_esaurimento.csv` | Tutti gli anni 0,...,H per il secondo scenario |
| `ss_simulation.fig` | Figura MATLAB modificabile |
| `ss_simulation.png` | Immagine esportata |
| `note_simulazione.txt` | Parametri e risultati principali |
| `verifica_equazioni.csv` | Esito, residuo massimo e anno critico per ciascuna equazione e scenario |
| `residui_per_periodo.csv` | Tutti i residui, anno per anno, con scala, tolleranza ed esito |

Ogni nuova esecuzione sostituisce i risultati nella cartella della versione scelta. Per conservare un esperimento, copia quella cartella con un nome diverso prima di rieseguire. I materiali Python e la figura originale del documento restano invariati.

Le proiezioni senza interventi possono diventare negative nei dati: sono controfattuali di finanziamento. Nel grafico si fermano al primo zero, come negli script Python.

## Organizzazione del codice e metodo

Tutti i file `.m` sono commentati in italiano.

| File | Compito |
|---|---|
| `simulate_ss.m` | Avvia la versione principale e lascia i risultati nel Workspace |
| `simulate_ss_levels.m` | Avvia la versione precedente, per confronto |
| `parametri_ss.m` | Unico punto dove impostare i parametri comuni |
| `solve_ss_model.m` | Calcola riferimenti, sentiero NK, riserve, correzioni e radice fiscale |
| `plot_ss_results.m` | Disegna i quattro pannelli |
| `export_ss_results.m` | Salva dati, tabelle e figura |
| `verifica_replica.m` | Controlla la replica della calibrazione originale |
| `verify_ss_equations.m` | Verifica automaticamente tutte le equazioni implementate dopo ogni soluzione |
| `reconstruct_ss_public_debt.m` | Ricostruisce il debito pubblico all'indietro, con valore terminale economico |
| `ss_public_debt_tail.m` | Valuta analiticamente i surplus dopo H e certifica la prosecuzione del ramo fiscale |
| `test_verify_ss_equations.m` | Prova il verificatore anche su sentieri alterati deliberatamente |

Il risolutore segue questi passaggi:

1. Calcola la radice stabile NK e la sequenza della notizia.
2. Costruisce il riferimento senza notizia e calibra il surplus esterno.
3. Per un candidato di inflazione iniziale, calcola inflazione e output, rendimenti e rivalutazioni.
4. Proietta le riserve senza correzione e individua la prima violazione della soglia.
5. Calcola i target all'indietro e applica le correzioni in avanti.
6. Varia l'inflazione iniziale finché il residuo del vincolo intertemporale è zero.
7. Ricostruisce il debito detenuto dal pubblico e verifica anche bilanci, condizione iniziale e continuazione dopo H.

`fzero`, incluso in MATLAB base, svolge la ricerca scalare che in Python usa `brentq`. Le equazioni e la tolleranza sono le stesse; gli iterati intermedi possono differire. Si verificano comunque residuo fiscale, equazioni NK e positività delle riserve. La versione principale verifica anche che la data di intervento sia stabile vicino alla radice.

## Verifica automatica delle equazioni dopo ogni simulazione

Non serve avviare un comando aggiuntivo: **simulate_ss.m** e **simulate_ss_levels.m** eseguono la verifica anche quando cambi i parametri. Vengono controllati tutti e quattro i sentieri: riserve ampie ed esaurimento previsto, ciascuno con e senza notizia. Se un controllo fallisce, l'esecuzione si interrompe e mostra equazione, scenario e anno critico. La verifica viene ripetuta prima dell'esportazione per riconoscere anche eventuali modifiche manuali ai dati nel Workspace.

Il verificatore usa i risultati già calcolati e ricalcola direttamente i residui, senza risolvere nuovamente l'equilibrio o ricostruire i sentieri con la stessa funzione del solver. Per la coda usa la formula analitica di continuazione; una seconda ricorsione scontata in avanti controlla indipendentemente la compatibilità con il debito ereditato. Controlla:

- costanti derivate, radice NK, sconti, notizia e prosecuzione permanente;
- IS, Phillips, regola monetaria e sentiero stabile;
- rendimenti reali, sia dalla regola monetaria sia dall'IS, e rivalutazioni delle riserve;
- saldi a legislazione invariata, proiezioni senza interventi e bilanci delle riserve, inclusi quelli di riferimento;
- data della prima violazione, target backward, target terminale, prosecuzione del target, correzione a parte positiva, assenza di correzione prima dell'attivazione e positività;
- differenze rispetto al riferimento e identità telescopica del bilancio;
- surplus consolidati, variazioni dei surplus, fattore di sconto della famiglia, Euler al primo ordine e surplus scontati al primo ordine;
- calibrazione del surplus esterno, sua invarianza con/senza notizia e vincolo intertemporale fiscale;
- bilanci del debito detenuto dal pubblico in livelli e deviazioni, per ogni anno incluso 0, e debito ereditato;
- identità intertemporali finite a ogni orizzonte, conservando il debito terminale scontato;
- compatibilità del debito terminale con i surplus futuri, assenza della componente esplosiva e accuratezza del troncamento;
- valori attuali e metadati esportati.

Per IS e Phillips si controlla **anche l'ultimo anno H**, usando un punto H+1 della continuazione stabile. Questo punto è soltanto diagnostico: non modifica la somma fiscale troncata a H. Per i rendimenti tra due date il controllo parte dall'anno 1; la rivalutazione all'anno 0 ha una verifica separata. Target e correzioni rispettano le convenzioni specifiche delle due versioni, compresa la differenza nella ricerca della prima violazione.

La verifica è riferita al **sistema approssimato effettivamente implementato**. Il debito pubblico viene ora ricostruito esplicitamente; restano escluse le variabili microeconomiche eliminate dal sistema ridotto e le equazioni non lineari. La calibrazione del riferimento usa il fattore `1-beta`; il verificatore tiene conto del termine di coda corrispondente, senza cambiare questa convenzione originale. Il valore terminale scontato delle differenze delle riserve viene mantenuto nell'identità telescopica, non imposto nullo per tutti i regimi.

### Debito pubblico e condizione terminale

I quattro scenari contengono `public_debt_reference`, `public_debt_deviation`, `public_debt` e `discounted_public_debt`. Quest'ultimo mantiene solo il primo ordine: `beta^k*(b0 + db + qhat*b0)`, senza il prodotto quadratico `qhat*db`. I CSV dei sentieri includono queste quattro colonne.

La ricostruzione procede all'indietro perché l'accumulazione in avanti amplifica gli arrotondamenti come `r^H`. Il valore finale è il valore attuale dei surplus dopo H, **non zero**. Ogni bilancio viene poi controllato separatamente, incluso quello dell'anno 0 con il debito ereditato dall'anno -1 e la rivalutazione iniziale `Rhat0=-pi0`. Per k>=1 si usa `Rhat[k]=i[k-1]-pi[k]` e si moltiplica la variazione del rendimento per il debito **di riferimento**.

La continuazione analitica conserva saldi permanenti, prosecuzione geometrica NK e variazioni delle correzioni dovute ai rendimenti. Certifica, con condizioni sufficienti, che le riserve restino sul ramo libero o sul floor a tutte le date successive. La somma dei surplus scontati converge: il checker confronta il suo valore con il debito terminale. Inoltre ricostruisce in avanti il debito in unità scontate, a partire dal debito ereditato. La differenza tra questo valore e il valore fondamentale della coda misura la componente esplosiva incompatibile con la trasversalità; la tolleranza assoluta è `1e-9`.

La certificazione vale per questa continuazione deterministica al primo ordine. Se le condizioni sufficienti del ramo non valgono, il codice **non certifica** la continuazione e interrompe la simulazione; questo non dimostra l'inesistenza dell'equilibrio. Può occorrere aumentare H o studiare il successivo cambio di ramo. Se invece fallisce `accuratezza_troncamento_coda_debito`, H è insufficiente alla tolleranza richiesta: il limite della coda omessa deve essere <= `1e-9`. Non si impone `b[H]=0`, né si confonde una somma troncata con una prova di trasversalità.

Il rapporto `risultati.validation.public_debt.ample` (analogamente per gli altri scenari) mostra il termine terminale scontato, il valore della coda, la componente esplosiva e il limite di troncamento. I controlli entrano anche nei consueti CSV e interrompono automaticamente l'esecuzione se falliscono. Per vecchi file MAT senza i nuovi campi, rieseguire la simulazione.

### Leggere il rapporto

```matlab
verifica                          % Una riga per equazione/scenario
risultati.validation.passed        % true se tutti i controlli sono superati
risultati.validation.details       % Residui completi, anno per anno
```

La tabella contiene il massimo residuo assoluto e il suo anno, il massimo errore normalizzato e il suo anno, il numero di violazioni e le tolleranze. Un anno `NaN` identifica un controllo globale o un evento che non avviene; `NumeroControlli=0` segnala un vincolo condizionale non applicabile (per esempio la soglia dopo un'attivazione che non si verifica).

Il criterio di accettazione è:

```text
abs(residuo) <= tolleranza_assoluta + tolleranza_relativa * scala
```

Per IS, Phillips e regola monetaria la tolleranza assoluta è `1e-12`. Per il vincolo fiscale globale è `1e-9`. Nei bilanci si usa `1e-10 + 1e-12*scala`, dove la scala dipende dai termini dell'equazione: questo gestisce la precisione finita quando le riserve diventano molto grandi. Il CSV riporta anche i residui assoluti, quindi la normalizzazione non nasconde l'entità dell'errore in unità originali. Le condizioni logiche, come la data di intervento, non ammettono violazioni.

**ErroreNormalizzatoMax <= 1** significa che la tolleranza è rispettata in ogni periodo. Valori non finiti vengono segnalati come errori, non ignorati.

Per riesaminare un risultato salvato, o diagnosticare dati modificati senza interrompere il controllo al primo errore:

```matlab
controllo = verify_ss_equations(risultati, false);
controllo.summary(~controllo.summary.Superato, :)  % Solo controlli falliti
```

Il file MAT contiene il rapporto completo; `verifica_equazioni.csv` ne riporta il riepilogo e `residui_per_periodo.csv` tutte le osservazioni controllate. I file sono prodotti per la calibrazione effettivamente eseguita, non soltanto per quella originale.

La versione `levels` conserva le differenze del vecchio script: rendimento r nei target, contabilità in livelli con rivalutazione additiva, ricerca della violazione anche a data 0 (ma correzioni applicate da data 1). Non è una soluzione non lineare esatta. Conserva anche il vecchio campo `tau` di riferimento; per evitare ambiguità usare `tau_report` quando interessa il saldo dopo la notizia.

Per consentire esperimenti, l'asserzione specifica “inflazione nulla nel secondo scenario” è collocata nella verifica della calibrazione originale, invece di essere imposta a ogni possibile calibrazione. Il caso con shock nullo è gestito esplicitamente: la quota di copertura 0/0 è `NaN`.

Grandi variazioni possono cambiare il regime o portare la radice fuori dall'intervallo iniziale [-0.10,0.10]. In quel caso il codice segnala un errore invece di riportare una falsa soluzione; occorre esaminare la nuova calibrazione. Il nome del regime nei grafici identifica lo scenario di partenza, non impone il suo esito.

## Controllare la replica originale

Nella Command Window eseguire:

```matlab
verifica_replica
```

La verifica usa i parametri originali anche se hai modificato `parametri_ss.m`, confronta i risultati con il JSON Python già presente, controlla le identità economiche e salva un rapporto in `output/verifica_replica.json`.

Risultati attesi: inflazione iniziale 3.153881 punti percentuali e output 1.895681% nel caso ampio; risposte nulle nel caso esaurimento; correzione anticipata dall'anno 8 all'anno 7; costo attuale della notizia 3.016506.

Verifica del 23 settembre 2026: entrambi gli script eseguiti, grafici controllati, controlli economici superati. Lo scarto massimo nei dati confrontati con il JSON Python è circa `2.78e-15`. L'analisi del codice MATLAB non ha segnalato problemi.
