function test_verify_ss_equations()
% TEST_VERIFY_SS_EQUATIONS Verifica che il controllore riconosca errori veri.
% Oltre alle soluzioni valide, alteriamo apposta una variabile per volta.
% Questi errori NON vengono salvati nei risultati dell'utente.

here=fileparts(mfilename('fullpath'));
p=struct('BETA',.96,'SIGMA',1,'NU',1,'THETA',.6,'PHI',.5, ...
    'LOWER',8,'INITIAL_RESERVES',10.6,'INITIAL_PUBLIC_DEBT',60, ...
    'AMPLE_TAU',.6,'DEPLETION_TAU',-.7,'J',10, ...
    'REVISION_PER_YEAR',.015,'H',800,'SHOW',25,'P_Y',12,'V_O',24);
r=solve_ss_model(p,'linearized');
assert(r.validation.passed);
legacy=solve_ss_model(p,'levels');
assert(legacy.validation.passed);

%% Calibrazioni diverse: il verificatore non deve imporre i numeri originali
q=p; q.PHI=.3;
variant=solve_ss_model(q,'linearized'); assert(variant.validation.passed);
q=p; q.REVISION_PER_YEAR=0;
zero=solve_ss_model(q,'linearized'); assert(zero.validation.passed);
q=p; q.J=6;
shorter=solve_ss_model(q,'linearized'); assert(shorter.validation.passed);
q=p; q.PHI=.99;
persistent_case=solve_ss_model(q,'linearized'); assert(persistent_case.validation.passed);

%% Debito: confronto con una formula indipendente nel caso senza interventi
% Dopo J il surplus e costante. Il prezzo del debito conserva la risposta
% dei tassi reali: db non e semplicemente ds/(r-1) se y e ancora diverso da 0.
ii=(p.J:p.H)'+1; x=r.ample;
expected_db=-p.REVISION_PER_YEAR*p.J/(r.r-1) + ...
    p.SIGMA*x.output(ii)*2.5*(p.BETA/(1-p.BETA)- ...
    p.BETA*r.rho/(1-p.BETA*r.rho));
assert(max(abs(x.public_debt_reference-60))<1e-10);
assert(max(abs(x.public_debt_deviation(ii)-expected_db))<1e-10);
assert(abs(x.public_debt(end)-56.4)<1e-10); % NON deve essere zero

% Controllo indipendente delle formule di coda, con output non trascurabile.
% Sommiamo esplicitamente i surplus futuri, includendo la correzione variabile.
for floor_case=[false,true]
    z=r.ample; z.output(end)=.02;
    if floor_case
        z.ref_reserves(end)=p.LOWER; z.reserves(end)=p.LOWER;
        z.tau_base(end)=-.7; z.tau_report(end)=-.85;
        z.ref_correction(end)=(1-r.r)*p.LOWER+.7;
        z.correction(end)=(1-r.r)*p.LOWER+.85;
    else
        z.ref_reserves(end)=20; z.reserves(end)=20;
    end
    tt=ss_public_debt_tail(z,p,r.rho); assert(tt.supported);
    m=(1:2000)'; yf=z.output(end)*r.rho.^m;
    if floor_case
        Rhat=p.SIGMA*(r.rho-1)*z.output(end)*r.rho.^(m-1);
        a=(1-r.r)*p.LOWER-z.tau_report(end)-r.r*p.LOWER*Rhat;
    else
        a=zeros(size(m));
    end
    ds=z.tau_report(end)+a-z.tau_base(end)-z.ref_correction(end);
    expected=sum(p.BETA.^m.*(ds+tt.surplus_reference* ...
        p.SIGMA*(z.output(end)-yf)));
    assert(abs(tt.debt_deviation-expected)<1e-11);
end

%% Errori mirati in diversi blocchi, inclusa l'ultima data H
bad=r; bad.ample.output(4)=bad.ample.output(4)+.001;
must_fail(bad,'ample','IS',3);
bad=r; bad.poor.output(end)=.001;
must_fail(bad,'poor','Phillips',p.H);
bad=r; bad.ample.nominal_rate_deviation(3)=.02;
must_fail(bad,'ample','regola_monetaria',2);
bad=r; bad.ample.real_return(3)=bad.ample.real_return(3)+.01;
must_fail(bad,'ample','rendimento_reale_da_tassi',2);
bad=r; bad.ample.revaluation(2)=bad.ample.revaluation(2)+.01;
must_fail(bad,'ample','rivalutazione_successiva',1);
bad=r; bad.poor.reserves(8)=bad.poor.reserves(8)+.1;
must_fail(bad,'poor','bilancio_riserve',7);
bad=r; bad.poor.correction(3)=.1;
must_fail(bad,'poor','correzione_con_news',2);
bad=r; bad.poor.target(8)=bad.poor.target(8)+.1;
must_fail(bad,'poor','target_con_news',7);
bad=r; bad.poor.target(end)=9;
must_fail(bad,'poor','target_con_news',p.H);
bad=r; bad.poor.breach=8;
must_fail(bad,'poor','prima_violazione_con_news',7);
bad=r; bad.ample.no_adjustment(10)=bad.ample.no_adjustment(10)+1;
must_fail(bad,'ample','proiezione_senza_interventi',9);
bad=r; bad.poor_base.ref_correction(9)=bad.poor_base.ref_correction(9)+.1;
must_fail(bad,'poor_base','correzione_riferimento',8);
bad=r; bad.ample.sdf(5)=bad.ample.sdf(5)+.01;
must_fail(bad,'ample','fattore_sconto_famiglia',4);
bad=r; bad.poor.delta_surplus(5)=bad.poor.delta_surplus(5)+.01;
must_fail(bad,'poor','revisione_surplus',4);
bad=r; bad.ample.discounted_surplus(6)=bad.ample.discounted_surplus(6)+.01;
must_fail(bad,'ample','surplus_scontato_primo_ordine',5);
bad=r; bad.ample.son=bad.ample.son+.1;
must_fail(bad,'ample','calibrazione_surplus_esterno',NaN);
bad=r; bad.poor.pi0=.001;
must_fail(bad,'poor','vincolo_intertemporale_fiscale',NaN);
bad=r; bad.ample.inflation(4)=NaN;
must_fail(bad,'ample','Phillips',3);
bad=r; bad.poor.reserves(4)=Inf;
must_fail(bad,'poor','bilancio_riserve',3);
bad=r; bad.delta_tau(end)=0;
must_fail(bad,'generale','news_e_continuazione_permanente',p.H);

%% Errori nel debito, nella condizione iniziale e nella continuazione
bad=r; bad.ample.public_debt_deviation(4)=bad.ample.public_debt_deviation(4)+.1;
must_fail(bad,'ample','bilancio_debito_pubblico_deviazione',3);
bad=r; bad.ample.public_debt_reference(1)=bad.ample.public_debt_reference(1)+.1;
must_fail(bad,'ample','bilancio_debito_pubblico_riferimento',0);
bad=r; bad.poor.public_debt(end)=0;
must_fail(bad,'poor','bilancio_debito_pubblico',p.H);
bad=r; bad.ample.discounted_public_debt(10)=bad.ample.discounted_public_debt(10)+.1;
must_fail(bad,'ample','identita_finita_debito_pubblico',9);
bad=r; bad.ample.public_debt_deviation(end)=bad.ample.public_debt_deviation(end)+.1;
must_fail(bad,'ample','debito_terminale_deviazione',p.H);
bad=r; bad.ample.inflation(1)=bad.ample.inflation(1)+.001;
must_fail(bad,'ample','trasversalita_debito_pubblico',p.H);
bad=r; bad.ample.ref_reserves(end)=0;
must_fail(bad,'ample','continuazione_fiscale_riferimento_certificata',p.H);
bad=r; bad.ample.reserves(end)=0;
must_fail(bad,'ample','continuazione_fiscale_certificata',p.H);
bad=r; bad.poor.public_debt(end)=NaN;
must_fail(bad,'poor','bilancio_debito_pubblico',p.H);

% Componente esplosiva: soddisfa la ricorsione per k>=1, ma non l'eredita
% iniziale o la condizione terminale. Non deve passare per via della scala.
bad=r; explosive=.01*r.r.^(r.time+1);
bad.ample.public_debt_deviation=bad.ample.public_debt_deviation+explosive;
bad.ample.public_debt=bad.ample.public_debt+explosive;
bad.ample.discounted_public_debt=bad.ample.discounted_public_debt+r.discount.*explosive;
must_fail(bad,'ample','bilancio_debito_pubblico_deviazione',0);
must_fail(bad,'ample','debito_terminale_deviazione',p.H);

% Accorciamo una soluzione valida: il checker deve riconoscere che la coda
% omessa e troppo grande, anche senza imporre debito terminale nullo.
bad=r; h=40; bad.parameters.H=h; bad.time=bad.time(1:h+1);
bad.discount=bad.discount(1:h+1); bad.delta_tau=bad.delta_tau(1:h+1);
names={'ample','poor','ample_base','poor_base'};
for j=1:numel(names)
    z=bad.(names{j}); fields=fieldnames(z);
    for f=1:numel(fields)
        if isequal(size(z.(fields{f})),[p.H+1,1])
            z.(fields{f})=z.(fields{f})(1:h+1);
        end
    end
    z.continuation.inflation=z.pi0*r.rho^(h+1);
    z.continuation.output=r.y_coefficient*z.continuation.inflation;
    bad.(names{j})=z;
end
must_fail(bad,'ample','accuratezza_troncamento_coda_debito',h);

%% Lo stop automatico deve usare un identificatore di errore riconoscibile
bad=r; bad.poor.target(8)=bad.poor.target(8)+.1;
caught=false;
try
    verify_ss_equations(bad);
catch ex
    caught=strcmp(ex.identifier,'SS:EquationVerification');
end
assert(caught,'Il controllo deve interrompere la soluzione non valida.');

% Controllo dimensionale, distinto dal controllo numerico.
bad=r; bad.ample.output=bad.ample.output';
caught=false;
try
    verify_ss_equations(bad,false);
catch ex
    caught=strcmp(ex.identifier,'SS:AuditShape');
end
assert(caught,'Il controllo deve riconoscere un vettore di forma errata.');

report=struct('passed',true,'valid_parameter_sets',5,'implementations',2, ...
    'deliberate_numerical_errors_detected',31,'automatic_stop_test',true, ...
    'public_debt_analytic_test',true,'terminal_tail_direct_sum_test',true, ...
    'short_horizon_rejected',true, ...
    'shape_test',true,'matlab_version',version);
outdir=fullfile(here,'output');
if ~exist(outdir,'dir'), mkdir(outdir); end
fid=fopen(fullfile(outdir,'test_verifica_equazioni.json'),'w');
assert(fid~=-1); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
fprintf('Verificatore: calibrazioni valide e 31 errori deliberati controllati.\n');
end

function must_fail(r,scenario,equation,year)
report=verify_ss_equations(r,false);
assert(~report.passed,'Una soluzione alterata e stata accettata.');
for k=1:numel(report.details)
    d=report.details(k);
    if strcmp(d.scenario,scenario) && strcmp(d.equation,equation)
        if isnan(year), where=isnan(d.year); else, where=d.year==year; end
        assert(any(where) && any(~d.passed(where)), ...
            'Il residuo atteso non segnala errore: %s / %s / %g.',scenario,equation,year);
        return
    end
end
error('Controllo atteso non trovato: %s / %s.',scenario,equation);
end
