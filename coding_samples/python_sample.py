"""
# Webscraper - Python Coding Sample

This python script is a web scraper that extracts book metadata from the National Library of India's online catalog 
(https://nationallibraryopac.nvli.in/) using systematic DDC code searches across multiple Indian languages. 
The script implements robust scraping with progress tracking and database storage for large-scale data collection.

NOTE:   This script was adapted from work I performed as an RA for a research project under Reka Juhasz. 
        All the code in this script is my own work and not based on work by any other RAs.

The code performs the following steps (non-exhaustive):
1. Initialize language list and DDC code list
2. Save DDC codes list to CSV file for reference
3. For each language:
   a. Check progress tracker to identify already scraped DDC codes
   b. Create list of remaining codes to scrape
   c. For each remaining DDC code:
      - Build search URL with language and DDC parameters
      - Send HTTP request to get total number of results
      - Calculate number of pages needed (100 results per page)
      - For each page:
        * Send HTTP request to scrape page content
        * Parse HTML to extract book metadata (title, call number, author, type, form, language, year, link)
        * Save extracted data to SQLite database
        * Add random delay (1-5 seconds) to avoid server blocking
      - Update progress tracker with completed DDC code
   d. Move to next language

Inputs:
- List of languages (Hindi, Tamil, Marathi, Urdu, Kannada, Bengali, English)
- List of DDC codes (600-699 range for technology and applied sciences)
- Base path for data storage
- User also needs to declare their device headers for HTTP requests in line 65

Outputs:
- SQLite databases with book metadata (one per language): `{path}/1_scraped_data/parsed_data_{language}.db`
- CSV progress tracking files: `{path}/0_subject_list/scraper_progess_tracker/ddc_codes_scraped_{language}.csv`
- DDC codes reference file: `{path}/0_subject_list/tech_ddc_codes_list.csv`

Dependencies:
- httpx
- pandas
- sqlite3
- BeautifulSoup
- math
- time
- re
- random

By: Akshat Kumar
Last updated: 8th September, 2025

"""
# Import the necessary libraries
import httpx
import pandas as pd
from random import randint
import time
import re
import sqlite3
import math
from bs4 import BeautifulSoup

# Declare the headers for the HTTP request
headers = {""} # Please add your device header here

def extract_text(soup, selector):
    """
    Tries to parse HTML for the text assoicted with the selector. 
    If the selector does not have text (i.e. we get an error message), it returns nothing.
    
    Input: HTML and selector
    Output: 
        - if selector exists: text associated with selector
        - if selector does not exist: None
    """
    try:
        text = soup.find(selector).text
        return text
    except AttributeError:
        # Return None if the selector is not found in the HTML
        return None

def extract_text_class(soup, selector, type ):
    """
    Tries to parse HTML for the text assoicted with the selector and a certian class.
    If the selector does not have text (i.e. we get an error message), it returns nothing.
    
    Input: HTML and selector
    Output: 
        - if selector exists: text associated with selector
        - if selector does not exist: None
    """
    try:
        text = soup.find(selector, class_=type).text
        return text
    except AttributeError:
        # Return None if the selector with specified class is not found
        return None

def clean_title(title):
    """
    Cleans the title of a book by removing new lines, tabs and slashes.
    """
    title = title.replace("\n", "")  # Remove newline characters
    title = title.replace("\t", "")  # Remove tab characters
    title = title.replace("/", "")   # Remove forward slashes
    title = title.strip()            # Remove leading/trailing whitespace
    return title


def extract_title(soup):
    """
    Extracts the clean title of a book from the HTML.
    """
    try:
        temp = soup.find('a', class_='title')
        # Extract the first direct text content (non-recursive) and clean it
        title = clean_title(temp.find(string=True, recursive = False))
        return title
    except AttributeError:
        # Return None if title element is not found
        return None

def extract_book_type(soup):
    """
    Extracts the type of a book(Periodicals, Printed text, etc.) from the HTML.
    """
    try:
        temp = soup.find('span', class_='results_material_type')
        # Remove the "Material type:" label and extract only the actual type
        material_type = temp.get_text(strip=True).replace("Material type:", "")
        return material_type
    except (AttributeError, IndexError):
        # Return None if material type element is not found or accessible
        return None
    
def extract_book_language(soup):
    """
    Extracts the language of a book from the HTML.
    """
    try:
        temp = soup.find('span', class_="results_summary languages")
        # Split by colon and extract the language part (after the colon)
        language = temp.get_text(strip=True).split(":", 1)[1].strip()
        return language
    except (AttributeError, IndexError):
        # Return None if language element is not found or doesn't contain colon
        return None

def extract_book_form(soup):
    """
    Extracts the literary form of a book from the HTML.
    """
    try:
        temp = soup.find('span', class_="results_contents_literary")
        # Check if the text contains a colon separator
        if ":" in temp.get_text(strip=True):
            # Extract text after the colon (the actual literary form)
            form = temp.get_text(strip=True).split(":", 1)[1].strip()
            return form
        else:
            # If no colon, return the entire text as the form
            return temp.get_text(strip=True).strip()
    except (AttributeError, IndexError):
        # Return None if literary form element is not found
        return None

def extract_call_number(book):
    """
    Extract the call number of a book from the HTML of the book.
    """
    try:
        call_number = book.find('span', class_='CallNumber').text.strip()
        return call_number
    except AttributeError:
        return None
    
def extract_link(book):
    """
    Extract the link of a book from the HTML of the book.
    """
    try:
        link = book.find('a').get('href')
        return link
    except AttributeError:
        return None
    
def parse_book(book):
    """
    Takes in a list of HTMLs where each HTML is a book and returns a list of tuples with the title, author, material type and year of the books.
    """
    title  = extract_title(book) # Book Title
    call_number = extract_call_number(book) # Call Number
    author = extract_text(book, "p") # Book Author
    booktype = extract_book_type(book) # Book Type
    form = extract_book_form(book) # Book Form
    language = extract_book_language(book) # Book Language
    year = extract_text_class(book,"span" , "publisher_date") # Book Year
    link = extract_link(book) # Book Link
    yield (title, call_number, author, booktype, form, language, year, link)


def num_of_results(url):
    """
    Takes in a URL and returns the number of results from the search.
    """
    resp = httpx.get(url, headers=headers, timeout=200)
    soup = BeautifulSoup(resp.content, 'html.parser')
    # Extract the text from h1 tag which contains result count
    num_results = soup.find('h1').text.strip()
    # Use helper function to extract numeric value from the text
    return extract_number(num_results)

def num_of_pages(num):
    """
    Takes in a number, divides it by 100 and returns the ceiling of the result.
    We use to find the number of pages we need to scrape scrape for each subject.
    """
    if num is None:
        return None
    else:
        # Each page displays 100 results, so calculate total pages needed
        return math.ceil(num / 100)

def extract_number(str):
    """
    Takes in a string and resturns the numbers presenet in the string. If the string has not numbers, it returns None.
    """
    # Find all digit sequences in the string using regex
    number = re.findall(r'\d+', str)
    if not number:
        return None
    # Join all found numbers and convert to integer
    return int(''.join(number))

def build_url(language, num, DDC):
    """
    Builds the url for the search based on the given subject, end year, language and the number of reuslts we have already parsed.

    Advanced Search Criteria:
    1) Call Number: DDC
    2) Item Type: Books
    3) Language: given language
    4) Content: Non-Fiction
    5) Sort by: Call Number (Z-A to 9-0)

    Parameters:
    - 100 results are displayed per page
    - The offset is the number of results we have already parsed

    Note: Call Number use by the Indian National Library follow the following format: "{language code}+{DDC Code}+{Internal Classfication Number}"
    The language codes are alphabets, the DDC code is a numeric(may contains periods) and the Internal Classification Number is alphanumeric.

    We would like to scrape books with DDC code begininng with 6 however, the Indian library does not have a filter for this. When we searh for call number using a 
    certain character, we are returned books with that character present anywhere in the call number. Therefore, we will be scraping books with 6 anywhere in the 
    call number and will have to filter them later.
    """
    # Map language names to their 3-letter ISO codes used by the library
    if language == "Hindi":
        lan = "hin"
    elif language == "Bengali":
        lan = "ben"
    elif language == "Tamil":
        lan = "tam"
    elif language == "Marathi":
        lan = "mar"
    elif language == "Urdu":
        lan = "urd"
    elif language == "Kannada":
        lan = "kan"
    elif language == "English":
        lan = "eng"
    else:
        print( language + " is not supported recognized.")
        return
    # Construct the search URL with all parameters for advanced search
    url = f"https://nationallibraryopac.nvli.in/cgi-bin/koha/opac-search.pl?idx=callnum&q={DDC}&limit=mc-itype%2Cphr%3ABKS&limit=ln%2Crtrn%3A{lan}&limit=fic%3A0&offset={num}&sort_by=call_number_dsc&count=100"
    
    return url

def save_to_database(database_path, page_results):
    """
    Save the page results to the database.

    Parameters:
    - database_path (str): Path to the SQLite database file.
    - page_results (list of tuples): Data to be inserted into the database.
    """
    con = sqlite3.connect(database_path)
    cur = con.cursor()
    
    # In the database, observations are identified by (title, author, year)
    # This is to ensure that we do not have duplicate entries

    # Create the books table with all necessary columns if it doesn't exist
    cur.execute(
        """CREATE TABLE IF NOT EXISTS books
            (title text, call_number text, author text, booktype text, form text, language text, year text, link text)"""
    )
    # Insert data using OR IGNORE to prevent duplicate entries
    cur.executemany(
        "INSERT OR IGNORE INTO books VALUES (?, ?, ?, ?, ?, ?, ?, ?)", page_results
    )
    con.commit()
    
    # Always close the database connection to free resources
    con.close()

def parse_page(url, path):
    """
    Takes in a URL and scrapes for title, author, call_number, material type, book type (form) and year of the books found in the page.
    """
    resp = httpx.get(url, headers=headers, timeout=200)
    # Parse the HTML response using BeautifulSoup
    soup = BeautifulSoup(resp.content, 'html.parser')
    # Locate the div containing search results
    table = soup.find('div', class_='searchresults')
    # Extract all book entries (table rows) from the results
    try:
        books = table.find_all('tr')

        # Check if any books were found on this page
        if len(books) == 0:
            return
        # Process each book and save to database
        else:
            for book in books:
                # Parse individual book data and save to database
                results = parse_book(book)
                save_to_database(path, results)
    except AttributeError:
        # Handle case where search results div is not found
        print("No books found on the page.")
        return None


def parse_code(language, path, code):
    """
    Takes in a DDC code and language and scrapes the books for that code and language. 
    The results are saved to a SQLite database.
    """
    # Set the database file path for this language
    database_path = f'{path}/1_scraped_data/parsed_data_{language}.db' 

    # Record start time for performance tracking
    start = time.time()
    # Build initial URL to check total number of results
    url = build_url(language, 0, code)

    num_res = num_of_results(url)     # Get total number of search results
    num_pages = num_of_pages(num_res) # Calculate number of pages to scrape

    # If no results are found, print a message
    if num_res is None:
        print (f"No results found for {language}")

    # If results are found, scrape the pages
    else:
        print(f"There are {num_res} books to scrape for {code}.")
       

        for i in range(0, num_pages):
            # Build URL for current page (offset by i*100 since each page has 100 results)
            url = build_url(language, i*100, code)
            # Scrape and parse the current page
            parse_page(url, database_path)
            # Display scraping progress to user
            print(f"Page {i+1} of {num_pages} of {code} has been scraped.")
            # Random delay between requests to avoid being blocked by the server
            time.sleep(randint(1, 5))
    # Calculate and display total scraping time
    end = time.time()
    runtime = str(round((end - start) / 60, 2))
    # Report completion time for this DDC code and language combination
    print(f"Time taken to scrape code:{code} for {language} : {runtime} minutes.")


def save_code_scraped(language, path, code):
    """
    Save the code that has been scraped to a csv file.
    If the file does not exist, create it.
    """
    file_path = f"{path}/0_subject_list/scraper_progess_tracker/ddc_codes_scraped_{language}.csv"
    
    df = pd.DataFrame({"DDC": [code]})
    try:
        existing_df = pd.read_csv(file_path)
        updated_df = pd.concat([existing_df, df], ignore_index=True)
    except FileNotFoundError:
        updated_df = df
    updated_df.to_csv(file_path, index=False)


def parse_language(language, path, list_of_codes):
    """
    Takes in a language and scrapes the books for that language for a given list of DDC codes.
    """
    #Start time
    start = time.time()

    # List of DDC codes
    codes = list_of_codes

    for code in codes:
        print(f"Scraping code: {code} for {language}")
        parse_code(language, path, code)
        time.sleep(randint(1, 5))
        save_code_scraped(language, path, code)

    # End time
    end = time.time()
    runtime = str(round((end - start) / 60, 2))
    # Print the time taken to scrape the subject
    print(f"Time taken to {language} : {runtime} minutes.")

def read_table(db_path, table_name):
    """
    Read a table from a sqlite database and return it as a pandas dataframe.
    """
    try:
        with sqlite3.connect(db_path) as conn:
            df = pd.read_sql_query(f"SELECT * FROM {table_name}", conn)
        conn.close()
        return df
    except Exception as e:
        print(f"An error occurred: {e}")
        return None

def progress_update_codes(path, language):
    """
    Update the progress of the codes scraped.
    """
    # Read the complete list of DDC codes
    df_code = pd.read_csv(f"{path}/0_subject_list/tech_ddc_codes_list.csv")
    list_of_codes = df_code['DDC'].tolist()

    try:
        # Read the list of codes that have already been scraped
        codes_scraped =  pd.read_csv(f"{path}/0_subject_list/scraper_progess_tracker/ddc_codes_scraped_{language}.csv")
        codes_scraped = codes_scraped['DDC'].tolist()
        print(f"{len(codes_scraped)} codes have been scraped for {language}.")
    except FileNotFoundError:
        print(f"No codes have been scraped for {language}.")
        codes_scraped = []

    # Find the codes that have not been scraped
    codes_to_scrape = [code for code in list_of_codes if code not in codes_scraped]

    return codes_to_scrape


def scrape_language(language, path):
    """
    Scrape the language for the given list of DDC codes.
    """
    
    # Update list of DDC codes to scrape
    list_of_codes = progress_update_codes(path, language)

    if len(list_of_codes) > 0:
        print(f"Restarting scraper for {language} from DDC code: {list_of_codes[0]}")
        parse_language(language, path, list_of_codes)
    else:
        print(f"All codes for {language} have already been scraped.")

def save_code_list(code_list):
    """
    Save the list of DDC codes to a csv file.
    """
    # Save the code list to a csv file
    code_df = pd.DataFrame(code_list, columns=["DDC"])
    code_df.to_csv("../Data/0_subject_list/tech_ddc_codes_list.csv", index=False)


def main(language_list, code_list, path):
    """
    Main function to run the scraper for each language and DDC code.
    """
    # Save Code List
    save_code_list(code_list)

    # Run the scraper for each language
    for language in language_list:
        print(f"Scraping {language}...")
        scrape_language(language, path)


if __name__ == "__main__":
    # List of languages to scrape
    language_list = [ "Hindi", "Tamil", "Marathi", "Urdu", "Kannada", "Bengali", "English"]

    # List of DDC codes to scrape
    code_list = [600, 601, 602, 603, 604, 605]

    path = "../Data/"

    # Run Main Function
    main(language_list, code_list, path)