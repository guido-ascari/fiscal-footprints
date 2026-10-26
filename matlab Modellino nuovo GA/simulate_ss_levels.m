%% Fiscal footprints: versione precedente con conti in livelli
% Equivalente di simulate_ss_levels.py, conservato per confronto.
% Per il normale utilizzo partire da simulate_ss.m.
% Entrambe le versioni leggono la stessa calibrazione da parametri_ss.m.

cartella_matlab = fileparts(mfilename('fullpath'));
addpath(cartella_matlab);
p = parametri_ss();

risultati = solve_ss_model(p, 'levels');
verifica = risultati.validation.summary; % Controlli della versione in livelli
ample = risultati.ample;
poor = risultati.poor;
ample_base = risultati.ample_base;
poor_base = risultati.poor_base;
anni = risultati.time;

cartella_output = fullfile(cartella_matlab, 'output', 'levels');
[riepilogo, figura] = export_ss_results(risultati, cartella_output);
disp(riepilogo);
fprintf('\nRisultati salvati in: %s\n', cartella_output);
