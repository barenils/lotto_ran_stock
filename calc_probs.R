# Function to calculate combinations
choose <- function(n, k) {
  factorial(n) / (factorial(k) * factorial(n - k))
}

# Function to calculate the probability of getting exactly k correct numbers out of n drawn
prob_exact_correct <- function(k, n, total) {
  choose(n, k) * choose(total - n, n - k) / choose(total, n)
}

# Eurojackpot configuration
total_main_numbers <- 50
drawn_main_numbers <- 5
total_euro_numbers <- 12
drawn_euro_numbers <- 2

# 0.0: No correct main numbers and no correct Euro numbers
prob_00 <- prob_exact_correct(0, drawn_main_numbers, total_main_numbers) * prob_exact_correct(0, drawn_euro_numbers, total_euro_numbers)

# 0.1: No correct main numbers and one correct Euro number
prob_01 <- prob_exact_correct(0, drawn_main_numbers, total_main_numbers) * prob_exact_correct(1, drawn_euro_numbers, total_euro_numbers)

# 0.2: No correct main numbers and two correct Euro numbers
prob_02 <- prob_exact_correct(0, drawn_main_numbers, total_main_numbers) * prob_exact_correct(2, drawn_euro_numbers, total_euro_numbers)

# 1.0: One correct main number and no correct Euro numbers
prob_10 <- prob_exact_correct(1, drawn_main_numbers, total_main_numbers) * prob_exact_correct(0, drawn_euro_numbers, total_euro_numbers)

# 1.1: One correct main number and one correct Euro number
prob_11 <- prob_exact_correct(1, drawn_main_numbers, total_main_numbers) * prob_exact_correct(1, drawn_euro_numbers, total_euro_numbers)

# Outputting the probabilities
prob_00
prob_01
prob_02
prob_10
prob_11

total_probability <- prob_00 + prob_01 + prob_02 + prob_10 + prob_11
total_probability

# Output the total probability
total_probability