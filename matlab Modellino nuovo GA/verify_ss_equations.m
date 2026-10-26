function report = verify_ss_equations(result, stop_on_failure)
% VERIFY_SS_EQUATIONS Verifica ex post delle equazioni effettivamente usate.
% report = verify_ss_equations(risultati)       interrompe se un controllo fallisce
% report = verify_ss_equations(risultati,false) restituisce anche gli errori
%
% Non richiama solve_ss_model, trial_path o reserve_plan: ricalcola i residui
% a partire dai sentieri salvati. Non risolve una seconda volta l'equilibrio.
% report.summary: una riga per equazione/scenario, massimi e anni critici.
% report.details: residui, scale e tolleranze di OGNI periodo controllato.
%
% Criterio: |residuo| <= atol + rtol*scala. Per i bilanci la scala e la somma
% dei valori assoluti dei termini, cosi livelli grandi non causano falsi errori.
% ErroreNormalizzatoMax <= 1 significa controllo superato. Per condizioni
% logiche si richiede esattamente zero violazioni (tolleranza nulla).
%
% Include debito verso il pubblico, bilanci a ogni data, identita finite e
% trasversalita sulla continuazione analitica del ramo fiscale dopo H.
% Se quel ramo non e certificabile, il controllo fallisce: aumentare H o
% studiare la continuazione. Non si verificano le equazioni non lineari.

if nargin<2, stop_on_failure=true; end
p=result.parameters;
H=p.H; t=(0:H)'; n=H+1;
assert(ismember(result.mode,{'linearized','levels'}),'SS:AuditMode','Versione sconosciuta.');
is_main=strcmp(result.mode,'linearized');
rows=struct('Scenario',{},'Equazione',{},'PeriodoIniziale',{},'PeriodoFinale',{}, ...
    'NumeroControlli',{},'ResiduoMaxAssoluto',{},'AnnoMaxAssoluto',{}, ...
    'ErroreNormalizzatoMax',{},'AnnoPeggiore',{},'NumeroViolazioni',{}, ...
    'TolleranzaAssoluta',{},'TolleranzaRelativa',{},'Superato',{});
details=struct('scenario',{},'equation',{},'year',{},'residual',{}, ...
    'scale',{},'tolerance',{},'normalized_error',{},'passed',{});

%% A. Parametri derivati, sequenza della notizia e convenzioni temporali
% Ricalcoliamo le costanti dai parametri primitivi, non dalle copie derivate.
rr=1/p.BETA;
kap=(1-p.THETA)*(1-p.BETA*p.THETA)*(p.SIGMA+p.NU)/p.THETA;
disc=p.BETA.^t;
news=-p.REVISION_PER_YEAR*min(t,p.J);
scenario='generale';
eq('griglia_temporale',result.time,t,t,0,0);
eq('fattori_sconto',result.discount,disc,t,1e-14,1e-12);
eq('news_e_continuazione_permanente',result.delta_tau,news,t,1e-12,1e-12);
eq('rendimento_r',result.r,rr,NaN,1e-12,0);
eq('pendenza_Phillips',result.kappa,kap,NaN,1e-12,0);
eq('radice_NK',p.SIGMA*(1-result.rho)*(1-p.BETA*result.rho), ...
    kap*(result.rho-p.PHI),NaN,1e-12,0);
condition('radice_stabile',result.rho>p.PHI && result.rho<1,NaN);
eq('coefficiente_output',(1-p.BETA*result.rho)/kap,result.y_coefficient,NaN,1e-12,0);
eq('valore_debito_iniziale',result.V0,rr*p.INITIAL_PUBLIC_DEBT,0,1e-10,1e-12);
eq('costo_attuale_news',result.present_value_cost,-sum(disc.*news),NaN,1e-10,1e-12);

%% B. Quattro scenari: due outlook, ciascuno con e senza la notizia
names={'ample','poor','ample_base','poor_base'};
base_balances=[p.AMPLE_TAU,p.DEPLETION_TAU,p.AMPLE_TAU,p.DEPLETION_TAU];
for j=1:numel(names)
    scenario=names{j}; x=result.(scenario);
    % Proteggiamo anche forma e dimensione: niente espansione implicita tra
    % vettori riga/colonna e nessun NaN/Inf nascosto nel calcolo dei massimi.
    fields={'inflation','output','nominal_rate_deviation','real_return', ...
        'revaluation','tau','tau_base','tau_report','reserves','correction', ...
        'target','no_adjustment','ref_reserves','ref_correction','ref_target', ...
        'ref_uncorrected','reference_surplus','extra_correction', ...
        'delta_surplus','consolidated_surplus','sdf','discounted_surplus', ...
        'public_debt_reference','public_debt_deviation','public_debt', ...
        'discounted_public_debt'};
    for f=1:numel(fields)
        v=x.(fields{f});
        assert(isnumeric(v) && isreal(v) && isequal(size(v),[n,1]), ...
            'SS:AuditShape','%s.%s deve essere un vettore colonna lungo H+1.',scenario,fields{f});
    end
    shock=double(j<=2)*news;
    tau0=base_balances(j)*ones(n,1);
    eq('saldo_current_law_riferimento',x.tau_base,tau0,t,1e-12,1e-12);
    eq('saldo_current_law_con_news',x.tau_report,tau0+shock,t,1e-12,1e-12);
    if is_main, stored_tau=x.tau_report; else, stored_tau=x.tau_base; end
    eq('campo_tau_esportato',x.tau,stored_tau,t,1e-12,1e-12);

    %% B1. NK: IS, Phillips e politica monetaria, compreso l'anno H
    % Il punto H+1 e la continuazione geometrica del modo stabile, non zero.
    next_pi=[x.inflation(2:end);x.continuation.inflation];
    next_y=[x.output(2:end);x.continuation.output];
    eq('inflazione_iniziale',x.inflation(1),x.pi0,0,1e-12,0);
    eq('modo_stabile_inflazione',next_pi,result.rho*x.inflation,t,1e-12,0);
    eq('modo_stabile_output',x.output,result.y_coefficient*x.inflation,t,1e-12,0);
    eq('continuazione_output_H1',x.continuation.output, ...
        result.y_coefficient*x.continuation.inflation,H+1,1e-12,0);
    eq('regola_monetaria',x.nominal_rate_deviation,p.PHI*x.inflation,t,1e-12,0);
    eq('IS',x.output,next_y-(x.nominal_rate_deviation-next_pi)/p.SIGMA,t,1e-12,0);
    eq('Phillips',x.inflation,p.BETA*next_pi+kap*x.output,t,1e-12,0);
    eq('rendimento_reale_da_tassi',x.real_return(2:end), ...
        rr*(1+x.nominal_rate_deviation(1:end-1)-x.inflation(2:end)),t(2:end),1e-12,1e-12);
    eq('rendimento_reale_da_IS',x.real_return(2:end), ...
        rr*(1+p.SIGMA*diff(x.output)),t(2:end),1e-12,1e-12);
    % Nel codice R(1) e un segnaposto r: lo shock di prezzo a data 0 entra
    % nella rivalutazione iniziale, non in questo elemento del vettore R.
    eq('convenzione_R0',x.real_return(1),rr,0,1e-12,0);
    condition('rendimenti_positivi',x.real_return(2:end)>0,t(2:end));
    eq('rivalutazione_iniziale',x.revaluation(1), ...
        -rr*p.INITIAL_RESERVES*x.pi0,0,1e-10,1e-12);
    eq('rivalutazione_successiva',x.revaluation(2:end), ...
        rr*x.ref_reserves(1:end-1).* ...
        (x.nominal_rate_deviation(1:end-1)-x.inflation(2:end)),t(2:end),1e-10,1e-12);

    %% B2. Riferimento senza news e proiezione non corretta
    ref_lag=[p.INITIAL_RESERVES;x.ref_reserves(1:end-1)];
    raw_lag=[p.INITIAL_RESERVES;x.ref_uncorrected(1:end-1)];
    eq('proiezione_riferimento_senza_interventi',x.ref_uncorrected, ...
        rr*raw_lag+x.tau_base,t,1e-10,1e-12);
    budget('bilancio_riserve_riferimento',x.ref_reserves, ...
        [rr*ref_lag,x.tau_base,x.ref_correction],t);
    first_year=double(is_main);
    ref_breach=find_breach(x.ref_uncorrected,first_year,p.LOWER);
    event('prima_violazione_riferimento',x.reference_breach,ref_breach);
    targets('target_riferimento',x.ref_target,x.tau_base,rr*ones(n,1),ref_breach);
    ref_pre=rr*ref_lag+x.tau_base;
    policy('correzione_riferimento',x.ref_correction,x.ref_target,ref_pre,ref_breach);
    condition('riserve_riferimento_positive',x.ref_reserves>0,t);

    %% B3. Contabilita dopo la notizia, incluse le condizioni iniziali
    lag=[p.INITIAL_RESERVES;x.reserves(1:end-1)];
    projection_lag=[p.INITIAL_RESERVES;x.no_adjustment(1:end-1)];
    budget('proiezione_senza_interventi',x.no_adjustment, ...
        [rr*projection_lag,x.tau_report,x.revaluation],t);
    budget('bilancio_riserve',x.reserves, ...
        [rr*lag,x.tau_report,x.revaluation,x.correction],t);
    eq('correzione_aggiuntiva',x.extra_correction,x.correction-x.ref_correction,t,1e-10,1e-12);
    % Per le deviazioni, la sottrazione di due riserve enormi perde cifre:
    % la scala include i livelli originari, non solo la loro differenza.
    db=x.reserves-x.ref_reserves;
    db_lag=[0;db(1:end-1)];
    terms=[db, -rr*db_lag, -shock, -x.revaluation, -x.extra_correction];
    record('bilancio_riserve_in_deviazione',sum(terms,2), ...
        sum(abs(terms),2)+abs(x.reserves)+abs(x.ref_reserves),t,1e-10,1e-12);
    breach=find_breach(x.no_adjustment,first_year,p.LOWER);
    event('prima_violazione_con_news',x.breach,breach);
    if is_main, target_returns=x.real_return; else, target_returns=rr*ones(n,1); end
    targets('target_con_news',x.target,x.tau_report,target_returns,breach);
    pre=rr*lag+x.tau_report+x.revaluation;
    policy('correzione_con_news',x.correction,x.target,pre,breach);
    % La soglia si applica dopo l'attivazione; non imponiamo vincoli aggiuntivi
    % alla data 0, in cui entrambe le implementazioni fissano a0=0.
    active=t>=max(1,breach);
    if isnan(breach), active=false(n,1); end
    record('soglia_dopo_attivazione',max(p.LOWER-x.reserves(active),0), ...
        abs(x.reserves(active))+p.LOWER,t(active),1e-10,1e-12);
    condition('riserve_positive',x.reserves>0,t);
    event('prima_correzione',x.first_correction,find_nonzero(x.correction));
    event('prima_correzione_riferimento',x.first_reference_correction,find_nonzero(x.ref_correction));

    %% B4. Surplus, fattore di sconto e valutazione fiscale al primo ordine
    % Non usiamo sdf.*surplus: quel prodotto reintrodurrebbe termini quadratici.
    s0=x.son+x.tau_base+x.ref_correction;
    ds=shock+x.correction-x.ref_correction;
    qhat=p.SIGMA*(x.output(1)-x.output);
    eq('surplus_riferimento',x.reference_surplus,s0,t,1e-10,1e-12);
    eq('revisione_surplus',x.delta_surplus,ds,t,1e-10,1e-12);
    eq('surplus_consolidato',x.consolidated_surplus,x.son+x.tau_report+x.correction,t,1e-10,1e-12);
    eq('surplus_consolidato_decomposizione',x.consolidated_surplus,s0+x.delta_surplus,t,1e-10,1e-12);
    eq('fattore_sconto_famiglia',x.sdf,disc.*(1+qhat),t,1e-12,1e-12);
    % Euler in log-deviazioni: qhat[k]-qhat[k-1]+Rhat[k]=0.
    % Dividere per beta^k evita che gli ultimi periodi spariscano nel controllo.
    qhat_saved=x.sdf./disc-1;
    record('Euler_SDF_primo_ordine',diff(qhat_saved)+x.real_return(2:end)/rr-1, ...
        ones(H,1),t(2:end),1e-12,0);
    eq('surplus_scontato_primo_ordine',x.discounted_surplus, ...
        disc.*(s0+ds+s0.*qhat),t,1e-10,1e-12);
    son_expected=(1-p.BETA)*(rr*p.INITIAL_PUBLIC_DEBT- ...
        sum(disc.*(x.tau_base+x.ref_correction)));
    eq('calibrazione_surplus_esterno',x.son,son_expected,NaN,1e-10,1e-12);
    % La calibrazione originale usa 1-beta invece dell'inverso della somma
    % FINITA degli sconti. Controlliamo l'identita con la sua coda esatta;
    % non trasformiamo questa piccola approssimazione in un nuovo vincolo.
    tail=x.son*p.BETA^(H+1)/(1-p.BETA);
    eq('valutazione_riferimento_con_coda_calibrazione', ...
        rr*p.INITIAL_PUBLIC_DEBT,sum(disc.*s0)+tail,NaN,1e-9,1e-12);
    fiscal=rr*p.INITIAL_PUBLIC_DEBT*x.pi0+sum(disc.*(ds+s0.*qhat));
    record('vincolo_intertemporale_fiscale',fiscal,1,NaN,1e-9,0);
    eq('residuo_fiscale_salvato',x.valuation_residual,fiscal,NaN,1e-12,0);
    eq('VA_correzione_aggiuntiva',x.pv_extra_correction, ...
        sum(disc.*(x.correction-x.ref_correction)),NaN,1e-10,1e-12);
    % Identita telescopica: il termine terminale NON si impone nullo.
    % Nel ramo ampio le riserve crescono, e beta^H*delta_b[H] puo non svanire.
    eq('identita_telescopica_riserve',sum(disc.*(shock+x.revaluation+x.extra_correction)), ...
        disc(end)*db(end),NaN,1e-9,1e-12);

    %% B5. Debito verso il pubblico: bilanci e trasversalita
    % La ricostruzione del solver procede all'indietro. Qui controlliamo
    % localmente OGNI bilancio, incluso il debito ereditato a data -1.
    % Rhat0=-pi0: NON usare real_return(1), che contiene il segnaposto r.
    b0=x.public_debt_reference; dbON=x.public_debt_deviation;
    lag0=[p.INITIAL_PUBLIC_DEBT;b0(1:end-1)];
    lagdb=[0;dbON(1:end-1)];
    Rhat=[-x.inflation(1);x.nominal_rate_deviation(1:end-1)-x.inflation(2:end)];
    budget('bilancio_debito_pubblico_riferimento',b0,[rr*lag0,-s0],t);
    budget('bilancio_debito_pubblico_deviazione',dbON, ...
        [rr*lagdb,rr*lag0.*Rhat,-ds],t);
    eq('debito_pubblico_decomposizione',x.public_debt,b0+dbON,t,1e-10,1e-12);
    budget('bilancio_debito_pubblico',x.public_debt, ...
        [rr*(lag0+lagdb),rr*lag0.*Rhat,-s0,-ds],t);
    eq('debito_pubblico_scontato',x.discounted_public_debt, ...
        disc.*(b0+dbON+b0.*qhat),t,1e-10,1e-12);
    % Identita FINITA per ciascun T=0,...,H. Il termine q_T*b_T rimane.
    V=rr*p.INITIAL_PUBLIC_DEBT;
    eq('identita_finita_debito_riferimento', ...
        cumsum(disc.*s0)+disc.*b0,V*ones(n,1),t,1e-9,1e-12);
    eq('identita_finita_debito_pubblico', ...
        cumsum(disc.*(s0+ds+s0.*qhat))+x.discounted_public_debt, ...
        V*(1-x.inflation(1))*ones(n,1),t,1e-9,1e-12);

    % Controllo della coda: dopo J i saldi current-law sono costanti.
    % Il surplus effettivo puo ancora variare, per rendimenti e correzioni.
    % La funzione analitica conserva questi termini geometrici e certifica
    % che il ramo (riserve libere/al floor) sia valido per TUTTE le date future.
    tail_debt=ss_public_debt_tail(x,p,result.rho);
    condition('continuazione_fiscale_riferimento_certificata',tail_debt.reference_supported,H);
    condition('continuazione_fiscale_certificata',tail_debt.actual_supported,H);
    condition('convergenza_coda_debito',tail_debt.supported,H);
    eq('debito_terminale_riferimento',b0(end),tail_debt.reference_debt,H,1e-10,1e-12);
    eq('debito_terminale_deviazione',dbON(end),tail_debt.debt_deviation,H,1e-10,1e-12);

    % Seconda ricostruzione IN AVANTI, indipendente dai sentieri salvati.
    % Calcoliamo beta^k*b[k] direttamente: cosi gli arrotondamenti non
    % vengono amplificati da r^H. Non usiamo questi numeri per i livelli.
    forward0=V-cumsum(disc.*s0);
    forward_delta=-V*x.inflation(1)+cumsum( ...
        [0;forward0(1:end-1).*Rhat(2:end)]-disc.*ds);
    fundamental0=disc(end)*tail_debt.reference_debt;
    fundamental_delta=disc(end)*(tail_debt.debt_deviation+ ...
        qhat(end)*tail_debt.reference_debt);
    bubble0=forward0(end)-fundamental0;
    bubble_delta=forward_delta(end)+qhat(end)*forward0(end)-fundamental_delta;
    % La differenza dal VA della coda e il coefficiente della componente
    % esplosiva. Va a zero, mentre il debito terminale in livelli puo restare
    % positivo. Tolleranza ASSOLUTA: un enorme debito non nasconde un errore.
    record('trasversalita_debito_riferimento',bubble0,1,H,1e-9,0);
    record('trasversalita_debito_deviazione',bubble_delta,1,H,1e-9,0);
    record('trasversalita_debito_pubblico',bubble0+bubble_delta,1,H,1e-9,0);
    % Il solver tronca la valutazione: richiediamo anche una coda piccola,
    % senza cancellazioni tra riferimento e deviazione, alle sue tolleranze.
    omitted=abs(fundamental0)+abs(fundamental_delta);
    record('accuratezza_troncamento_coda_debito',omitted,1,H,1e-9,0);
    report.public_debt.(scenario)=struct('tail',tail_debt, ...
        'discounted_terminal_debt',x.discounted_public_debt(end), ...
        'discounted_tail_surpluses',fundamental0+fundamental_delta, ...
        'explosive_component',bubble0+bubble_delta, ...
        'tail_truncation_bound',omitted);
    eq('quota_anziani_esportata',x.initial_old_share, ...
        (p.P_Y-x.tau(2))/(p.P_Y+p.V_O),1,1e-12,0);
    eq('revisione_demografica_terminale',x.terminal_old_share_increase, ...
        -news(p.J+1)/(p.P_Y+p.V_O),p.J,1e-12,0);
    if j<=2 && result.present_value_cost==0
        condition('quota_copertura_non_definita',isnan(x.lam),NaN);
    elseif j<=2
        eq('quota_copertura',x.lam,x.pv_extra_correction/result.present_value_cost,NaN,1e-10,1e-12);
    else
        eq('quota_copertura_riferimento',x.lam,0,NaN,0,0);
    end
end

%% C. Il surplus esterno e i riferimenti devono restare fissi con/senza news
for j=1:2
    scenario=names{j}; a=result.(names{j}); b=result.(names{j+2});
    eq('surplus_esterno_invariato',a.son,b.son,NaN,1e-12,0);
    eq('stesso_riferimento_riserve',a.ref_reserves,b.ref_reserves,t,1e-10,1e-12);
    eq('stesso_riferimento_correzione',a.ref_correction,b.ref_correction,t,1e-10,1e-12);
end
report.summary=struct2table(rows);
report.details=details;
report.passed=all(report.summary.Superato);
report.max_normalized_error=max(report.summary.ErroreNormalizzatoMax);
report.failed_checks=sum(~report.summary.Superato);
report.periods=H+1;
report.scope=['Equazioni implementate al primo ordine, k=0,...,H; NK a H ' ...
    'con continuazione stabile H+1. Debito pubblico, identita finite e ' ...
    'trasversalita condizionata alla continuazione fiscale certificata.'];
if ~report.passed && stop_on_failure
    disp(report.summary(~report.summary.Superato,:));
    error('SS:EquationVerification', ...
        ['Verifica ex post fallita: %d controlli. Le righe sopra indicano equazione e anno. ' ...
        'Usare verify_ss_equations(risultati,false) per ispezionare tutti i residui.'],report.failed_checks);
end

    function eq(id,lhs,rhs,years,atol,rtol)
        % Residuo algebrico in unita originali: lato sinistro meno destro.
        record(id,lhs-rhs,abs(lhs)+abs(rhs),years,atol,rtol);
    end

    function budget(id,lhs,terms,years)
        record(id,lhs-sum(terms,2),abs(lhs)+sum(abs(terms),2),years,1e-10,1e-12);
    end

    function condition(id,ok,years)
        record(id,double(~ok),zeros(size(ok)),years,0,0);
    end

    function event(id,actual,expected)
        % NaN = nessun evento entro H: confronto esplicito, non aritmetica NaN.
        condition(id,isequaln(actual,expected),expected);
    end

    function targets(id,m,tau,returns,breach_year)
        % Controllo locale della ricorsione, senza ricostruire il piano.
        % Fuori dalla ricorsione backward il codice assegna il floor.
        rhs=p.LOWER*ones(n,1);
        if ~isnan(breach_year)
            years=(breach_year:p.J-1)';
            ii=years+1;
            rhs(ii)=max(p.LOWER,(m(ii+1)-tau(ii+1))./returns(ii+1));
        end
        eq(id,m,rhs,t,1e-10,1e-12);
    end

    function policy(id,a,m,pre,breach_year)
        rhs=zeros(n,1);
        if ~isnan(breach_year)
            ii=t>=max(1,breach_year);
            rhs(ii)=max(m(ii)-pre(ii),0);
        end
        % La scala include le riserve pre-intervento: sottrarre livelli grandi
        % per ricostruire una piccola correzione ha precisione finita.
        record(id,a-rhs,abs(a)+abs(rhs)+abs(pre)+abs(m),t,1e-10,1e-12);
        condition([id '_nonnegativa'],a>=0,t);
    end

    function record(id,residual,scale,years,atol,rtol)
        residual=residual(:); scale=scale(:); years=years(:);
        assert(numel(residual)==numel(years) && numel(scale)==numel(years), ...
            'SS:AuditShape','Dimensioni incoerenti nel controllo %s.',id);
        tol=atol+rtol*scale;
        finite=isfinite(residual)&isfinite(scale)&isfinite(tol);
        passed=finite & abs(residual)<=tol;
        ratio=zeros(size(residual));
        positive=tol>0;
        ratio(positive)=abs(residual(positive))./tol(positive);
        ratio(~finite | (~positive & residual~=0))=Inf;
        if isempty(residual)
            % Un vincolo condizionale puo non essere applicabile: N=0.
            maxabs=0; maxratio=0; yearabs=NaN; yearworst=NaN;
            first=NaN; last=NaN;
        else
            magnitude=abs(residual); magnitude(~finite)=Inf;
            [maxabs,ia]=max(magnitude); [maxratio,ir]=max(ratio);
            yearabs=years(ia); yearworst=years(ir);
            first=years(1); last=years(end);
        end
        rows(end+1)=struct('Scenario',scenario,'Equazione',id, ...
            'PeriodoIniziale',first,'PeriodoFinale',last,'NumeroControlli',numel(residual), ...
            'ResiduoMaxAssoluto',maxabs,'AnnoMaxAssoluto',yearabs, ...
            'ErroreNormalizzatoMax',maxratio,'AnnoPeggiore',yearworst, ...
            'NumeroViolazioni',sum(~passed),'TolleranzaAssoluta',atol, ...
            'TolleranzaRelativa',rtol,'Superato',all(passed));
        details(end+1)=struct('scenario',scenario,'equation',id,'year',years, ...
            'residual',residual,'scale',scale,'tolerance',tol, ...
            'normalized_error',ratio,'passed',passed);
    end
end

function year=find_breach(b,first_year,lower)
i=find(b(first_year+1:end)<lower,1);
if isempty(i), year=NaN; else, year=i+first_year-1; end
end

function year=find_nonzero(a)
i=find(abs(a)>1e-9,1);
if isempty(i), year=NaN; else, year=i-1; end
end
