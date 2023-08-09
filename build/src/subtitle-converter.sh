#!/bin/bash


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
        track_info=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $track_id)" -A 10)
        language=$(echo "$track_info" | grep "Language:" | awk '{print $4}')
        #language_forced=$(echo "$track_info" | grep -i "forced" | grep -v -i "name")
        
        if [[ "$track" == "" ]]; then
            reason="No subtitles detected"
            break
        fi
        
        if [[ "$language" != *"$SC_PREF_LANG"* || "$language" == "" ]]; then
            Logger "$track_info" "debug"
            if [[ "$track_info" =~ "S_VOBSUB" ]]; then
                reason="S_VOBSUB detected"
                break
            elif [[ "$track_info" =~ "S_HDMV/PGS" ]]; then
                reason="S_HDMV/PGS detected"
                break
            else
                to_clean="true"
                break
            fi
        fi
        
        if [[ "$track_info" =~ "S_TEXT/UTF8" ]]; then
            continue
        elif [[ "$track_info" =~ "S_TEXT/ASS" ]]; then
            to_clean="true"
            break
        elif [[ "$track_info" =~ "S_TEXT/USF" ]]; then
            to_clean="true"
            break
        elif [[ "$track_info" =~ "S_VOBSUB" ]]; then
            reason="S_VOBSUB detected"
            break
        elif [[ "$track_info" =~ "S_HDMV/PGS" ]]; then
            reason="S_HDMV/PGS detected"
            break
        fi
    done
    
    if [[ "$to_clean" == "true" ]]; then
        Logger "(INFO) Start converting subtitles : $filename"
        ExtractSubtitles
    else
        Logger "(DEBUG) Skip : $filename ($reason)" "debug"
    fi
}


ExtractSubtitles() {
    for track in $tracks; do
        track_id=$(echo "$track" | awk '{print $3}' | tr -d ":")
        
        if [[ "$track" =~ "S_TEXT/UTF8" ]]; then
            ext="srt"
        elif [[ "$track" =~ "S_TEXT/ASS" ]]; then
            ext="ssa"
        elif [[ "$track" =~ "S_TEXT/USF" ]]; then
            ext="usf"
        elif [[ "$track" =~ "S_HDMV/PGS" ]]; then
            ext="sup"
        elif [[ "$track" =~ "S_VOBSUB" ]]; then
            ext="sub"
        fi
        
        tmp_file="$SC_TMP/$filename-$track_id.$ext"
        
        Logger "(DEBUG) Extract track : $track_id" "debug"
        mkvextract tracks "$mkv_file" "$track_id:$tmp_file" > /dev/null
        
        Logger "(DEBUG) Convert track : $track_id" "debug"
        ConvertSubtitles
    done

    Logger "(DEBUG) Cleaning old subtitles : $filename" "debug"
    CleanFile

    Logger "(DEBUG) Add converted subtitles : $filename" "debug"
    AddSubtitles
    
    mv "$mkv_file-tmp.mkv" "$mkv_file"
}


ConvertSubtitles() {
    if [[ "$track" =~ "S_HDMV/PGS" ]]; then
        echo > /dev/null
    elif [[ "$track" =~ "S_VOBSUB" ]]; then
        echo > /dev/null
    else
        ffmpeg -loglevel 0 -i $tmp_file -y -f srt $tmp_file.srt
    fi
    
    rm -f $tmp_file
}


CleanFile() {
    mkvmerge -q -o $mkv_file-tmp.mkv --no-subtitles $mkv_file
}


AddSubtitles() {
    srt_files=$(find $SC_TMP -name "$filename*.srt" -type f)
    IFS=$'\n'
    for srt_file in $srt_files; do
        track_id=$(echo $srt_file | rev | cut -d'-' -f 1 | rev | cut -d'.' -f 1)
        language=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $track_id)" -A 11 | grep "Language:" | awk '{print $4}')
        name=$(mkvinfo $mkv_file | grep "(track ID for mkvmerge & mkvextract: $track_id)" -A 11 | sed -n 's/.*Name: \(.*\)/\1/p')

        if [[ "$language" == "" ]]; then
            language="$SC_PREF_LANG"
        fi
        if [[ "$name" == "" ]]; then
            name="$SC_PREF_LANG_FULL"
        fi
        
        content=$(cat "$srt_file" | awk '{gsub(/<[^>]*>/,"")};1' | awk '!/^[0-9]+$/ && !/^[0-9]+:[0-9]+:[0-9]+,[0-9]+ --> [0-9]+:[0-9]+:[0-9]+,[0-9]+$/' | awk '{gsub(/{.*}/,"")};1' | sed '/^$/d')
        detected_language=$(echo "$content" | python3 -c "from langdetect import detect; import sys; print(detect(sys.stdin.read()))")

        if [[ "$detected_language" != "$SC_PREF_LANG" ]]; then
            Logger "(DEBUG) Delete $srt_file ($detected_language)" "debug"
        else
            Logger "(DEBUG) Add $srt_file ($detected_language)" "debug"
            mkvmerge -q -o "$mkv_file-sub.mkv" "$mkv_file-tmp.mkv" --language 0:$language --sub-charset 0:UTF-8 --track-name 0:"$name" "$srt_file"
            mv -f "$mkv_file-sub.mkv" "$mkv_file-tmp.mkv"
        fi
        
        rm -f $srt_file
    done
}


Logger() {
    local -r log_date="[$(date +'%d-%m-%Y|%H:%M:%S')]"

    if [[ "$2" != "debug" || "$SC_DEBUG" == "True" ]]; then
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


Main
