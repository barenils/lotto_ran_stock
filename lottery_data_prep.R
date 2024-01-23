library(dplyr)
library(stringr)

# Set the working directory to the folder containing the files
setwd("/home/nnx/Documents/Coding/lotto_ran_stock/save/")

# List all files in the directory
file_list <- list.files()

# Read all files and combine them into one dataframe
all_data <- lapply(file_list, function(file) {
                  read.csv(file, na.strings = c("", "NA"))
              }) %>% bind_rows()

# Remove duplicate rows
all_data <- distinct(all_data)

# Remove rows with NA
all_data_clean <- na.omit(all_data)

# View the final dataframe
matches <- str_match(all_data_clean$description, "(\\d+) \\+ (\\d+)")

# Assign the first set of digits to norm_num and the second set to eur_num
all_data_clean$norm_num <- as.numeric(matches[, 2])
all_data_clean$eur_num <- as.numeric(matches[, 3])

all_data_clean$total_winners <- str_replace_all(all_data_clean$total_winners, "\\D", "")
all_data_clean$price <- str_replace(all_data_clean$price, "not hit", "0")
all_data_clean$price <- str_replace_all(all_data_clean$price, "\\D", "")
all_data_clean[[1]] <- NULL

all_data_clean %>% head()



# Convert the extracted strings to numeric
all_data_clean$norm_num <- as.numeric(all_data_clean$norm_num)
all_data_clean$eur_num <- as.numeric(all_data_clean$eur_num)
all_data_clean$price <- as.numeric(all_data_clean$price)
all_data_clean$total_winners <- as.numeric(all_data_clean$total_winners)
all_data_clean$lottery_date <- as.Date(all_data_clean$lottery_date, format = "%d.%m.%Y")


all_data_clean <- all_data_clean[c("lottery_date", setdiff(names(all_data_clean), "lottery_date"))]
names(all_data_clean)[3] <- "price_money"
all_data_clean %>% head()

write.csv(all_data_clean, file = "/home/nnx/Documents/Coding/lotto_ran_stock/save/all_data_clean.csv", row.names = FALSE)