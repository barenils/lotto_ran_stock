using CUDA, Random, DataFrames, Base.Threads, ProgressMeter, StatsBase, CSV

function generate_lottery_numbers(n::Int, numbers_out, highest_num)
    num_numbers = numbers_out
    rng = CUDA.CURAND.RNG()
    gpu_numbers = CUDA.zeros(Float32, num_numbers, n)
    CUDA.rand!(rng, gpu_numbers)
    gpu_numbers .= floor.(gpu_numbers .* highest_num) .+ 1
    cpu_numbers = Array(gpu_numbers)  # Convert to Array
    cpu_numbers = Int32.(cpu_numbers)  # Convert the elements to Int32
    return cpu_numbers
end

function check_urows(data)
    x = Bool[]  # Initialize an empty array to store results (true if row has all unique elements, false otherwise)
    for row in eachrow(data)  # Loop through rows using eachrow
        u = allunique(row)
        push!(x, u)
    end
    return x
end

function lotto_machine(target)
    norm_nums = transpose(generate_lottery_numbers(target, 5, 50))
    row_check = check_urows(norm_nums)
    org_data = norm_nums[row_check, :]
    u_size = size(org_data,1)
    if u_size < target
        extra = target - u_size
        regenerate = transpose(generate_lottery_numbers(target, 5, 50))
        row_check = check_urows(regenerate)
        filtered_data = regenerate[row_check, :] 
        sampled_rows = sample(filtered_data, extra, replace=false)
        sampled_matrix = filtered_data[sampled_rows, :]
        eur_nums = transpose(generate_lottery_numbers(target, 2, 12))
        org_data = vcat(org_data, sampled_matrix)
        org_data = hcat(org_data, eur_nums)
        return org_data
    end 
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

    Threads.@threads for single_tick in eachrow(cupon)
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

function extract_to_df(data)
    correct_counts = Int[]
    extra_counts = Int[]
    instances = Int[]

    # Populate the arrays
    for (key, value) in data
        push!(correct_counts, key[1])
        push!(extra_counts, key[2])
        push!(instances, value)
    end

    # Convert to DataFrame
    df = DataFrame(Correct = correct_counts, Extra = extra_counts, Instances = instances)
    #sort!(df, :Instances)
    #show(df, allrows=true)
    #sum(vcat(df[14:end,3], df[12,3]))
    return df
end

function ticket_machine(no_tickets)
    generated_ticks = lotto_machine(no_tickets*1000)
    sampled_rows = sample(generated_ticks, no_tickets, replace=false)
    sampled_matrix = generated_ticks[sampled_rows, :]
    return sampled_matrix
end

function comb_df()
    range_col1 = 0:5
    range_col2 = 0:2
    combinations = collect(Iterators.product(range_col1, range_col2))
    combinations = vec(combinations)
    combinations = DataFrame(combinations)
    rename!(combinations, :1 => "norm", :2 => "eur")
    return combinations
end 

function grid_search()
    #no_tickets = [2, 6, 10, 20, 50, 100, 1000, 9000]
    no_tickets = [6, 10, 20, 50, 100, 1000, 9000]
    lotto_draws = [50_000, 100_000, 1_000_000, 10_000_000, 100_000_000, 250_000_000]
    #no_tickets = [2, 6, 10]
    #lotto_draws = [50_000, 100_000]
    combinations = comb_df()
    total_iterations = length(no_tickets) * length(lotto_draws)
    progress = Progress(total_iterations, 1, "Processing: ", 50)

    for ticks in no_tickets
        for draws in lotto_draws
            Ticket = ticket_machine(ticks)
            lotto_matrix = lotto_machine(draws)
            y = count_matches(Ticket, lotto_matrix)
            df_extracted  = extract_to_df(y)
            df_extracted = DataFrame(df_extracted)
            name_of_col = string(ticks, "_", draws)
            rename!(df_extracted, :Instances => name_of_col, :Correct => "norm", :Extra => "eur")
            combinations = outerjoin(combinations, df_extracted, on = [:norm, :eur], makeunique=true)
            next!(progress)
            path = "/home/nnx/Documents/Coding/lotto_ran_stock/cuda_runs/"
            csv_filename = string(path, ticks, "_tick_", draws, ".csv")
            CSV.write(csv_filename, combinations)

        end
    end
    return combinations          
end

x = grid_search()
