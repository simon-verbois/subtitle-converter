#!/bin/bash


ConvertSubtitles() {
    if [[ "$format" == "pgs" ]]; then
        # convert .sub to .srt
        #rm -f $tmp_file.$ext
        echo > /dev/null
    else
        ffmpeg -loglevel 0 -i $tmp_file.$ext -y -f srt $tmp_file.srt
        rm -f $tmp_file.$ext
    fi
}


CleanFile() {
    mkvmerge -q -o $mkv_file-new.mkv --no-subtitles $mkv_file
}


AddSubtitles() {
    srt_files=$(find $SC_TMP -name "$filename*.srt" -type f)
    IFS=$'\n'
    for srt_file in $srt_files; do
        ID=$(echo $srt_file | rev | cut -d'-' -f 1 | rev | cut -d'.' -f 1)
        language=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $ID)" -A 11 | grep "Language:" | awk '{print $4}')
        name=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $ID)" -A 11 | sed -n 's/.*Name: \(.*\)/\1/p')

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


GetTracksInfo() {
    filename=$(basename -s .mvk "$mkv_file")
    tracks=""
    tracks=$(mkvmerge -i "$mkv_file" | grep "subtitles")

    IFS=$'\n'
    for track in $tracks; do
        ext=""
        to_clean="false"
        reason="Already cleaned"
        track_id=$(echo "$track" | awk '{print $3}' | tr -d ":")
        language=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $track_id)" -A 10 | grep "Language:" | awk '{print $4}')
        #language_forced=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $track_id)" -A 10 | grep -i "forced" | grep -v -i "name")
        
        if [[ -z "$track" ]]; then
            reason="No subtitles detected"
            break
        fi
        
        if [[ "$language" != *"$pref_language"* ]]; then
            to_clean="true"
            break
        fi
        if [[ -z "$language" ]]; then
            to_clean="true"
            break
        fi
        
        if [[ "$track" =~ "S_TEXT/UTF8" ]]; then
            ext="srt"
            to_clean="true"
            break
        elif [[ "$track" =~ "S_TEXT/ASS" ]]; then
            ext="ssa"
            to_clean="true"
            break
        elif [[ "$track" =~ "S_TEXT/USF" ]]; then
            ext="usf"
            to_clean="true"
            break
        elif [[ "$track" =~ "S_VOBSUB" ]]; then
            ext="sub"
            reason="S_VOBSUB detected"
            break
        elif [[ "$track" =~ "S_HDMV/PGS" ]]; then
            ext="sup"
            reason="S_HDMV/PGS detected"
            break
        fi
    done
    
    if [[ "$to_clean" == "true" ]]; then
        Logger "(INFO) Start converting subtitles of : $filename"
        ExtractSubtitle
    else
        Logger "(DEBUG) Skip : $filename ($reason)" "debug"
    fi
}


ExtractSubtitle() {
    for track in $tracks; do
        #if [[ ! "$track" =~ "S_HDMV/PGS" && ! "$track" =~ "S_VOBSUB" ]]; then
        #    #ffmpeg -loglevel 0 -i "$mkv_file" -map 0:s:$track_id -scodec copy $SC_TMP/$filename-$track_id.sup
        #    echo > /dev/null
        #elif [[ ! "$track" =~ "S_HDMV/PGS" && ! "$track" =~ "S_VOBSUB" ]]; then
        #    #ffmpeg -loglevel 0 -i "$mkv_file" -map 0:s:$track_id -scodec copy $SC_TMP/$filename-$track_id.sup
        #    echo > /dev/null
        #else
        #    mkvextract tracks "$mkv_file" $track_id:$SC_TMP/$filename-$track_id.$ext > /dev/null
        #fi
        
        tmp_file="$SC_TMP/$filename-$track_id"
        
        Logger "(DEBUG) Extract track : $track_id" "debug"
        mkvextract tracks "$mkv_file" "$track_id:$tmp_file.$ext" > /dev/null
        
        Logger "(DEBUG) Convert track : $track_id" "debug"
        ConvertSubtitles
    done

    Logger "(DEBUG) Cleaning old subtitles tracks : $filename" "debug"
    CleanFile

    Logger "(DEBUG) Add new subtitles : $filename" "debug"
    AddSubtitles

    Logger "(DEBUG) Replace old file : $filename" "debug"
    mv "$mkv_file-new.mkv" "$mkv_file"
}


ScanFolders() {
    mkv_files=$(find "./data" -name "*.mkv" -type f)
    IFS=$'\n'
    for mkv_file in $mkv_files; do
        GetTracksInfo
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


Main() {
    lockfile="$SC_TMP/subtitle-converter.lock"
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


pref_language=$(grep '^\s*pref_language=' $SC_SETTINGS_FILE | cut -d'=' -f2)
pref_language_full=$(grep '^\s*pref_language_full=' $SC_SETTINGS_FILE | cut -d'=' -f2)
debug=$(grep '^\s*debug=' $SC_SETTINGS_FILE | cut -d'=' -f2)


Main
