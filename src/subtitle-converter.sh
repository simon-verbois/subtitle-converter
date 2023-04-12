#!/bin/bash

ConvertSubtitles(){
    if [[ "$format" == "pgs" ]]; then
        # convert .sub to .srt
        #rm -f $tmp_folder/$filename-$cleaned_track_id.sup
        echo > /dev/null
    else
        ffmpeg -loglevel 0 -i $tmp_folder/$filename-$cleaned_track_id.shit -y -f srt $tmp_folder/$filename-$cleaned_track_id.srt
        rm -f $tmp_folder/$filename-$cleaned_track_id.shit
    fi
}

CleanFile(){
    mkvmerge -q -o $mkv_file-new.mkv --no-subtitles $mkv_file
}

AddSubtitles(){
    srt_files=$(find $tmp_folder -name "$filename*.srt" -type f)
    IFS=$'\n'
    for srt_file in $srt_files; do
        ID=$(echo $srt_file | rev | cut -d'-' -f 1 | rev | cut -d'.' -f 1)
        language=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $ID)" -A 10 | grep "Language:" | awk '{print $4}')
        name=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $ID)" -A 10 | sed -n 's/.*Name: \(.*\)/\1/p')

        if [[ -z "$language" ]]; then
            language="$pref_language"
        fi
        if [[ -z "$name" ]]; then
            name="$pref_language_full"
        fi
        
        content=$(cat "$srt_file" | awk '{gsub(/<[^>]*>/,"")};1' | awk '!/^[0-9]+$/ && !/^[0-9]+:[0-9]+:[0-9]+,[0-9]+ --> [0-9]+:[0-9]+:[0-9]+,[0-9]+$/' | awk '{gsub(/{.*}/,"")};1' | sed '/^$/d')
        langue=$(echo "$content" | python3 -c "from langdetect import detect; import sys; print(detect(sys.stdin.read()))")

        if [[ "$langue" != "$pref_language" ]]; then
            Logger "(DEBUG) Remove $srt_file because language is $langue" "debug"
            rm -f $srt_file
        else
            Logger "(DEBUG) Add $srt_file ($langue) to $mkv_file-sub.mkv" "debug"
            mkvmerge -q -o "$mkv_file-sub.mkv" "$mkv_file-new.mkv" --language 0:$language --sub-charset 0:UTF-8 --track-name 0:"$name" "$srt_file"

            mv -f "$mkv_file-sub.mkv" "$mkv_file-new.mkv"
            rm -f $srt_file
        fi
    done
}

ExtractSubtitles(){
    filename=$(basename -s .mvk "$mkv_file")
    tracks=""
    tracks=$(mkvmerge -i "$mkv_file" | grep "subtitles")

    toclean="false"
    reason="Already cleaned"
    IFS=$'\n'
    for track in $tracks; do
        # Get track information
        ID=$(echo "$track" | awk '{print $3}' | tr -d ":")
        language=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $ID)" -A 10 | grep "Language:" | awk '{print $4}')
        language_forced=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $ID)" -A 10 | grep -i "forced" | grep -v -i "name")

        if [[ "$track" == *"PGS"* ]]; then
            # Skip PGS (not yet supported)
            toclean="false"
            reason="PGS detected"
            format="pgs"
            break
        fi
        if [[ -z "$track" ]]; then
            # Skip file without subtitle
            toclean="false"
            reason="No subtitles"
            break
        fi
        if [[ "$track" != *"SRT"* ]]; then
            # Go if contains at least one track other than srt
            toclean="true"
            format="good"
            break
        fi
        if [[ "$language" != *"$pref_language"* ]]; then
            # Go if contains a subtitle track other than the pref language
            toclean="true"
            format="good"
            break
        fi
        if [[ -z "$language" ]]; then
            # Go if contains a subtitle track without language metadata
            toclean="true"
            format="good"
            break
        fi
    done

    if [[ "$toclean" == "true" ]]; then
        Logger "(INFO) Start converting subtitles for : $mkv_file"
        for track in $tracks; do
            cleaned_track_id=$(echo $track | awk '{print $3}' | sed 's/://g')
            if [[ "$format" == "pgs" ]]; then
                # Extract .sup file (PGS)
                #ffmpeg -loglevel 0 -i "$mkv_file" -map 0:s:$cleaned_track_id -scodec copy $tmp_folder/$filename-$cleaned_track_id.sup
                echo > /dev/null
            else
                mkvextract tracks "$mkv_file" $cleaned_track_id:$tmp_folder/$filename-$cleaned_track_id.shit > /dev/null
            fi
            ConvertSubtitles
        done

        Logger "(INFO) Cleaning old subtitles tracks for : $mkv_file"
        CleanFile

        Logger "(INFO) Adding subtitles to : $mkv_file"
        AddSubtitles

        mv "$mkv_file-new.mkv" "$mkv_file"
    else
        Logger "(DEBUG) Skip : $filename ($reason)" "debug"
    fi
}

ScanFolders(){
    mkv_files=$(find "./data" -name "*.mkv" -type f)
    IFS=$'\n'
    for mkv_file in $mkv_files; do
        ExtractSubtitles
        Logger "(INFO) Complete : $mkv_file"
    done

    Logger "(INFO) Everythings is done"
    printf '%s\n' '------------------------------------'
    Main
}

Logger() {
    local -r log_date="[$(date +'%d-%m-%Y|%H:%M:%S')]"

    if [[ "$2" != "debug" || "$debug" == "True" ]]; then
        printf '%s\n' "$log_date $1"
    fi
}


Main(){
    lockfile="$tmp_folder/subtitle-converter.lock"
    last_run=$(cat "$lockfile" 2>/dev/null || echo "never")
    current_date=$(date +%Y-%m-%d)

    if [[ "$last_run" == "$current_date" ]]; then
        Logger "(INFO) Already executed today. Waiting for tomorrow (next check in 3h)"
        sleep 10800
    else
        if [[ $(date +%H) == 11 ]]; then
            Logger "(INFO) Start scanning files"
            echo "$current_date" > "$lockfile"
            ScanFolders
        else
            Logger "(INFO) Waiting for 11:00 (next check in 30m)"
            sleep 1800
            Main
        fi
    fi
}

# Set vars
tmp_folder="/var/tmp"

# Read settings file
pref_language=$(grep '^\s*pref_language=' settings.ini | cut -d'=' -f2)
pref_language_full=$(grep '^\s*pref_language_full=' settings.ini | cut -d'=' -f2)
debug=$(grep '^\s*debug=' settings.ini | cut -d'=' -f2)

Main
