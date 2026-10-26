function result = solve_ss_model(p, mode)
% SOLVE_SS_MODEL Traduzione numerica dei due script Python originali.
% result = solve_ss_model(parametri_ss(), 'linearized')  versione principale
% result = solve_ss_model(parametri_ss(), 'levels')      versione precedente
% Nessun file scritto da questa funzione. Tutti i sentieri sono vettori colonna.
% Convenzione: periodo economico k -> indice MATLAB k+1; NaN = nessun evento.

if nargin < 1, p = parametri_ss(); end
if nargin < 2, mode = 'linearized'; end
mode = validatestring(mode, {'linearized', 'levels'});
validate_parameters(p);
%% 1. Costanti derivate e radice stabile del blocco New Keynesian
% La politica monetaria e passiva. Una radice e stabile, l'altra esplosiva.
% Escludiamo il modo esplosivo: pi[k]=rho^k*pi0 e y[k]=Y_COEF*pi[k].
% L'ampiezza pi0 verra determinata dal vincolo intertemporale fiscale.
c = p;
c.R = 1 / p.BETA;
c.KAPPA = (1-p.THETA)*(1-p.BETA*p.THETA)/p.THETA*(p.SIGMA+p.NU);
eigenvalues = roots([p.SIGMA*p.BETA, ...
    -p.SIGMA*(1+p.BETA)-c.KAPPA, p.SIGMA+c.KAPPA*p.PHI]);
assert(isreal(eigenvalues), 'SS:NKRoots', 'Le radici NK non sono reali.');
c.RHO = min(eigenvalues);
assert(p.PHI < c.RHO && c.RHO < 1 && max(eigenvalues) > 1, ...
    'SS:NKRoots', 'Occorre una radice stabile PHI < rho < 1.');
c.Y_COEF = (1-p.BETA*c.RHO)/c.KAPPA;
%% 2. Notizia anticipata e sconti: la revisione terminale persiste oltre J
% T contiene gli anni economici. DELTA_TAU(1)=0 perche a data 0 arriva
% l'informazione, ma il primo peggioramento del saldo avviene a data 1.
c.T = (0:p.H)';
c.DISCOUNT = p.BETA.^c.T;
c.DELTA_TAU = -p.REVISION_PER_YEAR*min(c.T,p.J);
c.D = -sum(c.DISCOUNT(2:end).*c.DELTA_TAU(2:end));
c.V0 = c.R*p.INITIAL_PUBLIC_DEBT;

%% 3. Quattro soluzioni: ciascun regime con e senza la medesima notizia
% Il surplus esterno viene calibrato separatamente per i due riferimenti,
% poi mantenuto fisso nel confronto con/senza notizia del medesimo regime.
tau_ample = repmat(p.AMPLE_TAU,p.H+1,1);
tau_poor = repmat(p.DEPLETION_TAU,p.H+1,1);
result.ample = solve_scenario('Ample reserves',tau_ample,true,c,mode);
result.poor = solve_scenario('Projected depletion',tau_poor,true,c,mode);
result.ample_base = solve_scenario('Ample reserves reference',tau_ample,false,c,mode);
result.poor_base = solve_scenario('Projected depletion reference',tau_poor,false,c,mode);
result.parameters = p;
result.mode = mode;
result.time = c.T;
result.discount = c.DISCOUNT;
result.delta_tau = c.DELTA_TAU;
result.present_value_cost = c.D;
result.r = c.R;
result.kappa = c.KAPPA;
result.rho = c.RHO;
result.y_coefficient = c.Y_COEF;
result.V0 = c.V0;

%% 4. Verifica ex post indipendente di tutte le equazioni implementate
% Il verificatore usa i sentieri gia calcolati, senza richiamare il risolutore.
% Controlla anche i riferimenti senza notizia; un errore interrompe l'esecuzione.
result.validation = verify_ss_equations(result);

% Le asserzioni specifiche dello scenario originale sono nel test di replica.
% Qui si controllano le equazioni, senza imporre inflazione nulla per ogni
% possibile calibrazione scelta dall'utente.
end

function validate_parameters(p)
names = fieldnames(parametri_ss());
for j=1:numel(names)
    assert(isfield(p,names{j}), 'SS:Parameter', 'Parametro mancante: %s',names{j});
    validateattributes(p.(names{j}),{'numeric'},{'real','finite','scalar'}, ...
        mfilename,names{j});
end
assert(p.BETA>0 && p.BETA<1 && p.THETA>0 && p.THETA<1, ...
    'SS:Parameter','BETA e THETA devono essere tra 0 e 1.');
assert(p.SIGMA>0 && p.NU>=0 && p.PHI>=0 && p.PHI<1, ...
    'SS:Parameter','Occorrono SIGMA>0, NU>=0 e 0<=PHI<1.');
assert(p.LOWER>0 && p.INITIAL_RESERVES>0 && p.INITIAL_PUBLIC_DEBT>0, ...
    'SS:Parameter','Soglia, riserve iniziali e debito devono essere positivi.');
assert(p.P_Y>0 && p.V_O>0,'SS:Parameter','P_Y e V_O devono essere positivi.');
assert(p.J>=1 && p.J==fix(p.J) && p.H>=p.J && p.H==fix(p.H), ...
    'SS:Parameter','J e H devono essere interi con 1<=J<=H.');
assert(p.SHOW>=1 && p.SHOW==fix(p.SHOW) && p.SHOW<=p.H, ...
    'SS:Parameter','SHOW deve essere intero con 1<=SHOW<=H.');
end

function x = solve_scenario(name,tau,adverse,c,mode)
% PASSO 0: riferimento senza news, con inflazione e output gap nulli.
% ref include gia le correzioni previste prima della nuova informazione.
ref = reserve_plan(tau,zeros(c.H+1,1),c,mode);
son = (1-c.BETA)*(c.V0-sum(c.DISCOUNT.*(tau+ref.correction)));
reference_surplus = son+tau+ref.correction;
news = double(adverse)*c.DELTA_TAU;
report_tau = tau+news;
% ANELLO ESTERNO: per ogni pi0 si ricalcola l'intero anello interno.
% La radice richiede uguaglianza tra rivalutazione del debito ereditato
% e cambiamento del valore attuale dei surplus consolidati.
fun = @(pi0) valuation(pi0,tau,report_tau,news,ref,reference_surplus,c,mode);
% fzero e una ricerca scalare per intervallo; non richiede Optimization Toolbox.
options = optimset('TolX',5e-15,'Display','off');
[pi0,fval,exitflag] = fzero(fun,[-0.10,0.10],options);
assert(exitflag>0 && isfinite(fval) && abs(fval)<1e-9, ...
    'SS:Root','Nessuna radice valida: controllare intervallo e cambi di regime.');
x = trial_path(pi0,tau,report_tau,ref,c,mode);
% Conserviamo sia i risultati con news sia il riferimento: questo permette
% di leggere subito quanto della risposta proviene dalla nuova correzione.
x.name = name;
x.pi0 = pi0;
x.son = son;
x.tau_base = tau;
x.tau_report = report_tau;
if strcmp(mode,'levels')
    % Il vecchio Python esporta tau di riferimento anche dopo la notizia.
    x.tau = tau;
else
    x.tau = report_tau;
end
% Metadati demografici equivalenti ai JSON Python. Attenzione: il nome
% storico initial_old_share usa tau all'ANNO 1, non all'anno 0.
x.initial_old_share = (c.P_Y-x.tau(2))/(c.P_Y+c.V_O);
x.terminal_old_share_increase = -c.DELTA_TAU(c.J+1)/(c.P_Y+c.V_O);
x.ref_reserves = ref.reserves;
x.ref_correction = ref.correction;
x.ref_target = ref.target;
x.ref_uncorrected = ref.uncorrected;
x.reference_breach = ref.breach;
x.reference_surplus = reference_surplus;
x.extra_correction = x.correction-ref.correction;
x.first_correction = first_event(abs(x.correction)>1e-9,0);
x.first_reference_correction = first_event(abs(ref.correction)>1e-9,0);
x.valuation_residual = fun(pi0);
x.pv_extra_correction = sum(c.DISCOUNT.*x.extra_correction);
% Quantita derivate esplicite, utili per leggere e verificare la soluzione.
% Nel prodotto q*s manteniamo soltanto i termini del primo ordine.
x.delta_surplus = news+x.extra_correction;
x.consolidated_surplus = x.son+x.tau_report+x.correction;
x.sdf = c.DISCOUNT.*(1+c.SIGMA*(x.output(1)-x.output));
x.discounted_surplus = c.DISCOUNT.*(reference_surplus+x.delta_surplus + ...
    reference_surplus*c.SIGMA.*(x.output(1)-x.output));
% Debito esterno: ricostruzione stabile all'indietro, senza modificare pi0.
% La verifica indipendente controllera bilanci, debito ereditato e coda.
x = reconstruct_ss_public_debt(x,c,c.RHO);
if adverse && c.D~=0
    x.lam = x.pv_extra_correction/c.D;
elseif ~adverse
    x.lam = 0;
else
    x.lam = NaN; % Quota non definita quando il costo della notizia e zero.
end
assert(all(isfinite(x.reserves)) && min(x.reserves)>0, ...
    'SS:Reserves','Riserve non positive o non finite nella soluzione.');
if strcmp(mode,'linearized')
    % La data di intervento e discreta: il residuo puo avere salti.
    % Verifichiamo che la radice non sia semplicemente un cambio di ramo.
    for near_pi=[pi0-1e-6,pi0+1e-6]
        near = trial_path(near_pi,tau,report_tau,ref,c,mode);
        assert(isequaln(near.breach,x.breach),'SS:Branch', ...
            'La data di intervento cambia vicino alla radice trovata.');
    end
end
nk_is = x.output(1:end-1)-x.output(2:end) + ...
    (c.PHI*x.inflation(1:end-1)-x.inflation(2:end))/c.SIGMA;
nk_pc = x.inflation(1:end-1)-c.BETA*x.inflation(2:end)-c.KAPPA*x.output(1:end-1);
x.max_nk_residual = max([abs(nk_is);abs(nk_pc)]);
assert(x.max_nk_residual<1e-12,'SS:NKResidual','Equazioni NK non soddisfatte.');
end

function F = valuation(pi0,tau,report_tau,news,ref,reference_surplus,c,mode)
% Delta surplus = peggioramento current-law + correzione aggiuntiva.
% Il termine con y(1)-y(k) e la variazione del fattore di sconto della famiglia.
% V0*pi0 porta al primo membro la perdita reale sul debito nominale ereditato.
x = trial_path(pi0,tau,report_tau,ref,c,mode);
change = news+x.correction-ref.correction;
F = c.V0*pi0+sum(c.DISCOUNT.*(change + ...
    reference_surplus*c.SIGMA.*(x.output(1)-x.output)));
end

function x = trial_path(pi0,tau,report_tau,ref,c,mode)
% ANELLO INTERNO, PASSO 1: inflazione/output condizionati al candidato pi0.
x.inflation = pi0*c.RHO.^c.T;
x.output = c.Y_COEF*x.inflation;
x.nominal_rate_deviation = c.PHI*x.inflation;
% Un punto di continuazione serve a controllare IS e Phillips anche a k=H.
% Non entra nelle somme fiscali, che restano troncate all'anno H.
x.continuation.inflation = pi0*c.RHO^(c.H+1);
x.continuation.output = c.Y_COEF*x.continuation.inflation;
% R(1)=r e mantenuto come nello script principale; la rivalutazione a k=0
% viene trattata separatamente. R(2:end) sono i rendimenti attesi da k=1.
x.real_return = c.R*ones(c.H+1,1);
x.real_return(2:end) = c.R*(1+c.SIGMA*diff(x.output));
if strcmp(mode,'linearized')
    assert(all(x.real_return(2:end)>0),'SS:Return','Rendimento atteso non positivo.');
end
x.revaluation = zeros(c.H+1,1);
% PASSO 2: l'inflazione iniziale svaluta le riserve nominali ereditate.
% In seguito conta lo scarto del rendimento reale dal rendimento di riferimento.
% Moltiplichiamo per le riserve del riferimento, come richiede il primo ordine.
x.revaluation(1) = -c.R*c.INITIAL_RESERVES*pi0;
x.revaluation(2:end) = c.R*ref.reserves(1:end-1)*c.SIGMA.*diff(x.output);

if strcmp(mode,'levels')
    plan = reserve_plan(report_tau,x.revaluation,c,mode);
    x.reserves = plan.reserves;
    x.correction = plan.correction;
    x.target = plan.target;
    x.breach = plan.breach;
    x.no_adjustment = plan.uncorrected;
    return
end

news = report_tau-tau;
% PASSO 3: proiezione SENZA interventi per trovare la data di attivazione.
% Partiamo dalla proiezione non corretta del riferimento e vi aggiungiamo
% la deviazione dovuta a notizia e rivalutazioni, senza delta correzioni.
delta_no_adjustment = propagate(news+x.revaluation,0,c.R);
x.no_adjustment = ref.uncorrected+delta_no_adjustment;
x.breach = first_event(x.no_adjustment<c.LOWER,1);
x.target = c.LOWER*ones(c.H+1,1);
% PASSO 4: m[J]=soglia; ricorsione all'indietro fino alla prima violazione.
% Un target sopra la soglia finanzia i deficit successivi: da qui il salto
% delle riserve all'attivazione, seguito dalla discesa verso il minimo.
if ~isnan(x.breach)
    for k=c.J-1:-1:x.breach
        x.target(k+1) = max(c.LOWER, ...
            (x.target(k+2)-report_tau(k+2))/x.real_return(k+2));
    end
end
delta_reserves = zeros(c.H+1,1);
% PASSO 5: simulazione in avanti con le correzioni effettive.
% Il riferimento soddisfa gia il proprio bilancio. Aggiorniamo soltanto
% la deviazione e sommiamola al riferimento per ottenere le riserve in livelli.
x.correction = zeros(c.H+1,1);
x.reserves = zeros(c.H+1,1);
delta_reserves(1) = delta_no_adjustment(1);
x.reserves(1) = ref.reserves(1)+delta_reserves(1);
for k=1:c.H
    i=k+1;
    pre = c.R*(ref.reserves(i-1)+delta_reserves(i-1))+report_tau(i)+x.revaluation(i);
    if ~isnan(x.breach) && k>=x.breach
        x.correction(i) = max(x.target(i)-pre,0);
    end
    delta_correction = x.correction(i)-ref.correction(i);
    delta_reserves(i) = c.R*delta_reserves(i-1)+news(i)+x.revaluation(i)+delta_correction;
    x.reserves(i) = ref.reserves(i)+delta_reserves(i);
end
end

function plan = reserve_plan(tau,revaluation,c,mode)
% Piano a rendimento costante: usato per il riferimento in entrambe le
% versioni e per l'anello interno della versione storica 'levels'.
% Nella versione principale i target post-news usano invece R[k+1].
flow = tau+revaluation;
plan.uncorrected = propagate(flow,c.INITIAL_RESERVES,c.R);
if strcmp(mode,'levels')
    % Nel vecchio script la ricerca include k=0, ma la correzione parte da k=1.
    first_year=0;
else
    first_year=1;
end
plan.breach = first_event(plan.uncorrected<c.LOWER,first_year);
plan.target = c.LOWER*ones(c.H+1,1);
if ~isnan(plan.breach)
    for k=c.J-1:-1:plan.breach
        plan.target(k+1)=max(c.LOWER,(plan.target(k+2)-tau(k+2))/c.R);
    end
end
plan.correction=zeros(c.H+1,1);
plan.reserves=zeros(c.H+1,1);
plan.reserves(1)=plan.uncorrected(1);
for k=1:c.H
    i=k+1;
    pre=c.R*plan.reserves(i-1)+flow(i);
    if ~isnan(plan.breach) && k>=plan.breach
        plan.correction(i)=max(plan.target(i)-pre,0);
    end
    plan.reserves(i)=pre+plan.correction(i);
end
end

function path = propagate(flow,initial,r)
% Ricorsione di bilancio senza correzione: b[k]=r*b[k-1]+flusso[k].
% initial e lo stock all'anno -1, non la prima osservazione all'anno 0.
path=zeros(size(flow));
path(1)=r*initial+flow(1);
for i=2:numel(flow)
    path(i)=r*path(i-1)+flow(i);
end
end

function year = first_event(mask,first_year)
% Converte la posizione MATLAB del primo evento nell'anno del modello.
% NaN rende esplicito che l'evento non avviene entro l'orizzonte numerico H.
i=find(mask(first_year+1:end),1,'first');
if isempty(i), year=NaN; else, year=i+first_year-1; end
end
