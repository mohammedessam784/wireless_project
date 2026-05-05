clc; clear; close all;

%% ================= INPUTS =================
GOS = input('Enter GOS (e.g. 0.02): ');
city_area = input('Enter city area (km^2): ');
user_density = input('Enter user density (users/km^2): ');
SIR_dB = input('Enter SIRmin (dB): ');
sector_type = input('Enter sectorization (1=Omni, 2=120deg, 3=60deg): ');

total_channels = 340;
traffic_per_user = 0.025;

%% ================= CALCULATIONS =================

% Cluster Size
N = calc_cluster_size(SIR_dB, sector_type);

% Channels per cell
channels_per_cell = floor(total_channels / N);
% Traffic per sector
num_sectors = get_num_sectors(sector_type);
channels_per_sector=floor(channels_per_cell / num_sectors);
% Total users
total_users = city_area * user_density;

% Total traffic
A_total = total_users * traffic_per_user;

% Traffic per cell using Erlang B
A_sector = erlangB_from_excel(channels_per_sector, GOS);
A_cell= A_sector*num_sectors;
% Number of cells
num_cells = ceil(A_total / A_cell);

% Cell radius
R = calc_cell_radius(city_area, num_cells);

% Transmit Power
Pt = calc_tx_power(R);

fprintf('\n===== RESULTS =====\n');
fprintf('Cluster Size = %d\n', N);
fprintf('Number of Cells = %d\n', num_cells);
fprintf('Cell Radius = %.2f km\n', R);
fprintf('Traffic per Cell = %.2f Erlang\n', A_cell);
fprintf('Traffic per Sector = %.2f Erlang\n', A_sector);
fprintf('Transmit Power = %.2f dBm\n', Pt);

% Plot
plot_received_power(Pt, R);


function N = calc_cluster_size(SIR_dB, sector_type)

SIR = 10^(SIR_dB/10);

% Number of interferers
switch sector_type
    case 1
        i0 = 6;
    case 2
        i0 = 2;
    case 3
        i0 = 1;
end

n = 4;

% Theoretical N
N_theoretical = (((SIR * i0)^(1/n))+1)^2/ 3;

% Valid cluster sizes
valid_N = [1 3 4 7 9 12 13 16 19 21 27 28 31];

% Choose smallest valid N >= theoretical
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

% Read Erlang B table from CSV file
data = readmatrix('Erlang B Table.csv');

% Remove header rows (adjust this number if needed)
data = data(5:end, :);

% First column contains number of channels (trunks)
channels = data(2:end,1);

% First row (excluding first column) contains GOS values in percentage
gos = data(1,2:end);

% Remaining table contains traffic values (Erlang)
traffic_table = data(2:end,2:end);



% Find closest GOS column
[~, col_idx] = min(abs(gos - GOS));

% Find row corresponding to number of channels
row_idx = find(channels == C);

if isempty(row_idx)
    error('Channel value not found in Erlang B table');
end

% Extract traffic value
A_cell = traffic_table(row_idx, col_idx);

end

function B = erlangB(C, A)

B = 1;
for i = 1:C
    B = (A * B) / (i + A * B);
end

end

function Pt = calc_tx_power(R)

f = 900; % MHz
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

