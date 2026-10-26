# Fiscal footprints: note di studio e base per gli esperimenti

Studio del 23 settembre 2026. Letti il documento principale di 27 pagine, i due script Python, i frammenti LaTeX, i PDF di controllo, README, note e risultati salvati; esaminata la figura. Nessun parametro o file originale modificato.

## File e versioni

| File originale | Ruolo |
|---|---|
| `Fiscal_footprints.pdf` | Documento completo: modello, illustrazione, appendice A sul sentiero NK e appendice B sull'algoritmo. |
| `ss_simulation/simulate_ss.py` | Implementazione principale: contabilità delle riserve in deviazione dal riferimento, rendimenti attesi nei target, controllo locale della data di intervento. |
| `ss_simulation/simulate_ss_levels.py` | Versione precedente: ricorsione delle riserve in livelli con rivalutazione additiva; rendimento costante nei target; esporta anche la quota di copertura `lam`. Non è un risolutore esatto del modello non lineare. |
| `ss_simulation/results.json` | Parametri, statistiche e sentieri esportati per gli anni 0--25. Non contiene tutti gli 801 periodi usati internamente. |
| `ss_simulation/simulation_notes.md` | Riepilogo generato dallo script principale. |
| `ss_simulation/README.md` | Istruzioni; menziona un sorgente principale `social_security_demographic_model_final.tex` che non è presente. |
| `ss_simulation/simulation_explanation.tex` | Sezione numerica, leggermente più estesa della versione nel PDF principale. |
| `ss_simulation/implementation_appendix.tex` | Appendice numerica più aggiornata del PDF in alcuni passaggi. |
| `ss_simulation/implementation_appendix_final.tex` | Stessa appendice, con un paragrafo aggiuntivo sul controllo locale del ramo della soluzione. |
| `ss_simulation/check_*.tex`, `check_*.pdf` | Documenti autonomi di controllo; alcuni rimandi esterni compaiono come `??`. |
| `Figures/ss_simulation_permanent.png` e copia in `ss_simulation/` | Figure identiche, verificato anche tramite hash. Il documento usa quella in `Figures/`. |

## Logica economica

La famiglia rappresentativa comprende giovani e anziani e condivide tutte le risorse. I contributi e la correzione sono lump-sum. L'utilità dipende dal consumo aggregato e dalle ore per giovane, senza peso demografico nella disutilità. La produttività è `A_t = Abar/(1-omega_t)`. Queste ipotesi fanno cancellare la composizione demografica dalla produzione efficace e dal costo marginale: il canale studiato è quello dei conti previdenziali. Non è un modello OLG con risparmio separato delle generazioni.

Il saldo previdenziale a legislazione invariata è

\[
\tau_t=(1-\omega_t)\bar p^Y-\omega_t\bar v^O,
\qquad s_t^{OFF}=\tau_t+a_t.
\]

I titoli del fondo sono attività del fondo e passività interne al governo: si cancellano consolidando. Il debito rilevante per la valutazione della famiglia è quello detenuto dal pubblico, `B_ON`. Il surplus consolidato è `s_ON + tau + a`. Il surplus esterno `s_ON` è fissato all'interno di ciascun esperimento. La politica monetaria è passiva, con `0 <= phi < 1`.

La notizia arriva a data 0, cambia i saldi futuri da data 1 e non è seguita da altre sorprese. Nella calibrazione, `delta_tau[k] = -0.015*min(k,10)` per `k>=1`, con `delta_tau[0]=0`. Dopo `J=10` la revisione resta permanente: J non è la durata dello shock. I valori fiscali sono misurati in unità di PIL di riferimento, fissato a 100, non in rapporto al PIL endogeno contemporaneo.

Se le riserve prospettiche restano sopra la soglia, non sono attese correzioni: la notizia riduce il valore attuale dei surplus e induce inflazione. Se la regola è attiva e i sentieri con e senza notizia convergono alla stessa riserva terminale, la correzione aggiuntiva compensa il peggioramento previdenziale in valore attuale. Nella calibrazione questo lascia invariati inflazione e output. Si confronta sempre ciascuno scenario con il proprio riferimento senza notizia, non il passaggio da uno scenario all'altro.

## Regola delle riserve

1. Proiettare le riserve a legislazione invariata, senza correzioni discrezionali, tenendo conto dei rendimenti/rivalutazioni del sentiero candidato.
2. Individuare il primo `k>=1` con riserve strettamente inferiori alla soglia: `J_star`. La ricerca nel codice continua fino a H, anche oltre J.
3. Se non c'è violazione, la correzione è nulla. Altrimenti fissare `m[J]=LOWER` e ricostruire i target all'indietro fino alla data di intervento:

\[
m_k=\max\{\underline b,(m_{k+1}-\tau_{k+1})/R_{k+1}\}.
\]

4. Prima della data di intervento `a[k]=0`; da quella data, `a[k]=max(m[k]-b_pre[k],0)`. Le correzioni già effettuate entrano nella riserva precedente. Per `k>J`, il target è la soglia.

Il target può superare la soglia: all'attivazione c'è un salto delle riserve, seguito da discesa verso il minimo. Non si tratta di tagliare meccanicamente ogni osservazione alla soglia. La correzione è attesa fin dall'annuncio; non arriva come nuova sorpresa al momento del pagamento.

## Metodo di soluzione e corrispondenza con Python

**Riferimento.** `current_law_path`, `reserve_plan` e `reference` costruiscono i due sentieri senza notizie, con inflazione nulla. La correzione del caso di depletion è già presente nel riferimento. `calibrate_on_surplus` sceglie separatamente il surplus esterno costante per soddisfare la valutazione del debito:

\[
r=\beta^{-1},\quad V^0=r b_{-1}^{ON},\quad
s^{ON}=(1-\beta)\left[V^0-\sum_{k=0}^{H}\beta^k(\tau_k^0+a_k^0)\right].
\]

Il fattore `1-beta` approssima l'inverso della somma finita degli sconti; la differenza è trascurabile con H=800 e beta=0.96. `V0=62.5` include il rendimento sul debito iniziale di 60.

**Sentiero NK.** La radice stabile risolve

\[
\sigma(1-\rho)(1-\beta\rho)=\kappa(\rho-\phi),\quad
\kappa=\frac{(1-\theta)(1-\beta\theta)}{\theta}(\sigma+\nu).
\]

Per ogni candidato `pi0`, `simulate_given_pi` impone il sentiero limitato

\[
\pi_k=\rho^k\pi_0,\qquad y_k=c_y\pi_k,\qquad c_y=(1-\beta\rho)/\kappa.
\]

La dinamica geometrica viene dall'autovettore stabile; la sua ampiezza resta libera finché non si impone la valutazione fiscale. Per `k>=1`, il rendimento lordo anticipato è approssimato da `r*(1+sigma*(y[k]-y[k-1]))`.

**Rivalutazione e contabilità.** Il codice usa

\[
\mathcal R_0=-r b_{-1}^{OFF}\pi_0,\qquad
\mathcal R_k=r b_{k-1}^{OFF,0}\sigma(y_k-y_{k-1}),\quad k\geq1,
\]

\[
\Delta b_k^{OFF}=r\Delta b_{k-1}^{OFF}+\delta\tau_k+\mathcal R_k+(a_k-a_k^0).
\]

`uncorrected_projection` e `linearized_deviation_projection` producono la proiezione usata per decidere l'attivazione. La contabilità è al primo ordine, mentre la soglia discreta e gli operatori `max` restano espliciti. Il rapporto che definisce il target viene valutato direttamente sul rendimento approssimato: non è una soluzione globale esatta delle equazioni non lineari.

**Chiusura fiscale.** Dentro `solve`, il residuo è

\[
F(\pi_0)=V^0\pi_0+\sum_{k=0}^{H}\beta^k
\left[\delta\tau_k+a_k-a_k^0+s_k^0\sigma(y_0-y_k)\right].
\]

L'ultimo termine è la variazione del fattore di sconto della famiglia. Brent cerca uno zero nell'intervallo `[-0.10,0.10]`, ripetendo ogni volta l'intero calcolo delle riserve e della correzione. Lo script verifica il residuo fiscale, IS, Phillips, riserve positive e stabilità locale della data di intervento a `pi0 +/- 1e-6`. Questi controlli non sono una prova di unicità globale quando cambia il regime.

## Calibrazione verificata

Eseguiti entrambi gli script in copie isolate, senza sovrascrivere i risultati originali. Tutti i controlli interni sono passati. Tutti i campi numerici del nuovo `results.json` coincidono con quelli originali entro `1e-11`.

| Quantità | Riserve ampie | Esaurimento previsto |
|---|---:|---:|
| Saldo previdenziale di riferimento | 0.6 | -0.7 |
| Surplus esterno calibrato | 1.900000 | 2.941667 |
| Inflazione iniziale, punti percentuali | 3.153881 | circa 0 |
| Output iniziale, percentuale | 1.895681 | circa 0 |
| Costo della notizia in valore attuale, % PIL di riferimento | 3.016506 | 3.016506 |
| Correzione aggiuntiva in valore attuale | 0 | 3.016506 |
| Prima correzione con notizia | nessuna | anno 7 |
| Prima correzione senza notizia | nessuna | anno 8 |

Parametri comuni: `beta=.96`, `sigma=1`, `nu=1`, `theta=.6`, `phi=.5`, riserve iniziali 10.6, debito esterno 60, soglia 8, J=10, H=800. Risultano `kappa=.5653333333`, `rho=.6877074458`. Al primo intervento le riserve salgono da 7.748591 (senza correzione) a 9.386650, con correzione 1.638058. Da J raggiungono la soglia.

Controllo analitico indipendente: per una revisione annuale d=0.015 e prosecuzione permanente,

\[
D_\infty=d\,\frac{\beta(1-\beta^J)}{(1-\beta)^2}=3.016506276076487.
\]

Nel ramo senza correzione, il surplus di riferimento è costante a 2.5 e

\[
\pi_0=\frac{D_\infty}{V^0+2.5\sigma c_y\left[(1-\beta)^{-1}-(1-\beta\rho)^{-1}\right]},
\]

che riproduce 3.15388123948 punti percentuali. Il peso `beta**801` è circa `6.30e-15`. Nel ramo di depletion la compensazione segue dalla somma telescopica della differenza dei bilanci delle riserve: a inflazione nulla, il valore attuale di `delta_tau + delta_a` è `beta**H * delta_b[H] - r*delta_b[-1]`, nullo quando le riserve iniziali e terminali coincidono.

## Punti da ricordare prima di variare i parametri

- **Rendimento nei target:** l'equazione (94) del PDF usa r; l'equazione (19), `simulate_ss.py` e i frammenti LaTeX usano il rendimento atteso variabile. La versione `levels` usa r. La calibrazione di depletion ha inflazione nulla, perciò questa differenza non emerge nei risultati di riferimento.
- **Orizzonte J e dimensione dello shock:** aumentando J a `REVISION_PER_YEAR` costante si aumenta anche la revisione terminale. Per studiare soltanto il timing o l'orizzonte della regola occorre separare questi elementi.
- **Contributi e benefici:** `P_Y` e `V_O` servono attualmente a tradurre saldi esogeni in quote demografiche. Cambiarli da soli non modifica il sentiero di tau, né l'equilibrio macroeconomico, perché tau e la sua revisione sono calibrati direttamente.
- **Riferimenti:** modificare beta, saldi o regola induce una nuova calibrazione di `s_ON`. Un esercizio con surplus esterno comune e invariato tra tutte le calibrazioni sarebbe un esperimento diverso.
- **Cambi di regime:** il nome dello scenario non garantisce che il ramo resti quello iniziale. Lo script principale contiene anche `assert abs(poor['pi0']) < 1e-10`, specifico della calibrazione attuale. Per esperimenti generali andrà distinto dai controlli di validità dell'equilibrio.
- **Ricerca numerica:** la data del primo superamento può saltare; Brent presuppone continuità sull'intervallo pertinente. Residuo nullo e controllo locale del ramo sono essenziali. Per grandi variazioni servirà verificare intervalli, possibili radici multiple e ammissibilità, non soltanto accettare un cambio di segno.
- **Orizzonte H:** è diverso da J. Con beta più vicino a uno occorre rivalutare la coda e la calibrazione del riferimento. Riserve esplosive nel ramo di accumulo possono rendere delicate le operazioni su livelli molto grandi.
- **Data 0:** nel codice la correzione può iniziare solo da k=1. Parametri che portassero le riserve già sotto soglia alla data dell'annuncio richiedono una scelta esplicita sulla regola iniziale; il controllo attuale impone soltanto positività delle riserve.
- **Definizione della proiezione:** anche la proiezione senza correzione usa rivalutazioni calcolate sulle riserve effettive del riferimento (`reference_reserves`), che nel caso depletion includono correzioni. Per estensioni con inflazione non nulla e diversa attivazione, questa scelta va confrontata con la linearizzazione della proiezione esatta (17).
- **Metadati:** `initial_old_share` nello script principale è calcolata dal saldo post-notizia all'anno 1, non dalla quota iniziale senza notizia. Non va letta automaticamente come omega alla data 0.
- **Figure:** lo script salva la figura in `ss_simulation/`, mentre il documento incorpora la copia in `Figures/`. Dopo futuri esperimenti bisognerà aggiornare esplicitamente la figura pertinente o usare nomi distinti.

## Ricostruzione LaTeX

`Fiscal_footprints.tex` contiene il documento completo e modificabile; dipende soltanto dalla figura esistente in `Figures/`. Conserva titolo, sezioni, appendici A e B, note e numerazione delle equazioni (1)--(118). Non incorpora le pagine originali come immagini.

Il corpo e l'appendice A sono stati ricostruiti dal PDF; per la sezione numerica e l'appendice B sono stati riutilizzati i frammenti esistenti, adattandoli alla versione effettivamente stampata. Sono state mantenute le ripetizioni e le incongruenze del testo originale, incluso r nella (94), per non mescolare trascrizione e revisione del modello. Tra i punti editoriali già presenti: il richiamo alla ricerca della radice rho nel corpo, benché l'incognita dell'anello esterno sia pi0; l'affermazione di uguaglianza al target dopo la (20), dove la regola generale garantisce una disuguaglianza; uso di “current-law” associato a s_OFF anziché tau.

La compilazione produce `output/pdf/Fiscal_footprints_reconstructed.pdf` (26 pagine: l'impaginazione non è identica all'originale di 27). Controllati tutte le pagine renderizzate, rimandi risolti, equazione finale (118), assenza di avvisi di righe fuori margine. Il PDF originale resta invariato.

Per compilare dalla cartella principale, eseguire due volte:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error -jobname=Fiscal_footprints_reconstructed -output-directory=output/pdf Fiscal_footprints.tex
```

Il nome di output distinto evita di sovrascrivere `Fiscal_footprints.pdf`.
