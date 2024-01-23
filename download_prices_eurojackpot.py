from selenium import webdriver # Webdriver
from selenium.webdriver.support.ui import WebDriverWait # Allows webdriver to wait for refresh
from selenium.webdriver.support import expected_conditions as EC # Error expectation 
from selenium.webdriver.common.by import By # passing arguemnt 
from selenium.webdriver.chrome.options import Options # Set the options for chrome 
import re # used to locate numbers 
from selenium.common.exceptions import StaleElementReferenceException
import pandas as pd # Pandas dataframes
import time
import subprocess # Allows linux commands to be sendt 
from selenium.webdriver.common.keys import Keys
from IPython.display import display
from tqdm import tqdm
import random
import os





# Bash docker run -d -p 4444:4444 -p 7900:7900 selenium/standalone-chrome:latest 

#driver = webdriver.Remote(command_executor='http://localhost:4444/wd/hub', options = opt_conf)  # Adjust the port if needed

def n_dates(driver):
    npages = driver.find_element(By.CSS_SELECTOR, "div.flex-md-grow-0:nth-child(1) > select:nth-child(1)")
    max_page = len(re.findall(r'\d{2}\.\d{2}', npages.text)) 
    return max_page

def n_year_(driver):
    npages = driver.find_element(By.CSS_SELECTOR, "div.flex-md-grow-0:nth-child(2) > select:nth-child(1)")
    max_page = len(re.findall(r'\d{4}', npages.text)) 
    return max_page

import time

def scrape_table(driver, timestamp):
    attempts = 0
    max_attempts = 10
    while attempts < max_attempts:
        try:
            table = driver.find_element(By.CLASS_NAME, 'results-table')
            rows = table.find_elements(By.TAG_NAME, "tr")
            data = []
            for row in rows:
                cells = row.find_elements(By.TAG_NAME, "td")
                row_data = [cell.text for cell in cells]
                data.append(row_data)
            return pd.DataFrame(data, columns=['description', 'total_winners', 'price'])
        except StaleElementReferenceException:
            random_number = random.randint(1, 5)
            print(f"Unstable DOM, waiting {random_number} seconds (timestamp: {timestamp})")            
            time.sleep(random_number)  # Wait a bit for the DOM to become stable
            driver.find_element(By.TAG_NAME, 'body').send_keys(Keys.PAGE_DOWN)
            time.sleep(.5)
            driver.find_element(By.TAG_NAME, 'body').send_keys(Keys.PAGE_UP)
            time.sleep(.5)

            attempts += 1
    raise Exception("Failed to scrape table after multiple attempts")

#def scrape_table(driver):
    data = []    
    table = driver.find_element(By.CLASS_NAME, 'results-table')
    rows = table.find_elements(By.TAG_NAME, "tr")
    for row in rows:
        cells = row.find_elements(By.TAG_NAME, "td")
        row_data = [cell.text for cell in cells]
        data.append(row_data)
    return pd.DataFrame(data, columns=['description', 'total_winners', 'price'])

def interact_next(path_to_click, driver, y):
    root = driver.find_element(By.CSS_SELECTOR, path_to_click)
    root.click()
    for _ in range(y): 
        root.send_keys(Keys.ARROW_DOWN)
    root.send_keys(Keys.ENTER)

def loop_dates(drop_down_dates, current_year, ww_mm, driver):
    all_tables = pd.DataFrame() 
    table_data = pd.DataFrame() 
    for i in range(drop_down_dates):  # Include all dates
        WebDriverWait(driver, 5).until(EC.presence_of_element_located((By.CLASS_NAME, 'results-table')))
        current_date = ww_mm[i]
        the_date_to_use = f'{current_date}.{current_year}'
        time.sleep(1)
        table_data = scrape_table(driver, the_date_to_use)
        table_data['lottery_date'] = the_date_to_use
        all_tables = all_tables._append(table_data, ignore_index=True)  # Reassign appended DataFrame
        if i != drop_down_dates - 1:  # Only interact if not the last date
            interact_next("div.flex-md-grow-0:nth-child(1) > select:nth-child(1)", driver, 1) 
    return all_tables

def connect_docker():
    opt_conf = Options()

    opt_conf.add_experimental_option("prefs", {
    "download.prompt_for_download": False,
    "profile.default_content_setting_values.popups": 2,
    "safebrowsing.enabled": True
    })

    docker_driver = webdriver.Remote(
        command_executor='http://localhost:4444/wd/hub',  # Adjust the port if needed
        options = opt_conf
    )

    return docker_driver


def check_docker_container(container_name):
    # Run 'docker ps' to get a list of running containers
    result = subprocess.run(['docker', 'ps'], capture_output=True, text=True)

    # Check if the specific container is in the output
    if container_name in result.stdout:
        # If the container is running, restart it
        restart_result = subprocess.run(['docker', 'restart', container_name], capture_output=True, text=True)
        return f"Container '{container_name}' restarted. Output: {restart_result.stdout}"
    else:
        # If the container is not running, start it
        start_result = subprocess.run(['docker', 'start', container_name], capture_output=True, text=True)
        return f"Container '{container_name}' started. Output: {start_result.stdout}"

def load_saved_years(directory):
    # Load all saved years to know where to continue from
    saved_years = []
    for filename in os.listdir(directory):
        if filename.endswith(".csv"):  # or .json, .pkl, etc. depending on your chosen format
            year = filename.split('.')[0]
            saved_years.append(int(year))
    return saved_years

def scraper():
    all_data = pd.DataFrame() 
    scraped_data = pd.DataFrame() 
    main_url = "https://www.eurojackpot.com/"
    #check_docker_container("priceless_hypatia")
    #time.sleep(5)
    #driver = connect_docker()
    driver = webdriver.Chrome()
    driver.get(main_url)
    WebDriverWait(driver, 5).until(EC.presence_of_element_located((By.CLASS_NAME, 'results-table'))) 
    drop_down_years = n_year_(driver)
    active_year = driver.find_element(By.CSS_SELECTOR, "div.flex-md-grow-0:nth-child(2) > select:nth-child(1)")
    year = re.findall(r'\d{4}', active_year.text)
    saved_years = load_saved_years("/home/nnx/Documents/Coding/lotto_ran_stock/save/")
    for y in tqdm(range(drop_down_years)):
    #for y in tqdm(range(2)):
        driver.find_element(By.TAG_NAME, 'body').send_keys(Keys.PAGE_DOWN)
        current_year = year[y]
        time.sleep(.5)
        if int(current_year) in saved_years:
            continue
        if y > 0:
            interact_next("div.flex-md-grow-0:nth-child(2) > select:nth-child(1)", driver, y) # Year 
        WebDriverWait(driver, 5).until(EC.presence_of_element_located((By.CLASS_NAME, 'results-table')))
        drop_down_dates = n_dates(driver)
        active_date = driver.find_element(By.CSS_SELECTOR, "div.flex-md-grow-0:nth-child(1) > select:nth-child(1)")
        ww_mm = re.findall(r'\d{2}\.\d{2}', active_date.text)
        loop_tabs = loop_dates(drop_down_dates, current_year, ww_mm, driver)
        all_data = all_data._append(loop_tabs)
        filename = f"/home/nnx/Documents/Coding/lotto_ran_stock/save/{current_year}.csv"
        all_data.to_csv(filename, index=False)
        driver.refresh()
    if all_data:
        scraped_data = pd.concat(all_data, ignore_index=True)
        driver.quit()
        return scraped_data
    else:
        return pd.DataFrame()  # Return an empty DataFrame if no data was scraped


def retry_scraper(max_attempts):
    attempt = 0
    while attempt < max_attempts:
        try:
            scraped_all = scraper()
            return scraped_all  # Successfully executed, return the result
        except Exception as e:
            attempt += 1
            print(f"Attempt {attempt} failed. Retrying...")

            if attempt == max_attempts:
                print("Maximum attempts reached. Exiting.")
                raise e  # Optional: re-raise the last exception after the last attempt

scraped_all = retry_scraper(10)


pd.options.display.max_rows = None
display(scraped_all)





