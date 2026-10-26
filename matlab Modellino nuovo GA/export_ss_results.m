function [summary, fig] = export_ss_results(result, outdir)
% EXPORT_SS_RESULTS Mostra la figura e salva risultati leggibili da MATLAB.
% La soluzione economica e gia stata calcolata da solve_ss_model.
% Questa funzione si occupa soltanto di tabelle, file e grafici.
% Ogni versione salva in una cartella propria, senza toccare i file Python.

if ~exist(outdir,'dir'), mkdir(outdir); end
% Ripetiamo la verifica sui dati ricevuti: evita di esportare un rapporto
% obsoleto se l'utente ha modificato manualmente un sentiero nel Workspace.
result.validation=verify_ss_equations(result,false);
verification=result.validation.summary;
writetable(verification,fullfile(outdir,'verifica_equazioni.csv'));
% Conserviamo anche ogni singolo residuo, non soltanto il massimo.
parts=cell(numel(result.validation.details),1);
for k=1:numel(parts)
    z=result.validation.details(k); count=numel(z.year);
    parts{k}=table(repmat({z.scenario},count,1),repmat({z.equation},count,1), ...
        z.year,z.residual,z.scale,z.tolerance,z.normalized_error,z.passed, ...
        'VariableNames',{'Scenario','Equazione','Anno','Residuo','Scala', ...
        'Tolleranza','ErroreNormalizzato','Superato'});
end
writetable(vertcat(parts{:}),fullfile(outdir,'residui_per_periodo.csv'));
if ~result.validation.passed
    disp(verification(~verification.Superato,:));
    error('SS:EquationVerification', ...
        'Equazioni non soddisfatte. Rapporti diagnostici salvati in %s.',outdir);
end
fprintf('Verifica ex post: %d controlli superati su %d periodi e quattro scenari.\n', ...
    height(verification),result.validation.periods);
p=result.parameters;
a=result.ample;
d=result.poor;

%% 1. Tabella sintetica: i due scenari, ciascuno rispetto al suo riferimento
% Inflazione in punti percentuali; output in percentuale; grandezze fiscali
% in percentuale del PIL DI RIFERIMENTO, mantenuto fisso a 100.
Scenario={'Riserve ampie';'Esaurimento previsto'};
Inflazione_impatto_pp=100*[a.pi0;d.pi0];
Output_impatto_percento=100*[a.output(1);d.output(1)];
Costo_news_VA=repmat(result.present_value_cost,2,1);
Correzione_aggiuntiva_VA=[a.pv_extra_correction;d.pv_extra_correction];
Primo_intervento_anno=[a.first_correction;d.first_correction];
Intervento_senza_news_anno=[a.first_reference_correction;d.first_reference_correction];
Surplus_esterno=[a.son;d.son];
Residuo_fiscale=[a.valuation_residual;d.valuation_residual];
summary=table(Scenario,Inflazione_impatto_pp,Output_impatto_percento, ...
    Costo_news_VA,Correzione_aggiuntiva_VA,Primo_intervento_anno, ...
    Intervento_senza_news_anno,Surplus_esterno,Residuo_fiscale);
writetable(summary,fullfile(outdir,'riepilogo.csv'));

%% 2. File MAT: contiene tutti i sentieri, dall'anno 0 all'anno H
% load('results.mat') permette di riprendere la simulazione senza ricalcolarla.
save(fullfile(outdir,'results.mat'),'result','summary','verification');

%% 3. Tabelle dei sentieri: una riga per anno, senza la riserva iniziale a -1
% tau_report e sempre il saldo effettivamente usato dopo la notizia.
% Nel vecchio Python il campo tau esportato era invece quello del riferimento:
% nel MAT conserviamo entrambi i campi; nei CSV li distinguiamo esplicitamente.
scenarios={a,d};
filenames={'sentieri_riserve_ampie.csv','sentieri_esaurimento.csv'};
for j=1:2
    x=scenarios{j};
    paths=table(result.time,100*x.inflation,100*x.output,x.reserves, ...
        x.ref_reserves,x.no_adjustment,x.target,x.tau_base,x.tau_report, ...
        x.correction,x.ref_correction,x.extra_correction,x.revaluation, ...
        x.public_debt_reference,x.public_debt_deviation,x.public_debt, ...
        x.discounted_public_debt, ...
        'VariableNames',{'Anno','Inflazione_pp','Output_percento','Riserve', ...
        'Riserve_senza_news','Riserve_senza_interventi','Target_riserve', ...
        'Saldo_senza_news','Saldo_con_news','Correzione','Correzione_senza_news', ...
        'Correzione_aggiuntiva','Rivalutazione','Debito_pubblico_senza_news', ...
        'Debito_pubblico_deviazione','Debito_pubblico','Debito_pubblico_scontato'});
    writetable(paths,fullfile(outdir,filenames{j}));
end

%% 4. Figura a quattro pannelli, equivalente alla figura degli script Python
fig=plot_ss_results(result);
savefig(fig,fullfile(outdir,'ss_simulation.fig')); % Figura modificabile in MATLAB
exportgraphics(fig,fullfile(outdir,'ss_simulation.png'),'Resolution',160);

%% 5. Breve riepilogo testuale, leggibile anche fuori da MATLAB
fid=fopen(fullfile(outdir,'note_simulazione.txt'),'w');
assert(fid~=-1,'SS:Output','Impossibile scrivere le note.');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'Fiscal footprints - versione %s\n\n',result.mode);
fprintf(fid,'Verifica ex post: SUPERATA (%d righe di controllo).\n',height(verification));
fprintf(fid,'Massimo errore normalizzato: %.6g (deve essere <= 1).\n', ...
    result.validation.max_normalized_error);
fprintf(fid,'Vedere verifica_equazioni.csv e residui_per_periodo.csv.\n\n');
fprintf(fid,'Un periodo = un anno; PIL di riferimento = 100.\n');
fprintf(fid,'J = %d; H = %d; revisione terminale permanente = %.8g.\n', ...
    p.J,p.H,-p.REVISION_PER_YEAR*p.J);
fprintf(fid,'beta=%.6g, sigma=%.6g, nu=%.6g, theta=%.6g, phi=%.6g\n', ...
    p.BETA,p.SIGMA,p.NU,p.THETA,p.PHI);
fprintf(fid,'kappa=%.12g; rho=%.12g; costo news VA=%.12g\n\n', ...
    result.kappa,result.rho,result.present_value_cost);
for j=1:2
    x=scenarios{j};
    fprintf(fid,'%s\n',Scenario{j});
    fprintf(fid,'  Inflazione iniziale: %.10f punti percentuali\n',100*x.pi0);
    fprintf(fid,'  Output iniziale: %.10f percento\n',100*x.output(1));
    fprintf(fid,'  VA correzione aggiuntiva: %.12g\n',x.pv_extra_correction);
    fprintf(fid,'  Primo intervento: %g (NaN significa nessun intervento)\n',x.first_correction);
    fprintf(fid,'  Residuo del vincolo fiscale: %.4g\n\n',x.valuation_residual);
    keys={'ample','poor'}; debt=result.validation.public_debt.(keys{j});
    fprintf(fid,'  Debito pubblico terminale: %.12g\n',x.public_debt(end));
    fprintf(fid,'  Debito terminale scontato: %.4g\n',debt.discounted_terminal_debt);
    fprintf(fid,'  Componente esplosiva scontata: %.4g\n',debt.explosive_component);
    fprintf(fid,'  Limite della coda omessa: %.4g (tolleranza 1e-9)\n\n',debt.tail_truncation_bound);
end
fprintf(fid,['Le risposte sono rispetto al riferimento senza news di ciascuno scenario.\n' ...
    'I CSV contengono tutti gli anni 0,...,H; la figura mostra solo 0,...,SHOW.\n' ...
    'Le proiezioni senza intervento nei CSV possono diventare negative: sono\n' ...
    'controfattuali contabili, troncati al primo zero soltanto nel grafico.\n']);
end
