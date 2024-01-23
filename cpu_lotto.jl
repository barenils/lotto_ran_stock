using Random, DataFrames, Base.Threads, ProgressMeter, StatsBase, CSV

#Selects x amount of rows from our large lottoframe 
function eurojackpot_draw()
    main_numbers = sort(randperm(50)[1:5]) # Select 5 unique numbers from 1 to 50
    euro_numbers = rand(1:12, 2) # Select 2 numbers (can be the same) from 1 to 12
    return vcat(main_numbers, euro_numbers)
end

function lotto_run(runs)
    b_size = 500_000
    batch = runs ÷ b_size
    holder_mat = Vector{Vector{Int}}()
    lock = ReentrantLock()
    progress = Progress(batch, desc="Creating all lotto numbers: ")  # Initialize the progress meter

    Threads.@threads for _ in 1:batch
        local_batch = Vector{Int}[]

        for _ in 1:b_size
            draw = eurojackpot_draw()
            push!(local_batch, draw)
        end

        Threads.lock(lock)
        try
            append!(holder_mat, local_batch)
        finally
            Threads.unlock(lock)
            next!(progress)  # Update the progress meter
        end
    end

    return holder_mat
end

#lotto_run(100_000_000)

function lotto_machine(data, rows_to_keep)
    sel_rows = randperm(size(data, 1))[1:rows_to_keep] # Ran non repeat nums 
    lotto_draws = data[sel_rows, :] #select those nums
    return lotto_draws
end

# same as above, but we need tickets. (Redundant when i see it now)
function ticket_machine(data, rows_to_keep)
    sel_rows = randperm(size(data, 1))[1:rows_to_keep]
    tickets = data[sel_rows, :]
    return tickets
end


function count_matches(cupon, lotto_matrix)
    match_counts = Dict()
    #cupon = Ticket
    # Initialize match_counts dictionary with all possible combinations
    for i in 0:5
        for j in 0:2
            match_counts[(i, j)] = 0
        end
    end

    for single_tick in eachrow(cupon)
        cupon_first_five = single_tick[1:5]
        cupon_last_two = single_tick[6:end]
        for row in eachrow(lotto_matrix)
            first_five_match_count = sum(in.(cupon_first_five, row[1:5]))
            last_two_match_count = sum(in.(cupon_last_two, row[6:end]))
            match_counts[(first_five_match_count, last_two_match_count)] += 1
        end
    end

    return match_counts
end

function monte_carlo_combined(data, draws, ticks)
    draws_matrix = lotto_machine(data, draws) # We draw from big table 
    tickets_matrix = ticket_machine(data, ticks) # Tickets from big table 
    matches = count_matches(draws_matrix, tickets_matrix) # compare the two 
    propper_format = fix_columns(matches) # fix cols  
    result = count_unique(propper_format) # Counting information
    path = "/home/nnx/Documents/Coding/lotto_ran_stock/cuda_runs/"
    csv_filename = string(path, ticks, "_tick_", draws, ".csv")
    CSV.write(csv_filename, result) # Saves 
    return
end

function main_mc()
    lotto_frame = lotto_run(250_000_000)
    no_tickets = [2, 4, 6, 10, 20, 50, 100, 1_000] # no of entries to lottery
    lotto_draws = [50_000, 100_000, 1_000_000, 10_000_000, 100_000_000, 250_000_000] # no of draws from big simulation
    #no_tickets = [2, 4, 6, 10] # no of entries to lottery
    #lotto_draws = [50_000, 100_000, 1_000_000] # no of draws from big simulation
    counter = 0 # counter to check
    all_combs = size(lotto_draws,1) * size(no_tickets,1) # all u combs 

    @threads for ticks in no_tickets #multi threading
        @threads    for draws in lotto_draws
            counter += 1
            monte_carlo_combined(lotto_frame, draws, ticks) # Runs the sim per unique combination
            println(counter, "/", all_combs, " @ ", ticks," - ", draws)
        end
    end
end

main_mc()

