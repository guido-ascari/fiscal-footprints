%% Fiscal footprints: versione principale
% Aprire questo file in MATLAB e premere Run.
% Per cambiare la calibrazione, modificare parametri_ss.m e rieseguire.
% Non occorrono Python o toolbox aggiuntivi.

cartella_matlab = fileparts(mfilename('fullpath'));
addpath(cartella_matlab);
p = parametri_ss();

risultati = solve_ss_model(p, 'linearized');
verifica = risultati.validation.summary; % Massimi residui e anni critici
ample = risultati.ample;
poor = risultati.poor;
ample_base = risultati.ample_base;
poor_base = risultati.poor_base;
anni = risultati.time;          % Indice MATLAB 1 = anno 0

cartella_output = fullfile(cartella_matlab, 'output', 'principale');
[riepilogo, figura] = export_ss_results(risultati, cartella_output);
disp(riepilogo);
fprintf('\nRisultati salvati in: %s\n', cartella_output);
