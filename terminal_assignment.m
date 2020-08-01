clear all;
% global vars to be used throughout the script
global CostTable sol_length entry_size num_t num_c;
% Cost table matrix where rows are concentrators and cols are terminals
filename = "CostTable.xlsx";
CostTable = getCostTable(filename);
% Number of concentrators and terminals
[num_c, num_t] = size(CostTable);
% Required bits to store the range of terminals
entry_size = length(dec2bin(num_c-1));
% Length of each solution
sol_length = num_t*entry_size;


% The probability vector
PV = ones(1, sol_length) * 0.5;

% Key variables in how the algorithm runs
learning_rate = 0.01;
epoch_size = 250;
max_iterations = 500;

% Keeps track of the min cost of each epoch
min_costs = zeros(1, max_iterations);
% Keeps track of the number of iterations run
iterations = 0;

% Runs until solution is reached or max # of iterations reached
while (iterations < max_iterations && ~solutionReached(min_costs, iterations))
    
    iterations = iterations + 1;
    % Keeps track of the min_cost of this epoch/iteration
    min_cost = inf;
    
    for trial = 1 : epoch_size
        % Generates a solution based on the PV
        current_solution = rand(1, sol_length) < PV;
        current_cost = getTotalCost(current_solution);
        
        % If it's cost is less than current cost & it's valid,
        % reassign min_cost and best_solution
        if (min_cost > current_cost && isValid(current_solution))
            min_cost = current_cost;
            best_solution = current_solution;
        end
    end
    
    % Add this epoch's/iteration's min cost to the array
    min_costs(iterations) = min_cost;
    % Use the best solution to alter the PV
    PV = updatePV(PV, best_solution, learning_rate);

end

% Removes any 0 elements from min_costs as these do not need to be graphed
min_costs = min_costs(min_costs~=0);
% Final minimum cost
min_cost;
% Iterations/epochs required to reach solution
iterations;

PV = reshapeSolution(PV);
% Stores how many connections each concentrator has
concentrator_connections = zeros(1, num_c);
% Stores which terminals are connected to which concentrators
terminal_connections = zeros(1, num_t);

% For each terminal, gets the connected concentrator and increments the
% concentrator's connection count by 1
for terminal = 1 : num_t
    concentrator = convertToInt(PV(:, terminal)) + 1;
    concentrator_connections(concentrator) = concentrator_connections(concentrator) + 1;
    terminal_connections(terminal) = concentrator;
end

% Plots minimum cost over all iterations
subplot(2, 2, 1);
plot(min_costs);
title('Minimum Cost vs Iteration');
xlabel('Iteration');
ylabel('Minimum Cost');
grid on;

% Plots which terminals are connected to which concentrators
subplot(2,2,3);
scatter([1:num_t], terminal_connections, 50, 'filled');
grid on;
axis([1 num_t 1 num_c]);
xlabel('Terminal');
ylabel('Concentrator');
title('Connection Configuration');

% Plots number of connections per concentrator
subplot(2,2,4);
bar(concentrator_connections);
title('Connections per Concentrator');
xlabel('Concentrator');
ylabel('Connections');
grid on;

% Annotates plots with key pieces of information
outstr = ["Learning rate: " + num2str(learning_rate), ...
    "Epoch size: " + int2str(epoch_size), ...
    "Maximum iterations: " + int2str(max_iterations), ...
    "Number of iterations: " + int2str(iterations), ...
    "Final cost: " + int2str(min_cost)];

annotation('textbox', [0.5 0.85 0.1 0.1], 'string', outstr);

function PV = updatePV(PV, best_solution, learning_rate)
    % Modifies PV, increasing probability of getting 1 or 0 if sol has 1 or
    % 0 respectively
    PV(best_solution==1) = PV(best_solution==1) + learning_rate;
    PV(best_solution==0) = PV(best_solution==0) - learning_rate;
    % Entries over 1 or below 0 are rounded to 1 or 0 respectively
    PV(PV>1) = 1;
    PV(PV<0) = 0;
end

function valid = isValid(solution)
    %isValid takes in a binary string and returns true if it adheres to constraints
    global num_t num_c;
    solution = reshapeSolution(solution);
    con_num = zeros(num_c, 1);
    valid = true;
    % Loops over each concentrator, and checks if each is used more than 3
    % times, if so, the solution is invalid
    for i = 1 : num_t
        % Converts logical array to integer and adds 1 (range 1-8)
        concentrator = convertToInt(solution(:, i)) + 1;
        con_num(concentrator) = con_num(concentrator) + 1;
        if (con_num(concentrator) > 3)
            valid = false;
            break
        end
    end
end

function reached = solutionReached(cost_array, iteration)
    % isSolutionReached checks if a solution has been reached
    % If std dev for last 16 iterations is 0, assume solution is reached
    if (iteration > 10)
        reached = std(cost_array(iteration-10:iteration))==0;
    else
        reached = false;
    end
end

function total_cost = getTotalCost(solution)
    %getCost takes in a binary string and returns the total cost of the solution
    global CostTable num_t;
    sol = reshapeSolution(solution);
    total_cost = 0;
    % Loops over each terminal and sums the cost of connection between that
    % terminal and its corresponding concentrator
    for terminal = 1 : num_t
        concentrator = convertToInt(sol(:, terminal)) + 1;
        total_cost = total_cost + CostTable(concentrator, terminal);
    end
end

function number = convertToInt(binary_array)
    % convertToInt converts an array of 1s and 0s to a base 10 number
    global entry_size;
    % Rounds array to 1s and 0s in case they are not already 1s and 0s
    binary_array = round(binary_array);
    number = 0;
    for index = 1 : entry_size
        number = number + binary_array(index)*bitshift(1, entry_size-index);
    end
end

function new_solution = reshapeSolution(solution)
    % Reshapes 1x(entry_size*num_t) solution into (entry_size)x(num_t) solution
    global entry_size num_t;
    new_solution = reshape(solution, [entry_size, num_t]);
end

function costTable = getCostTable(filename)
    % Gets cost table and removes the NaN rows and columns
    costTable = readmatrix(filename);
    [~, cols] = size(costTable);
    % Stores cols that are entirely NaNs (i.e. the headers)
    nan_cols = [];
    % Bool to check if there's a single NaN in a row/column (means that row
    % & col are part of the headers
    nan_row_col = false;
    for i = 1 : cols
        if (isnan(costTable(:,i)))
            nan_cols(end+1) = i;
        elseif (isnan(costTable(1,i)))
            nan_row_col = true;
        end
    end
    % Deletes the columns full of NaNs
    costTable(:,nan_cols) = [];
    % Deletes the row & column with the singular NaN (it's always in the
    % first index for row & col)
    if (nan_row_col)
        costTable(:,1) = [];
        costTable(1,:) = [];
    end
end
