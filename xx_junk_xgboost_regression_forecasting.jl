using CSV, DataFrames, Statistics, Plots, StatsBase, Dates

file_path = "/home/nnx/Documents/Coding/lotto_ran_stock/save/all_data_clean.csv"
df = CSV.File(file_path) |> DataFrame

for col in 2:size(df, 2)
    if eltype(df[!, col]) <: Integer
        continue  # Skip columns that are already integers
    end
    df[!, col] = round.(Int, df[!, col])  # Round to nearest integer and then convert
end

df[!, :price_money] = df.price_money ./ 100 # Data error sovled

#Plot
##########################################################################################
gr()

function plot_average_winners(data::DataFrame)
    # Filter out rows where total_winners is 0
    filtered_data = filter(row -> row.total_winners != 0, data)
    # Group by norm_num and eur_num, and calculate the mean
    grouped_data_mean = combine(groupby(filtered_data, [:norm_num, :eur_num]), :total_winners => mean)
    grouped_data_std = combine(groupby(filtered_data, [:norm_num, :eur_num]), :total_winners => std)
    grouped_data_min = combine(groupby(filtered_data, [:norm_num, :eur_num]), :total_winners => minimum)
    grouped_data_max = combine(groupby(filtered_data, [:norm_num, :eur_num]), :total_winners => maximum)
    
    merged_data = innerjoin(grouped_data_mean, grouped_data_std, on=[:norm_num, :eur_num])
    merged_data = innerjoin(merged_data, grouped_data_min, on=[:norm_num, :eur_num])
    merged_data = innerjoin(merged_data, grouped_data_max, on=[:norm_num, :eur_num])
    rename!(merged_data, names(merged_data)[3] => :mean, names(merged_data)[4] => :std, names(merged_data)[5] => :min, names(merged_data)[6] => :max)

    merged_data[!, "groups"] = [string(row[:norm_num], "+", row[:eur_num]) for row in eachrow(merged_data)]

    return merged_data
end

# Assuming 'lottery_data' is your DataFrame
desc_data = plot_average_winners(df)

function create_scatter_plot(desc_data::DataFrame)
    p = scatter(
        desc_data.groups,
        desc_data.mean,
        group=desc_data.groups,
        yerr=desc_data.std,
        xlabel="Norm Number",
        ylabel="Average Total Winners",
        title="Average Total Winners with Standard Deviation",
        legend=:topright
    )
    
    # Add labels for the data points (showing average numbers)
    for i in 1:nrow(desc_data)
        x = desc_data.groups[i]
        y = desc_data.mean[i]
        avg_number = desc_data.mean[i]  # Assuming you want to show the average number itself
        annotate!(x, y, text(round(avg_number, digits = 0), 10, 45.0, :left, :bottom))  # Adjust the text position and size as needed
    end
    
    return p
end

# Assuming desc_data is a DataFrame with columns desc_data.groups, desc_data.mean, desc_data.std, etc.
create_scatter_plot(desc_data)
create_scatter_plot(desc_data[9:end, :]) # Thus we fill in the holes with randomly distributed numbers

for row in eachrow(df)
    if row.norm_num == 5 && row.eur_num == 2 && row.total_winners == 0
        row.total_winners = 1
    end
end

filtered_desc_data = filter(row -> row.norm_num == 5 && row.eur_num == 1, desc_data)

# Create a function to generate random values based on mean, std, min, and max
function generate_random_value(mean::Float64, std::Float64, min_val::Int64, max_val::Int64)
    random_value = mean + std * randn()
    return round(max(min_val, min(random_value, max_val)))
end

# Iterate through the rows in df and update the mean column using random values from filtered_desc_data
for (i, row) in enumerate(eachrow(df))
    if row.norm_num == 5 && row.eur_num == 1 && row.total_winners == 0
        random_mean = generate_random_value(filtered_desc_data.mean[1], filtered_desc_data.std[1], filtered_desc_data.min[1], filtered_desc_data.max[1])
        df[i, :total_winners] = random_mean
    end
end

##########################################################################################
df[!, :winnings_per_winner] = df.price_money ./ df.total_winners 
df[!, :total_pool] = df.price_money .* df.total_winners 

df_filtered = filter(row -> row.price_money != 0, df)

# Group by date
function group(norm_nums, data)
    grouped = groupby(data, :lottery_date)
    total_pools = Dict("$(norm_nums)_2" => [], "$(norm_nums)_1" => [], "$(norm_nums)_0" => [])
    for g in grouped
        if all([any(row -> row.norm_num == norm_nums && row.eur_num == e, eachrow(g)) for e in [2, 1, 0]])
            for e in [2, 1, 0]
                key = "$(norm_nums)_$(e)"
                total_pool = sum([row.total_pool for row in eachrow(g) if row.eur_num == e])
                push!(total_pools[key], total_pool)
            end
        end
    end
    df_pool = DataFrame(total_pools)
    df_pool[!, :fivetwo_fivzero] = df_pool[!, 3] ./ df_pool[!, 1]
    df_pool[!, :fivetwo_fivone] = df_pool[!, 3] ./ df_pool[!, 2]
    df_pool[!, :fiveone_fivezero] = df_pool[!, 2] ./ df_pool[!, 1]
    return(df_pool)
end

x1 = group(5, df_filtered)
x2 = group(4, df_filtered)
rename!(x2, :fivetwo_fivzero => :fourtwo_fourzero , :fivetwo_fivone => :fourtwo_fourone , :fiveone_fivezero => :fourone_fourzero)
x1 = x1[!, 4:end]
x2 = x2[!, 4:end]

df_pool = hcat(x1, x2)

#############################################

function generate_random_value(mean::Float64, std::Float64, min_val::Float64, max_val::Float64)
    random_value = mean + std * randn()
    return max(min_val, min(random_value, max_val))
end

function logic_cap(new_pool, date)
    date = Date(date)
    if new_pool > 120000000 && date >= Date(2022, 3, 1)
        return 120000000
    elseif new_pool > 90000000 && date >= Date(2013, 2, 1) && date <= Date(2022, 3, 1)
        return 90000000
    elseif new_pool > 27500000 && date <= Date(2013, 2, 1)
        return 27500000
    else 
        return new_pool
    end
end

# Iterate through the rows in df
function upd_total_pool(data, summary_stats)  
    #data = x1
    for i in 1:nrow(data)
        row = data[i, :]
        for x in [6:1]
            stats = summary_stats[x, :]
            if x == 3 || x == 6
                y = 0
            elseif x = 456 
                y = x
            end
            if row.norm_num == 5 && row.eur_num == y && row.total_pool == 0
                lotto_date = Date(row.lottery_date)
                random_mean = generate_random_value(stats.mean, stats.std, stats.min, stats.max)
                new_index = min(i + x, nrow(data))  # Ensure index does not go out of bounds
                new_pool = data[new_index, :total_pool] * random_mean 
                new_pool = logic_cap(new_pool, lotto_date)
                data[i, :total_pool] = new_pool
            end
        end
    end
    return data
end

summary_stats = describe(df_pool)
summary_stats[!, :drop] = [2,1,1,2,1,1]
summary_stats[!, :norm_num] = [5,5,5,4,4,4]

# Call the function to update df
updated_df = upd_total_pool(df, summary_stats)

filter(row -> row.total_pool == 120000000, df)
filter(row -> row.total_pool == 120000000, updated_df)
x1 = filter(row -> row.total_pool == 0, updated_df)

upd_total_pool(x1, summary_stats)
filter(row -> row.total_pool == 0, x1)

#updated_df
