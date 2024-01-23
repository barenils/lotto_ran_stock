#ods of winning lottery
using Random, CUDA, DataFrames, ProgressMeter, Base.Threads, IterTools, Distributed, CSV

struct ProbabilityStruc 
    prob::Float32
    normal_nums::Int32
    euro_nums::Int32  
end

function ods_lottery()
    out = []
    for i in 0:4  # For main numbers (5, 4, 3, 2, 1)
        draws = 50:-1:(50 - i)  # Unique numbers for the main draw
        main_num_prob = prod(1 ./ draws)  # Probability for main numbers
        for eur_num in 0:2  # For Euro numbers (2, 1, 0)
            euro_prob = (eur_num == 0 ? (11/12)^2 :
                         eur_num == 1 ? 2 * (1/12) * (11/12) : (1/12)^2)
            combined_prob = main_num_prob * euro_prob
            push!(out, ProbabilityStruc(Float32(combined_prob), Int32(i+1), Int32(eur_num)))
        end
    end
    return out
end

ods_of_draw = ods_lottery()

## Calculate how many cupons we need to win a price.

df = ods_of_draw |> DataFrame
df[!, :tickets_need_to_win] = 1 ./ df.prob
df = sort(df, :prob, rev=false ) # Learned something new, lower Probability of 4+2 than 5+0
df[!,:winning_class] = Int32.([1, 2, 4, 3, 5, 6, 7, 9, 8, 10, 12, 11, 999, 999 , 999]) # Manualy entered from eurojackpot website
df = sort(df, :winning_class, rev=false ) 

# Now we should calculate a random cupon.
function eurojackpot_draw()
    #Random.seed!(123) # set seed for reproducability 
    main_numbers = sort(randperm(50)[1:5]) # Select 5 unique numbers from 1 to 50
    euro_numbers = sort(rand(1:12, 2)) # Select 2 numbers (can be the same) from 1 to 12
    return vcat(main_numbers, euro_numbers)
end

# Draw numbers
drawn_numbers = eurojackpot_draw() # your randomly generated cupon.

###########
########## Here we retrive the the price information 
########## THAT TOOK SO MUCH MORE TIME THEN EXPECTED!!!

# Now we should calculate a random cupon.
function eurojackpot_draw()
    main_numbers = sort(randperm(50)[1:5]) # Select 5 unique numbers from 1 to 50
    euro_numbers = sort(rand(1:12, 2)) # Select 2 numbers (can be the same) from 1 to 12
    return CUDA.copy(vcat(main_numbers, euro_numbers))
end

# Draw numbers
drawn_numbers = eurojackpot_draw() # your randomly generated cupon.

###########
########## Here we retrieve the price information 
########## THAT TOOK SO MUCH MORE TIME THAN EXPECTED!!!

function eurojackpot_draw()
    main_numbers = sort(randperm(50)[1:5]) # Select 5 unique numbers from 1 to 50
    euro_numbers = sort(rand(1:12, 2)) # Select 2 numbers (can be the same) from 1 to 12
    return CUDA.copy(vcat(main_numbers, euro_numbers))
end

function draw_tickets(amount_of_ent)
    number_holder = []
    for _ in 1:amount_of_ent
        cupon_nums = eurojackpot_draw()
        push!(number_holder, cupon_nums) 
    end
    return number_holder
end

function comp_tick(tickets, drawn_numbers)
    draw = repeat([drawn_numbers], outer=length(tickets))
    return [ticket .== dn for (ticket, dn) in zip(tickets, draw)]
end

struct draw_struc_cuda
    normal_nums::CuArray{Int32}
    euro_nums::CuArray{Int32}
end

function montecarlo_gpu(tickets, progress::Progress)
    ticket_array = Vector{draw_struc_cuda}()
    drawn_numbers = eurojackpot_draw()
    for i in 1:length(tickets)
        y_comp = comp_tick(tickets, drawn_numbers)
        norm = sum(y_comp[i][1:5])
        eur = sum(y_comp[i][6:7])
        ticket = draw_struc_cuda(CUDA.copy([norm]), CUDA.copy([eur]))
        push!(ticket_array, ticket)
        
        next!(progress)  # Update the progress bar
    end
    return ticket_array
end

function extract_results_info_to_dataframe(results::Vector{Vector{draw_struc_cuda}})
    thread_results = [DataFrame(Normal_Numbers = Int[], Euro_Numbers = Int[]) for _ in 1:Threads.nthreads()]

    @threads for i in 1:length(results)
        run_info = DataFrame(Normal_Numbers = Int[], Euro_Numbers = Int[])
        
        for j in 1:length(results[i])
            ticket = results[i][j]
            normal_nums = Array(ticket.normal_nums)
            euro_nums = Array(ticket.euro_nums)
            push!(run_info, (Normal_Numbers=normal_nums[1], Euro_Numbers=euro_nums[1]))
        end
        append!(thread_results[Threads.threadid()], run_info)
    end

    extracted_info = vcat(thread_results...)
    return extracted_info
end


function main_mc(nruns, tickets)
    results = Vector{Vector{draw_struc_cuda}}(undef, nruns)  # Initialize an array to store results
    progress = Progress(nruns)  # Create a progress bar
    for i in 1:nruns
        y = montecarlo_gpu(tickets, progress)
        results[i] = y  # Store the results in the array
    end
    return results
end


# Function to run simulations on a single GPU #############################################

function run_simulations_on_gpu(runz, tick)
    column_name = string("p_", runz, "_", tick)
    inst_column_name = string("n_", runz, "_", tick)

    tickets = draw_tickets(tick)
    results = main_mc(runz, tickets)

    extracted_df = extract_results_info_to_dataframe(results)
    unique_counts = combine(DataFrames.groupby(extracted_df, [:Normal_Numbers, :Euro_Numbers]), nrow => Symbol(inst_column_name))
    unique_counts[!, Symbol(column_name)] = unique_counts[!, Symbol(inst_column_name)] ./ sum(unique_counts[!, Symbol(inst_column_name)])
    
    CUDA.reclaim()
    GC.gc()
    return unique_counts
end

function grid_cuda_and_save_results()
    nruns = [10_000, 100_000, 1_000_000, 50_000_000, 100_000_000, 250_000_000]  # Adjust this as needed
    ticks_num = [2, 4, 8, 20, 30, 50]  # Adjust this as needed
    range_col1 = 0:5
    range_col2 = 0:2
    combinations = collect(Iterators.product(range_col1, range_col2))
    combinations = vec(combinations)
    df = DataFrame(combinations, [:Normal_Numbers, :Euro_Numbers])

    for runz in nruns
        for tick in ticks_num

            column_name = string("p_", runz, "_", tick)
            inst_column_name = string("n_", runz, "_", tick)
        

            println("Running simulations for ", runz, " runs and tick ", tick)
            half_runs = runz ÷ 2  # Divide the runs evenly between two GPUs
            future_gpu1 = Future()
            future_gpu2 = Future()
        
            @sync begin
                @async begin
                    device!(0)
                    result = run_simulations_on_gpu(half_runs, tick)
                    put!(future_gpu1, result)
                end
                @async begin
                    device!(1)
                    result = run_simulations_on_gpu(half_runs, tick)
                    put!(future_gpu2, result)
                end
            end
        
            # Fetch results from the futures
            results_gpu1 = fetch(future_gpu1)
            results_gpu2 = fetch(future_gpu2)
            # Combine results from both GPUs
            # Assuming you have a mechanism to combine results_gpu1 and results_gpu2
            
            combined_results = outerjoin(results_gpu1, results_gpu2, on = [:Normal_Numbers, :Euro_Numbers], makeunique=true)            
            combined_results[!, Symbol(column_name)] = combined_results[!, end] .* combined_results[!, end-2]
            combined_results[!, Symbol(inst_column_name)] = combined_results[!, end-2] .+ combined_results[!, end-4]
            num_cols = size(combined_results, 2)
            combined_results = combined_results[:, [1, 2, num_cols-1, num_cols]] 

            temp_df = outerjoin(df, combined_results, on = [:Normal_Numbers, :Euro_Numbers], makeunique=true)
            replace!(temp_df[!, Symbol(column_name)], missing => 0)

            # Define the filename for this run
            path = "/home/nnx/Documents/Coding/lotto_ran_stock/cuda_runs/"
            csv_filename = string(path, "results_run_", runz, "_tick_", tick, ".csv")

            CUDA.device_reset!(CuDevice(0))
            CUDA.device_reset!(CuDevice(1))
            # Write the combined results to a CSV file
            CSV.write(csv_filename, temp_df)
        end
    end
end

# Call the function to run simulations on both GPUs and save results to CSV files
grid_cuda_and_save_results()


##########################################################
function draw_tickets(amount_of_ent)
    number_holder = []
    for _ in 1:amount_of_ent
        cupon_nums = eurojackpot_draw()
        push!(number_holder, cupon_nums) 
    end
    return number_holder
end


function comp_tick(tickets, drawn_numbers)
    draw = repeat([drawn_numbers], outer=length(tickets))
    return [ticket .== dn for (ticket, dn) in zip(tickets, draw)]
end

struct draw_struc
    normal_nums::Vector{Int32}
    euro_nums::Vector{Int32}
end

function montecarlo_cpu(tickets)
    ticket_array = Vector{draw_struc}()
    drawn_numbers = eurojackpot_draw()
    for i in 1:length(tickets)
        y_comp = comp_tick(tickets, drawn_numbers)
        norm = sum(y_comp[i][1:5])
        eur = sum(y_comp[i][6:7])
        ticket = draw_struc([norm], [eur])
        push!(ticket_array, ticket)
    end
    return ticket_array
end

function main_mc(nruns, tickets)
    results = Vector{Vector{draw_struc}}(undef, nruns)  # Initialize an array to store results
    @threads for i in 1:nruns
        y = montecarlo_cpu(tickets)
        results[i] = y  # Store the results in the array
    end
    return results
end

tickets = draw_tickets(2)
y = comp_tick(tickets, drawn_numbers)
x = main_mc(10^4, tickets)