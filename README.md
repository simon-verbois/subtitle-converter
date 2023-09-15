# Introduction
Subtitle-converter is a project to improve the compatibility of subtitle files present in .MKV (Matroska) files.<br>
It will convert files of different formats to .SRT, in order to allow the application to change the formatting of these files at the last level (player).<br>
This script has been created to work with <a href="https://www.filebot.net/" target="_blank">filebot</a> (for PGS and VOSUB only).<br>
Furthermore, the conversion of subtitle files (SUP and SUB) to SRT format saves a lot of storage (+-25MB -> 100kb, depending on the file).

<br>

# How it works
The script runs in an Debian docker (light), the dependencies are installed when building the docker.<br>
A volume (data) is mounted on the host, this volume points to the root folder where the .mkv files are located.<br>
It will then retrieve the paths of all the .mvk files, and it will search file by file for subtitle files in a format other than format other than .srt<br>
It will convert them and multiplex the result.

<br>

# Actual capabilities
- [x] ASS
- [x] SRT
- [x] USF
- [ ] SUP
- [ ] SUB

<br>

# How to use it
Clone this repository.
```
git clone https://github.com/simon-verbois/subtitle-converter.git
```

Custom `docker-compose.yml` and `.env` files, include the path of the folder where your .mkv files are located, and proceed to build the docker.
Build, then start the container.
```
docker-compose up --build -d
```

<br>

# Testing
To test the script on your computer directly, you need to install the dependencies in the following point.<br>
And create a <b>./data</b> and <b>/var/tmp/subtitle-converter</b> folders.<br>

<br>

# Dependencies
ffmpeg<br>
mkvtoolnix<br>
python3<br>
python3-langdetect


## Star History
[![Star History Chart](https://api.star-history.com/svg?repos=usememos/memos&type=Date)](https://star-history.com/#usememos/memos&Date)
