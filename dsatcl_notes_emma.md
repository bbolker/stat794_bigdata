# 1 Introduction 

## 1.1 Data Is OSEMN 

* OSEMN: (1) obtaining data, (2) scrubbing data, (3) exploring data, (4) modeling data, and (5) interpreting data 

* BMB: OSEMN loop/web is similar to the "import → tidy → {transform → visualise → model} → communicate" flow from tidyverse [here](https://tidyverse.tidyverse.org/articles/data-science.png)

# 2 Getting started

## 2.1 Getting the Data

1. Download the ZIP file from https://www.datascienceatthecommandline.com/2e/data.zip.
2. Create a new directory. Named mine "dsatcl2e-data" (name from the book)
3. Move the ZIP file to that new directory and unpack it.

## 2.2 Installing the Docker image 

1. Install the image: 
``` 
  docker pull datasciencetoolbox/dsatcl2e
```

2. Test that the image runs:

```
  docker run --rm -it datasciencetoolbox/dsatcl2e
```

But there are no contents inside of it... 

3. Run the image with a *volume*. To get data in and out of the container (i.e., the data we just downloaded), add a volume (i.e., a local directory gets mapped to a directory inside the container). Adding a volume is done like this: 

```
  docker run --rm -it -v "$(pwd)":/data datasciencetoolbox/dsatcl2e-data
```

* Comment from BMB: the -v argument of docker run is of the format <local directory>:<location within docker container>. Using /data as the location within the container means you have to cd /data after you start the container.
* Emma: how does the volume actually allow us to do this (move files in and out)? 

4. So after starting the docker with a volume: 

```
  cd /data 
```

Now we are in the image/container and the data we need is also there!


# 3 Obtaining Data

## 3.1 Overview 

  * Copy local files to the Docker image
  * Download data from the Internet
  * Decompress files
  * Extract data from spreadsheets
  * Query relational databases
  * Call web APIs

1. Navigate into the 'ch03' directory in the data directory

```
  cd data/ch03
```

2. Check all the files we need are there

```
  l
```

##  3.2 Copying Local Files to the Docker Container 
 * This sections talks about copy local files to the container... but my container just has all the local files already in it...
 * I'm skipping this... it's just the command 'cp [local files] [directory to be moved to]'
 * If I start the image with a volume in the directory the data is in, why is the data already there? did it get automatically copied over...? 

##  3.3 Downloading from the Internet 

### 3.3.1 Introducing curl
* Note from BMB: wget also works... curl is more powerful?

* Curl:
  * downloads the data and, by default, prints it to standard output
  *  doesn’t do any interpretation, but luckily other command-line tools can be used to process the data further
  * Example: 
  
  ```
    curl "https://en.wikipedia.org/wiki/List_of_windmills_in_the_Netherlands" | trim
  ```
  
  * by default, curl outputs a progress meter that shows the download rate and the expected time of completion
  * this output isn’t written to standard output, but a separate channel: standard error
  * information can be useful when downloading very large files, the -s option can silence this output
  * example:
  
  ```
    curl -s "https://en.wikipedia.org/wiki/List_of_windmills_in_Friesland" | trim
  ```

###  3.3.2 Saving

* You can let curl save the output to a file by adding the -O option. The filename will be based on the last part of the URL.

```
  curl -s "https://en.wikipedia.org/wiki/List_of_windmills_in_Friesland" -O
```

* look at files to see the new file

```
  l
```

* If you don’t like that filename then you can use the -o option together with a filename or redirect the output to a file yourself:

```
  curl -s "https://en.wikipedia.org/wiki/List_of_windmills_in_Friesland" > friesland.html
```

### 3.3.4 Following Redirects 

* Accessing a shortened URL (i.e., http://bit.ly/ or http://t.co/) -->  your browser automatically redirects to the correct location
  *  Curl, however, needs the -L or --location option in order to be redirected
  *  examples of what happens without -L:
  
  ```
    curl -s "https://bit.ly/2XBxvwK"
  ```
  ```
    curl -s "https://youtu.be/dQw4w9WgXcQ"
  ```
* the -I or --head option allows curl to fetches only the HTTP header of the response: 

```
  curl -sI "https://youtu.be/dQw4w9WgXcQ" | trim
```

##  3.4 Decompressing Files 
* Command-line tools for decompressing files:
  * tar (tar.gz) 
  * unzip (.zip)
  * unrar (.rar)
* Decompress the logs file: (dont run this next one though!!)

```
  tar -xzf logs.tar.gz
```

* flags:
  * -x: extract files from an archive
  * -z: use the gzip as the decompression algorithm
  * -f: use file logs.tar.gz

* Since we’re not yet familiar with this archive, examine its contents (done it -t instead of -x): 

```
  tar -tzf logs.tar.gz | trim
```

* archive contains a lot of files --> In order to keep the current directory clean, create a new directory using mkdir and extract those files there using the -C option: 

```
  mkdir logs
  tar -xzf logs.tar.gz -C logs
```

* verify the number of files and some of their contents:

```
  ls logs | wc -l
  cat logs/* | trim
``` 

* unpack looks at the extension of the file that you want to decompress, and calls the appropriate command-line tool. Now, in order to decompress this same file, you would run:

```
  unpack logs.tar.gz
```

* Emma: why not just use unpack all the time? 

##  3.5 Converting Microsoft Excel Spreadsheets to CSV 
* CSVkit: tools used in this section (in2csv, csvgrep, and csvlook) are part of this package (?)
* in2csv: command-line tool that converts Microsoft Excel spreadsheets to CSV files
*  CSV stands for comma-separated values (didn't know that!)
* Yakov Shafranovich defines the CSV format according to the following three points:
  1. Each record is located on a separate line, delimited by a line break (␊). Take, for example, the following CSV file with crucial information about the Teenage Mutant Ninja Turtles:

  ```
    bat -A tmnt-basic.csv ➊
  ```
  * The -A option makes bat show all non-printable characters like spaces, tabs, and newlines.
    
  2. The last record in the file may or may not have an ending line break. For example:
  
  ```
    bat -A tmnt-missing-newline.csv
  ```
  
  3. There may be a header appearing as the first line of the file with the same format as normal record lines. This header will contain names corresponding to the fields in the file and should contain the same number of fields as the records in the rest of the file. For example:
  
  ```
    bat -A tmnt-with-header.csv
  ```
* CSV not too readable: csvlook is a tool that data can be piped to and nicelt formatted:

```
  csvlook tmnt-with-header.csv
```

```
  csvlook tmnt-basic.csv
```

* If there is no header, add -H flag:

```
  csvlook -H tmnt-missing-newline.csv
```

* demonstrate in2csv using a spreadsheet that contains the 2000 most popular songs according to an annual Dutch marathon radio program Top 2000. To extract its data, invoke in2csv:

```
  curl https://cms-assets.nporadio.nl/npoRadio2/TOP-2000-2020.xlsx > top2000.xlsx
```

```
  in2csv top2000.xlsx | tee top2000.csv | trim
```

```
  csvgrep top2000.csv --columns ARTIEST --regex '^Queen$' | csvlook -I
```

* value after --regex options is a regular expression (or regex) (special syntax for defining patterns)

* Notes:
  * format of the file is automatically determined by the extension, .xlsx in this case -- need to specify the format explicitly when piping to in2csv
  * spreadsheet can contain multiple worksheets. in2csv extracts, by default, the first worksheet. To extract a different worksheet, need to pass the name of worksheet to the --sheet option (can use the --names option, which prints the names of all the worksheets, if unsure about name):
  ```
    in2csv --names top2000.xlsx
  
## 3.6 Querying Relational Databases

* relational databases: MySQL, PostgreSQL, and SQLite
* some provide a command-line tool or a command-line interface, while others do not -- not very consistent when it comes to their usage and output
* sql2csv: command-line tool which is part of the CSVkit suite
  * works with many different databases (MySQL, Oracle, PostgreSQL, SQLite, Microsoft SQL Server, and Sybase) through a common interface
  * output of sql2csv is in CSV format
* obtain data from relational databases by executing a SELECT query on them
* sql2csv needs two arguments:
  1. --db: specifies the database URL, of which the typical form is: dialect+driver://username:password@host:port/database
  2. --query: contains the SELECT query.
  * Example: given an SQLite database that contains the standard datasets from, select all the rows from the table mtcars and sort them by the mpg column:

``` 
  sql2csv --db 'sqlite:///r-datasets.db' --query 'SELECT row_names AS car, mpg FROM mtcars ORDER BY mpg' | csvlook
```

* that SQLite database is a local file, so there is no need to specify any username, password or host -- see next section!

## 3.7 Calling Web APIs
* most web APIs return data in a structured format (JSON or XML)
* Having data in a structured form has the advantage that the data can be easily processed by other tools (jq)
* Example:
* 
```
  curl -s "https://anapioficeandfire.com/api/characters/583" | jq '.'
```

### 3.7.1 Authentication
* Some web APIs require authentication 
* call the following and get an error:

```
  curl -s "http://newsapi.org/v2/everything?q=linux" | jq .
```

* add authentication:

```
  curl -s "http://newsapi.org/v2/everything?q=linux&apiKey=$(<secret_apikey.txt)" |
  jq '.' | trim 30
```

* I stored my API key in the file 'secret_apikey.txt'

### 3.7.2 Streaming APIs
* Some web APIs return data in a streaming manner (once you connect to it, the data will continue to pour in, until the connection is closed)
* take a 10 second sample of one of Wikimedia’s streaming APIs, for example:

```
  curl -s "https://stream.wikimedia.org/v2/stream/recentchange" |
  sample -s 10 > wikimedia-stream-sample
```

* sample: command-line tool used to close the connection after 10 seconds
* the connection can also be closed manually by pressing Ctrl-C to send an interrupt
* output is saved to a file wikimedia-stream-sample. take a peek using trim:

```
  < wikimedia-stream-sample trim
```

* With sed and jq, scrub this data to get a glimpse of the changes happening on the English version of Wikipedia:

```
  < wikimedia-stream-sample sed -n 's/^data: //p' | 
  jq 'select(.type == "edit" and .server_name == "en.wikipedia.org") | .title'
```
* This sed expression only prints lines that start with data: and prints the part after the semicolon, which happens to be JSON.
* This jq expression prints the title key of JSON objects that have a certain type and server_name


# 4 Creating Command-line Tools 
## 4.1 Overview 
* Convert one-liners into parameterized shell scripts
* Turn existing Python and R code into reusable command-line tools

* Redirect to this directory:

```
  cd ..
  cd ch04
```

##  4.2 Converting One-liners into Shell Scripts 

* Get the top most frequent words used in a piece of text (Alice’s Adventures in Wonderland by Lewis Carroll)

``` 
  curl -sL "https://www.gutenberg.org/files/11/11-0.txt" | trim
```

* The following sequence of tools or pipeline should do the job:

```
  curl -sL "https://www.gutenberg.org/files/11/11-0.txt" | 
  tr '[:upper:]' '[:lower:]' | 
  grep -oE "[a-z\']{2,}" | 
  sort | 
  uniq -c | 
  sort -nr | 
  head -n 10
```

step-by-step explanation of the above command: \n
* curl: Downloading an ebook using curl
* tr: Converting the entire text to lowercase using tr
* grep: Extracting all the words using grep48 and put each word on separate line
* sort: Sort these words in alphabetical order using sort
* uniq: Remove all the duplicates and count how often each word appears in the list using uniq
* sort: Sort this list of unique words by their count in descending order using sort
* head: Keep only the top 10 lines (i.e., words) using head \n

* don't include stopwords (with grep we can filter out the stopwords!):

```
  curl -sL "https://www.gutenberg.org/files/11/11-0.txt" |
  tr '[:upper:]' '[:lower:]' |
  grep -oE "[a-z\']{2,}" |
  sort |
  grep -Fvwf stopwords | 
  uniq -c |
  sort -nr |
  head -n 10
```

*  -f: obtain the patterns from a file (stopwords in our case), one per line
*   -F: interpret those patterns as fixed strings with
*   -w: select only those lines containing matches that form whole words with
*   -v: select non-matching lines with

*   How can we make this an executable command? 

### 4.2.1 Step 1: Create File 
* builtin fc (fix command): allows you to fix or edit the last-run command

```
  fc
```
* fc invokes the default text editor, which is stored in the environment variable EDITOR. In the Docker container, this is set to nano, a straightforward text editor.

* give this temporary file a proper name by pressing Ctrl-O, removing the temporary filename, and typing top-words-1.sh:
* file extension .sh: shell script.
  * command-line tools *don’t need* to have an extension
* confirm the contents of the file:

```
  bat top-words-1.sh
```
* use bash to interpret and execute the commands in the file:

```
  bash top-words-1.sh
```

* because the file cannot be executed on its own, it’s not yet a real command-line tool...
  
### 4.2.2 Step 2: Give Permission to Execute

* The reason we cannot execute our file directly is that we don’t have the correct access permissions
* to compare differences between steps, copy the file to top-words-2.sh using cp -v top-words-{1,2}.sh
* chmod: command line took that changes the access permissions of a file (stands for change mode)

```
  cp -v top-words-{1,2}.sh
```
```
  chmod u+x top-words-2.sh
```

* u+x: (1) u indicates that we want to change the permissions for the user who owns the file, which is you, because you created the file; (2) + indicates that we want to add a permission; and (3) x, which indicates the permissions to execute.
* look at permissions: 

 ```
  l top-words-{1,2}.sh
```

* execute the file as follows:

```
  ./top-words-2.sh
```

* following command outputs error: trying to  execute a file for which you don’t have the correct access permissions

```
  ./top-words-1.sh
```

### 4.2.3 Step 3: Define Shebang

* shebang: a special line in the script that instructs the system which executable it should use to interpret the commands

```
  cp -v top-words-{2,3}.sh
```
 
* Go ahead and type #!/usr/bin/env/bash and press Enter. When you’re ready, press Ctrl-X to save and exit.
* confirm what top-words-3.sh looks like:

```
  bat top-words-3.sh
```

* if the bash (or python) executables are installed in a different location than /usr/bin, then the script does not work anymore
  * better to use the form above (!/usr/bin/env) because the env executable is aware where bash and python are installed
  * i.e., using env makes your scripts more portable.
  
### 4.2.4 Step 4: Remove Fixed Input

* want to obtain the top 10 most-used words from another e-book -- the input data is fixed within the tools itself
* assume that the user of the command-line tool will provide the text
* remove the curl command from the script. Here is the updated script named top-words-4.sh:

```
  cp -v top-words-{3,4}.sh
```

```
  sed -i '2d' top-words-4.sh
```
 
```
  bat top-words-4.sh
```

```
  curl -sL 'https://www.gutenberg.org/files/11/11-0.txt' | ./top-words-4.sh
```

```
  curl -sL 'https://www.gutenberg.org/files/12/12-0.txt' | ./top-words-4.sh
```

```
  man bash | ./top-words-4.sh
```

### 4.2.5 Step 5: Add Arguments

* it would be very useful to allow for different values for the head command (i.e. how many words do you want returned)
*  below shows what the file top-words-5.sh looks like:

```
  bat top-words-5.sh
```
* variable NUM_WORDS is set to the value of $1, which is a special variable in Bash: holds the value of the first command-line argument passed to the command-line tool.
* note that in order to use the value of the $NUM_WORDS variable, need to put a dollar sign in front of it

* see the top 20 most-used words of our text, we would invoke the command-line tool as follows:

```
  curl -sL "https://www.gutenberg.org/files/11/11-0.txt" > alice.txt
```
* if the user does not specify a number, then the script will show the top 10 most common words:

```
  < alice.txt ./top-words-5.sh
```

### 4.2.6 Step 6: Extend Your PATH

* ensure that you can execute your command-line tools from everywhere
* to accomplish this, Bash needs to know where to look for your command-line tools
* In a fresh Docker container, the PATH looks like this:

```
  echo $PATH
```

* print it as a list of directories by translating the colons to newlines:

```
  echo $PATH | tr ':' '\n'
```

* to change the PATH permanently, edit the .bashrc or .profile file located in your home directory. If you put all your custom command-line tools into one directory, say, ~/tools, then you only change the PATH once. Now, you no longer need to add the ./, but you can just use the filename. Moreover, you do no longer need to remember where the command-line tool is located.

```
  cp -v top-words{-5.sh,}
```

```
  export PATH="${PATH}:/data/ch04"
```
 
```
  echo $PATH
```

```
  curl "https://www.gutenberg.org/files/11/11-0.txt" | ./top-words 10
```

## 4.3 Creating Command-line Tools with Python and R
### 4.3.1 Porting The Shell Script 
* I'm skipping pyton!
* look at R code we want to makea command line tool:

```
  bat top-words.R
```

check both implementations (i.e., Bash and R) return the same top 5 words with the same counts:

```
  time < alice.txt ./top-words 5
```

```
  time < alice.txt ./top-words.R 5
```

### 4.3.2 Processing Streaming Data from Standard Input
* R read the complete standard input at once in the previous code snippet
* on the command line, most tools pipe data to the next command-line tool in a streaming fashion
* there are a few command-line tools which require the complete data before they write any data to standard output (e.g., sort)
* the pipeline is blocked by such command-line tools
* if input data is a non-stop stream, such blocking command-line tools are useless
* R supports processing streaming data -- can apply a function on a line-per-line basis
* example that demonstrate how this works in R:
  * the R tool solves the 'Fizz Buzz' problem, which is defined as follows: Print the numbers from 1 to 100, except that if the number is divisible by 3, instead print “fizz”; if the number is divisible by 5, instead print “buzz”; and if the number is divisible by 15, instead print “fizzbuzz”:

  ```
    bat fizzbuzz.R
  ```
  
  ```
    seq 30 | fizzbuzz.R | column -x
  ```
  
* Emma: this topic seems super useful -- is this a good practice to have, or does creating your own command line tools *too much* cause problems?
  
# 5 Scrubbing data

## 5.1 Overview
* convert data from one format to another
* Apply SQL queries directly to CSV
* Filter lines
* Extract and replace values
* Split, merge, and extract columns
* Combine multiple files

* Redirect to data directory:

```
  cd ..
  l
```

##  5.2 Transformations, Transformations Everywhere 
* get the first 100 items of a fizzbuzz sequence (cf. Chapter 4)
* visualize how often the words fizz, buzz, and fizzbuzz appear using a bar chart
  
1. obtain the data by generating the sequence and write it to fb.seq:
```
  seq 100 |
 ./ch04/fizzbuzz.py | 
 tee fb.seq | trim
```

2. then you use grep to keep the lines that match the pattern fizz or buzz and count how often each word appears using sort and uniq (-c adds counts)
```
  grep -E "fizz|buzz" fb.seq | 
  sort | uniq -c | sort -nr > fb.cnt 
 
  bat -A fb.cnt
```

3. next step would be to visualize the counts using rush. However, since rush expects the input data to be in CSV format, this requires a less subtle transformation first. awk can add a header, flip the two fields, and insert commas in a single incantation:
```
  < fb.cnt awk 'BEGIN { print "value,count" } { print $2","$1 }' > fb.csv

  bat fb.csv

  csvlook fb.csv
```

4. now use rush to create a bar chart
```
  rush plot -x value -y count --geom col --height 2 fb.csv > fb.png
```
* 'display fb.png' doesn't work for me... I just opened the png without the command line...

## 5.3 Plain text
### 5.3.1 Filtering Lines
* The first scrubbing operation is filtering lines
  
#### 5.3.1.1 Based on Location

```
  seq -f "Line %g" 10 | tee lines
```
* print the first 3 lines using either head, sed, or awk (NR refers to the total number of input records seen so far):

```
  < lines head -n 3
  < lines sed -n '1,3p'
  < lines awk 'NR <= 3'
```

* print the last 3 lines using tail:

```
   < lines tail -n 3
```

* removing the first 3 lines goes as follows:

```
  < lines tail -n +4
  < lines sed '1,3d'
  < lines sed -n '1,3!p'
```


* removing the last 3 lines can be done with head:

```
  < lines head -n -3
```

* print specific lines using a either sed, awk, or a combination of head and tail. print lines 4, 5, and 6:

```
  < lines sed -n '4,6p'
  < lines awk '(NR>=4) && (NR<=6)'
  < lines head -n 6 | tail -n 3
```

* print odd lines with sed by specifying a start and a step, or with awk by using the modulo operator:

```
  < lines sed -n '1~2p'
  < lines awk 'NR%2'
```

* printing even lines works in a similar manner:

```
  < lines sed -n '0~2p'
  < lines awk '(NR+1)%2'
```

* these examples start with the smaller-than sign (<) followed by the filename: this allows you to read the pipeline from left to right
  
#### 5.3.1.2 Based on a Pattern
* use grep!

```
  < alice.txt grep -i chapter
```
* -i: case-insensitive

* I got bored here... this feels like maybe something to skip for now...

# 6 Project Management with Make
"I hope that by now you have come to appreciate that the command line is a very convenient environment for working with data." Young person question: why do we not learn how to use the terminal/command line properly prior to grad/professional work/did old people (not actually old, but not like 20) (I swear I'm not calling you old Ben...) also just have to learn it on their own? 

## 6.1 Overview

* Defining your workflow with a Makefile.
* Thinking about your workflow in terms of input and output dependencies.
* Running tasks and building targets

* Emma: when would you use this? 

* change into correct directory:
```
  cd ..
  cd ch06
  l
```

## 6.2 Introducing Make

* make organizes command execution around data and its dependencies
  * your data processing steps are formalized in a separate text file (a workflow), and each step may have inputs and outputs
  * make automatically resolves their dependencies and determines which commands need to be run and in which order
* when you have an SQL query that takes ten minutes, it only has to be executed when the result is missing or when the query has changed afterwards
* if you want to (re-)run a specific step, make only re-runs the steps on which that step depends -- saves time

## 6.3 Running Tasks

* by default, make searches for a configuration file called Makefile in the current directory. It can also be named makefile (lower case), but book recommends calling your file Makefile because it’s more common and that way it appears at the top of a directory listing
* normally you would only have one configuration file per project
* because this chapter discusses many different ones, each of them a different filename with the .make extension. * start with the following Makefile:

```
  bat -A numbers.make
```

* contains one target called numbers. A target is like a task. It’s usually the name of a file you’d like to create but it can also be more generic than that. The line below, seq 7, is known as a rule. Think of a rule as a recipe; one or more commands that specify how the target should be built.
* whitespace in front of the rule is a single tab character. make is picky when it comes to whitespace. Beware that some editors insert spaces when you press the TAB key, known as a soft tab, which will cause make to produce an error. The following code illustrates this by expanding the tab to eight spaces:

```
  < numbers.make expand > spaces.make
  bat -A spaces.make
```

```
  make -f spaces.make
```
* -f: short for the --makefile option, need to add because the configuration file isn’t called Makefile
```
  rm spaces.make
```
* rename the appropriate file to Makefile because that matches real-world use more closely. So, run make:

```
  cp numbers.make Makefile
```

```
  make
```

* Then we see that make first prints the rule itself (seq 7), and then the output generated by the rule. This process is known as building a target. If you don’t specify the name of a target, then make will build the first target specified in the Makefile. In practice though, you’ll most often be specifying the target you’d want to build:

```
  make numbers
```

* example of make file with targets: 
```
  bat tasks.make
```
* note the extra dollar sign in front of $(pwd). This is needed because make uses a single dollar sign to refer to various special variables

## 6.4 Building, For Real 

* modify the Makefile such the output of the rule is written to a file numbers

```
  cp numbers-write.make Makefile
```
 
```
  bat Makefile
```

```
  make numbers
```

```
  bat numbers
```

* now we can say that make is actually building something
* if we run it again, we see that make reports that target numbers is up-to-date

```
  make numbers
```

* In make, it’s all about files -- but make only cares about the name of the target. It does not check whether a file of the same name actually gets created by the rule. If we were to write to a file called nummers, which is Dutch for “numbers,” and the target was still called numbers, then make would always build this target. Vice versa, if the file numbers was created by some other process, whether automated or manual, then make would still consider that target up-to-date.

* avoid some repetition by using the automatic variable $@, which gets expanded to the name of the target:

```
  cp numbers-write-var.make Makefile
```
 
```
  bat Makefile
```

* verify that this works by removing the file numbers and calling make again:

```
  rm numbers
```

```
  make numbers
```

```
  bat numbers
```

## 6.5 Adding Dependencies 

* what about targets that *do not* exist in isolation?
* in a typical data science workflow, many steps depend on other steps -- to properly talk about dependencies in a Makefile, let’s consider two tasks that work with a dataset about Star Wars characters.

* Here’s an excerpt of that dataset:

```
  curl -sL 'https://raw.githubusercontent.com/tidyverse/dplyr/master/data-raw/starwars.csv' |
  xsv select name,height,mass,homeworld,species |
  csvlook
```

* The first task computes the ten tallest humans:

```
  curl -sL 'https://raw.githubusercontent.com/tidyverse/dplyr/master/data-raw/starwars.csv' |
  grep Human | 
  cut -d, -f 1,2 | 
  sort -t, -k2 -nr | 
  head
```
step-by-step explanation of the above command: 
* Only keep lines that contain the pattern Human.
* Extract the first two columns.
* Sort the lines by the second column in reverse numeric order.
* By default, head prints the first 10 lines. You can override this with the -n option.

```
  curl -sL 'https://raw.githubusercontent.com/tidyverse/dplyr/master/data-raw/starwars.csv' |
  rush plot --x height --y species --geom boxplot > heights.png
```

* put these two tasks into a Makefile. Instead of doing this incrementally, the book first shows what a complete Makefile looks like and then explains all the syntax step by step.

```
  cp starwars.make Makefile
  bat Makefile
```

Makefile step by step:
1. The first three lines are there to change some default settings related to make itself:
  * All rules are executed in a shell, which by default, is sh. With the SHELL variable we can change this to another shell, like bash. This way we can use everything that Bash has to offer such as for loops.
2. By default, every line in a rule is sent separately to the shell. With the special target .ONESHELL we can override this so the rule for target top10 works.
3. The .SHELLFLAGS line makes Bash more strict, which is considered a best practice. For example, because of this, the pipeline in the rule for target top10 now stops as soon as there is an error.

```
  make
```

* Emma: confused on this chapter... I'm clear on how the shell knows what to do when "make" or "makefile" is called... how is this better than simply creating and executing our own .sh files like in chapter 4? 
