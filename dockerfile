FROM debian:latest

RUN apt-get update && apt-get install -y ffmpeg mkvtoolnix python3 python3-pip && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN python3 -m pip install langdetect

RUN mkdir -p /var/tmp/subtitle-converter /var/opt/subtitle-converter

COPY ./src/subtitle-converter.sh /
COPY ./src/_settings.ini /var/opt/subtitle-converter/settings.ini 

CMD ["/bin/bash", "/subtitle-converter.sh"]
