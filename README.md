# Introduction
Subtitle-converter is a project to improve the compatibility of subtitle files present in .MKV (Matroska) files.<br>
It will convert files of different formats to .SRT, in order to allow the application to change the formatting of these files at the last level (player).

<br>

# How it works
The script runs in an Debian docker (light), the dependencies are installed when building the docker.<br>
A volume (data) is mounted on the host, this volume points to the root folder where the .mkv files are located.<br>
It will then retrieve the paths of all the .mvk files, and it will search file by file for subtitle files in a format other than format other than .srt<br>
It will convert them and multiplex the result.

<br>

# How to use it
Just clone this repo.
```
git clone https://github.com/simon-verbois/subtitle-converter.git
```

Then, change the path in the `docker-compose.yml` file to add your path from where your 
add your path to where your .mkv files are and finish by building the 
docker.
```
docker-compose build
```

And run it.
```
docker-compose up -d
```

<br>

# Testing
To test the script on your computer directly, you need to install the dependencies in the following point.<br>
And create a data and sc_tmp folder at the root of the project (already in the .gitignore).<br>
You can then run the script in /src

<br>

# Dependencies
ffmpeg<br>
mkvtoolnix<br>
python3<br>
python3-langdetect
