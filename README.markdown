# Automated promo code submitter for Estrella Damm's Sónar 2013 contest

This is no-guarantees, probably-full-of-bugs-but-good-enough, script to automate submission of promo codes to [Estrella Damm's Sónar 2013 contest](http://concertinauguralsonar.estrelladamm.com).

## How to use

First you need to make an account at [the contest website](http://concertinauguralsonar.estrelladamm.com). Then you can use your account with the script:

    ruby submit_promo_codes.rb

When you run it, you'll be prompted to choose whether to use it interactively or to process a promo code input file.

### Using it interactively

Using the script interactively looks like this:

    ruby .\submit_promo_codes.rb
    Please enter a number, one of:
    1. Log in
    2. Submit promo code
    3. Get stats
    4. Exit
    5. Operate with file
    Your choice:
    5
    Enter relative path to file:
    sample_input.txt
    Login unsuccessful
    Code accepted? N - Entries: 0 - Codes: 0/30

### Operating with a file

If you choose to use the script with an input file, the file needs to have the following format:

* First line has username
* Second line has password
* Following lines promo codes, one per line

For example:

    username@example.org
    example password
    DEADBEEF
    AAAAAAAA
    NOTACODE

## Overview

As part of the [S&oacute;nar 2013 music festival](http://www.sonar.es/en/2013/) [Estrella Damm](http://en.wikipedia.org/wiki/Estrella_Damm) put on a contest to give away free entries to the [Pet Shop Boys](http://www.sonar.es/en/2013/prg/ar/pet-shop-boys_141) concert on the second night of the music festival.

The contest consists of collecting 30 the stickers from bottles of Estrella (medium size, no [quintos](http://www.nytimes.com/fodors/top/features/travel/destinations/europe/spain/barcelona/fdrs_feat_23_11.html)) in order to *participate in the drawing an entry to the concert*. Each sticker contains an unique pormo code on the back that needs to be entered on the [contest website](http://concertinauguralsonar.estrelladamm.com/).

![An used Estrella Damm code for the Pet Shop Boys concert](README_files/used_estrella_damm_code_for_the_pet_shop_boys_concert.jpg)

When you have this many stickers ...

![Way too many used Estrella Damm codes for the Pet Shop Boys concert](README_files/way_too_many_used_estrella_damm_code_for_the_pet_shop_boys_concert.jpg)

... it's worthwhile trying to find a way to automate the process.

An effective way to do this manually is to go through each sticker and copy the promo code into a spreadsheet, then once you have 30 of them, copy and paste each one into the submission form. This allows us to mark a promo code as invalid and later check if there was a typo with it.

This is boring, so I wrote this script to automate it.

## Requirements

You need to have the excellent [HTTParty gem](https://github.com/jnunemaker/httparty) installed.

## Contact
You can reach me at <abraao@alourenco.com>, [@abelourenco](https://twitter.com/abelourenco). You can visit my website at <http://www.alourenco.com>.