function cellular_gui
clc;

%% ================= UI FIGURE =================
fig = uifigure('Name','Cellular Network Planner','Position',[100 100 500 600]);

%% ================= INPUT FIELDS =================
uilabel(fig,'Position',[20 540 200 22],'Text','GOS:');
gosField = uieditfield(fig,'numeric','Position',[200 540 100 22],'Value',0.02);

uilabel(fig,'Position',[20 500 200 22],'Text','City Area (km^2):');
areaField = uieditfield(fig,'numeric','Position',[200 500 100 22]);

uilabel(fig,'Position',[20 460 200 22],'Text','User Density:');
densityField = uieditfield(fig,'numeric','Position',[200 460 100 22]);

uilabel(fig,'Position',[20 420 200 22],'Text','SIRmin (dB):');
sirField = uieditfield(fig,'numeric','Position',[200 420 100 22]);

uilabel(fig,'Position',[20 380 200 22],'Text','Sector (1=Omni,2=120,3=60):');
sectorField = uieditfield(fig,'numeric','Position',[250 380 50 22]);

%% ================= BUTTON =================
btn = uibutton(fig,'push',...
    'Text','Calculate',...
    'Position',[180 330 120 30],...
    'ButtonPushedFcn',@(btn,event) calculateCallback());

%% ================= OUTPUT AREA =================
outputBox = uitextarea(fig,...
    'Position',[20 20 460 290],...
    'Editable','off');

%% ================= CALLBACK =================
function calculateCallback()

    GOS = gosField.Value;
    city_area = areaField.Value;
    user_density = densityField.Value;
    SIR_dB = sirField.Value;
    sector_type = sectorField.Value;

    total_channels = 340;
    traffic_per_user = 0.025;

    % ---- Calculations ----
    N = calc_cluster_size(SIR_dB, sector_type);
    channels_per_cell = floor(total_channels / N);

    num_sectors = get_num_sectors(sector_type);
    channels_per_sector = floor(channels_per_cell / num_sectors);

    total_users = city_area * user_density;
    A_total = total_users * traffic_per_user;

    A_sector = erlangB_from_excel(channels_per_sector, GOS);
    A_cell = A_sector * num_sectors;

    num_cells = ceil(A_total / A_cell);
    R = calc_cell_radius(city_area, num_cells);
    Pt = calc_tx_power(R);

    % ---- Display ----
    outputBox.Value = {
        '===== RESULTS ====='
        ['Cluster Size = ' num2str(N)]
        ['Number of Cells = ' num2str(num_cells)]
        ['Cell Radius = ' num2str(R) ' km']
        ['Traffic per Cell = ' num2str(A_cell)]
        ['Traffic per Sector = ' num2str(A_sector)]
        ['Transmit Power = ' num2str(Pt) ' dBm']
        ''
        'Plot generated... check figure window'
    };

    plot_received_power(Pt, R);

end

end

%% ================= FUNCTIONS (same as yours) =================

function N = calc_cluster_size(SIR_dB, sector_type)

SIR = 10^(SIR_dB/10);

switch sector_type
    case 1
        i0 = 6;
    case 2
        i0 = 2;
    case 3
        i0 = 1;
end

n = 4;

N_theoretical = (((SIR * i0)^(1/n))+1)^2/ 3;

valid_N = [1 3 4 7 9 12 13 16 19 21 27 28 31];

N = valid_N(find(valid_N >= N_theoretical, 1));

end

function sectors = get_num_sectors(type)

if type == 1
    sectors = 1;
elseif type == 2
    sectors = 3;
else
    sectors = 6;
end

end

function R = calc_cell_radius(area, num_cells)
cell_area = area / num_cells;
R = sqrt((2 * cell_area) / (3 * sqrt(3)));
end

function A_cell = erlangB_from_excel(C, GOS)

data = readmatrix('Erlang B Table.csv');
data = data(5:end, :);

channels = data(2:end,1);
gos = data(1,2:end);
traffic_table = data(2:end,2:end);

[~, col_idx] = min(abs(gos - GOS));
row_idx = find(channels == C);

if isempty(row_idx)
    error('Channel value not found in Erlang B table');
end

A_cell = traffic_table(row_idx, col_idx);

end

function Pt = calc_tx_power(R)

f = 900;
hb = 20;
hm = 1.5;
d = R;

a_hm = (1.1*log10(f)-0.7)*hm - (1.56*log10(f)-0.8);

L = 69.55 + 26.16*log10(f) - 13.82*log10(hb) ...
    - a_hm + (44.9 - 6.55*log10(hb))*log10(d);

Pr_min = -95;

Pt = Pr_min + L;

end

function plot_received_power(Pt, R)

d = linspace(0.1, R, 100);

f = 900;
hb = 20;
hm = 1.5;

Pr = zeros(size(d));

for i = 1:length(d)

    a_hm = (1.1*log10(f)-0.7)*hm - (1.56*log10(f)-0.8);

    L = 69.55 + 26.16*log10(f) - 13.82*log10(hb) ...
        - a_hm + (44.9 - 6.55*log10(hb))*log10(d(i));

    Pr(i) = Pt - L;

end

figure;
plot(d, Pr, 'LineWidth',2);
grid on;
xlabel('Distance (km)');
ylabel('Received Power (dBm)');
title('Received Power vs Distance');

end