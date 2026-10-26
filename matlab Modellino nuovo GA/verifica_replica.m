function report = verifica_replica()
% VERIFICA_REPLICA Controlli numerici ripetibili, senza eseguire Python.
% Eseguire verifica_replica nella Command Window. Usa la calibrazione originale
% esplicita, per non confonderla con eventuali modifiche a parametri_ss.m.
% Controlla i dati Python salvati, le identita economiche e il caso senza shock.

here=fileparts(mfilename('fullpath'));
p=struct('BETA',.96,'SIGMA',1,'NU',1,'THETA',.6,'PHI',.5, ...
    'LOWER',8,'INITIAL_RESERVES',10.6,'INITIAL_PUBLIC_DEBT',60, ...
    'AMPLE_TAU',.6,'DEPLETION_TAU',-.7,'J',10, ...
    'REVISION_PER_YEAR',.015,'H',800,'SHOW',25,'P_Y',12,'V_O',24);
r=solve_ss_model(p,'linearized');
old=jsondecode(fileread(fullfile(here,'..','ss_simulation','results.json')));
xs={r.ample,r.poor};
max_error=0;
for j=1:2
    x=xs{j};
    s=old.scenarios(j);
    actual=[100*x.pi0,100*x.output(1),x.son,x.pv_extra_correction, ...
        x.initial_old_share,x.terminal_old_share_increase];
    expected=[s.impact_inflation_pp,s.impact_output_percent,s.outside_surplus, ...
        s.pv_extra_correction,s.initial_old_share,s.terminal_old_share_increase];
    max_error=max(max_error,max(abs(actual-expected)));
    assert(isequaln(x.first_correction,event_value(s.first_correction)));
    assert(isequaln(x.breach,event_value(s.first_breach)));
    assert(isequaln(x.reference_breach,event_value(s.first_reference_breach)));
    for k=0:p.SHOW
        i=k+1; d=s.plotted_data(i);
        actual=[100*x.inflation(i),100*x.output(i),x.reserves(i), ...
            x.ref_reserves(i),x.tau(i),x.correction(i), ...
            x.ref_correction(i),x.extra_correction(i)];
        expected=[d.inflation_pp,d.output_percent,d.reserves, ...
            d.reference_reserves,d.current_law_surplus,d.correction, ...
            d.reference_correction,d.additional_correction];
        max_error=max(max_error,max(abs(actual-expected)));
        if k<=p.J
            max_error=max(max_error,abs(x.target(i)-d.reserve_target));
        end
        if j==2
            max_error=max(max_error,abs(x.no_adjustment(i)-d.no_adjustment_reserves));
        end
    end
end
assert(max_error<1e-9,'SS:Replication','I risultati non coincidono con la base Python.');

%% Controllo indipendente: soluzione analitica nel ramo senza correzione
D=p.REVISION_PER_YEAR*p.BETA*(1-p.BETA^p.J)/(1-p.BETA)^2;
denominator=r.V0+2.5*p.SIGMA*r.y_coefficient* ...
    (1/(1-p.BETA)-1/(1-p.BETA*r.rho));
assert(abs(r.ample.pi0-D/denominator)<1e-12);
assert(abs(r.present_value_cost-D)<1e-12);
assert(abs(r.poor.pi0)<1e-10 && abs(r.poor.lam-1)<1e-9);
assert(r.poor.breach==7 && r.poor.reference_breach==8);
assert(abs(r.poor.reserves(8)-9.3866496)<1e-9);

%% Identita di bilancio e compensazione: controllo su tutti gli anni 0,...,H
for j=1:2
    x=xs{j};
    lag=[p.INITIAL_RESERVES;x.reserves(1:end-1)];
    accounting=x.reserves-r.r*lag-x.tau_report-x.revaluation-x.correction;
    % I livelli del caso ample crescono: il controllo usa una scala relativa.
    assert(max(abs(accounting)./max(1,abs(x.reserves)))<1e-12);
end
assert(abs(sum(r.discount.*(r.delta_tau+r.poor.extra_correction)))<1e-10);
assert(max(abs(r.poor.reserves(p.J+1:end)-p.LOWER))<1e-10);

%% Versione precedente: medesimi risultati macro nella calibrazione originale
legacy=solve_ss_model(p,'levels');
assert(abs(legacy.ample.pi0-r.ample.pi0)<1e-12);
assert(abs(legacy.poor.pi0)<1e-10 && abs(legacy.poor.lam-1)<1e-9);
assert(abs(legacy.ample.lam)<1e-10);
assert(max(abs(legacy.poor.reserves-r.poor.reserves))<1e-9);
% La differenza dei metadati tau della vecchia versione e preservata.
assert(all(legacy.ample.tau==p.AMPLE_TAU));
assert(max(abs(legacy.ample.tau_report-r.ample.tau_report))<1e-12);

%% Nessuna notizia: nessuna risposta rispetto al riferimento
zero=p; zero.REVISION_PER_YEAR=0;
rz=solve_ss_model(zero,'linearized');
assert(abs(rz.ample.pi0)<1e-12 && abs(rz.poor.pi0)<1e-12);
assert(max(abs(rz.poor.extra_correction))<1e-10);
assert(isnan(rz.poor.lam)); % Il rapporto 0/0 non ha significato economico.

report=struct('passed',true,'matlab_version',version, ...
    'max_absolute_error_vs_python',max_error, ...
    'ample_inflation_pp',100*r.ample.pi0,'poor_inflation_pp',100*r.poor.pi0, ...
    'ample_output_percent',100*r.ample.output(1), ...
    'present_value_cost',r.present_value_cost, ...
    'depletion_breach',r.poor.breach,'reference_depletion_breach',r.poor.reference_breach);
outdir=fullfile(here,'output');
if ~exist(outdir,'dir'), mkdir(outdir); end
fid=fopen(fullfile(outdir,'verifica_replica.json'),'w');
assert(fid~=-1,'SS:Output','Impossibile salvare la verifica.');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
disp(report);
fprintf('Replica e controlli economici superati.\n');
end

function y=event_value(x)
% null nel JSON Python diventa [] in MATLAB; qui equivale a nessun evento.
if isempty(x), y=NaN; else, y=x; end
end
