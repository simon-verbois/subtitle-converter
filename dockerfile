FROM debian:latest

RUN apt-get update && apt-get install -y ffmpeg mkvtoolnix python3 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN python3 -m pip install langdetect

RUN mkdir /var/tmp

COPY ./src/subtitle-converter.sh /
COPY ./config/settings.ini /

CMD ["/bin/bash", "/subtitle-converter.sh"]
