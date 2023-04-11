FROM ubuntu:latest
RUN apt-get update && apt-get install -y ffmpeg mkvtoolnix python3
RUN python3 -m pip install langdetect
RUN mkdir /sc_tmp
COPY ./src/subtitle-converter.sh /
CMD ["/bin/bash", "/subtitle-converter.sh"]