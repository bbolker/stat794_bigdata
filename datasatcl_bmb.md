## BMB notes on "Data Science at the Command Line" 2e

I wish that the author showed his examples without the `>` continuation characters on new lines, to make them easier to cut and paste ...

### chapter 1

* OSEMN" loop/web is similar to the "import → tidy → {transform → visualise → model} → communicate" flow from tidyverse [here](https://tidyverse.tidyverse.org/articles/data-science.png) (I guess OSEMN rather than OSEMI is to make it pronounceable like "awesome" ...?)
* debatable whether dimensional reduction is a 'model'?

### chapter 2

* the `-v` argument of `docker run` is of the format `<local directory>:<location within docker container>`. Using `/data` as the location within the container means you have to `cd /data` after you start the container.
* `head -<n>` is a shortcut for `head -n <n>`
* shell function for factorial: not sure why we not to prepend 1 (i.e. `echo 1`)? (i.e., why do we need `1*1*2*3` rather than `1*2*3` to compute 3! ?) Seems to work without it?
* I often use `which` instead of `type`
* typo: Carrol → Carroll
* I usually use `wget` rather than `curl` - they're similar tools, `curl` is more powerful/flexible
* using " CHAPTER" in the `grep` example gets us just the entries from the table of contents, not the chapter headings themselves.
* typo: "that are pass[ed] into it"
* `<` redirection at the beginning of the line seems weird, but I understand the reasoning. Much more standard is `[cmd] <source ...`
* `dseq` isn't well documented. Try "bat `which dseq`"
* as well as command-line file removal being scary because you don't have a graphical interface, `rm` is also **permanent** - it doesn't move things to a recycle bin from which you could retrieve it ("you've got good backups, right?")
* one minor disadvantage with this book is that it can be a little hard to distinguish which tools are general/nearly universal (`mv`, `cp`, etc.), which are from libraries you could install (`csv*` functions), and which are aliases/scripts that the author wrote themselves (e.g. `dseq`). Also, different shells (e.g. `zsh` vs `bash`) are very similar but not identical ...
* for `bash`, see `man bash-builtins`
* `tldr` is nice!

## chapter 3

* you can also use `docker cp` (from outside a container) to copy files in and out of a container (although moving them into a mounted directory is easier). (See [here](https://stackoverflow.com/questions/28302178/how-can-i-add-a-volume-to-an-existing-docker-container) for attaching a directory to an already-running container ...
* I think the etymology of 'curl' might be "see URL"
* typo/grammar: "all the contents [are] immediately printed"
* "you can specify a username and a password as follows with the -u option" (but then nothing is shown?)
* "If the original dataset is very large or [if] it's a collection of many files"
* OpenOffice does has command-line tools for file type conversion (but probably won't be available on a server)
* deprecation warning about float conversion from `in2csv`: "DeprecationWarning: `np.float` is a deprecated alias for the builtin `float`." (might be fixed in later versions)
* not sure why we need `-I` in Queen example ("disable type inference") - for efficiency or ?
* "`sql2csv also support[s] ..."

## chapter 4

* `fc` stands for "fix command"
* I don't like `nano` much. This Docker container doesn't come with `vi`, which is a bit surprising. It is available on most servers. https://www.baeldung.com/linux/vi-nano-command-line-alternative-editors
* `sudo apt update; sudo apt install vim` doesn't work because the Ubuntu version ("hirsute", 21.04) is too old (end-of-life on Jan 20 2022). It was not a "long-term service" (LTS) release. e.g. version 20.04.6 is supported at some level until April 2032 ... https://documentation.ubuntu.com/project/release-team/list-of-releases/ [can we find the Dockerfile and rebuild the container ourselves?]
* more on brace expansion [here](https://unix.stackexchange.com/questions/409065/how-does-curly-brace-expansion-work-in-the-shell)
* remember to *append* new directories to `PATH` rather than resetting it (which will make your current shell instance unusable)
* Python script: weird to depend on remote stopwords URL rather than downloading? (caching?)
* weird solution of fizzbuzz: why not an `if` statement using modulo operator? I guess hard-coding the cycle is marginally faster?
* note type hinting in Python code
* R code should use `if (is.na(word)) n else word` or `if (is.na(word)) return(n); word`
* `display` doesn't work? does [this](https://medium.com/@priyamsanodiya340/running-gui-applications-in-docker-containers-a-step-by-step-guide-335b54472e4b) help? (could save file to a directory that can be seen outside?) (see section 7.4.1 of the book)

## chapter 5

* what is the `-r` flag for `sed` ?
* "if you wanted to uppercase the values in the `day` column in the tips data set" ... but there are no alphabetic characters in that column?
* "comma's" → "commas"
* "csvsql employ[s] SQLite"
* "What if last_name [contained] a comma?" (I had a student named "Lourd's" in a class once ...) also see https://xkcd.com/327/
* "van Beethoven" is bad anyway!
* "that that [you] want to put side by side"
* what is `sed -n '1p;49,54p'` doing in the cvsjoin example? (looking at lines 1 and 49-54 - why?)

## chapter 6

* why `cp` rather than `mv` to Makefile ?
* `xsv` seems to be another CSV tool - why aren't we using the `csvtools` stuff?
* could use line-continuation characters `\` rather than .ONESHELL ?
* why is Figure 6.2 right-to-left?
* does all that stuff really get printed when `make` runs?
* see `make -n`

## chapter 7

* see also https://github.com/eddelbuettel/littler
* "open the image ([tips.png?] in this example)"

## chapter 8

* weird numbering before "The value of this variable" ((3) instead of (2)) ?
* I use https://github.com/sharkdp/fd instead of `find`
* note `make -j <n>` runs `make` in parallel with up to `<n>` concurrent jobs

