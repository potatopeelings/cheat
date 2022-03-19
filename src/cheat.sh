CHEAT_ALIGNMENT="${CHEAT_ALIGNMENT:-topRight}"
CHEAT_COLOR="${CHEAT_COLOR:-white}"
CHEAT_FONT_SIZE="${CHEAT_FONT_SIZE:-12}"
CHEAT_OPACITY="${CHEAT_OPACITY:-0.3}"
CHEAT_SIZE="${CHEAT_SIZE:-400x600}"


function _cheat_command_apply() {
    _cheat_initialize withSettings
    sheet=$1

    if [ -f "${sheet}" ]; then
        _cheat_command_apply_file "${sheet}" "uniform"
    else
        file="${sheets_directory}/${sheet}.txt"
        _cheat_verify_file_exists "sheet '${sheet}' not found\n\n-e = edit a new/existing sheet\n-l = list all sheets" "${file}"

        contents=$(cat "${file}")

        background_image_file_windows=$(jq -r '[.profiles.list[] | select(.source=="Windows.Terminal.Wsl")][0].backgroundImage' "${windows_terminal_settings_file}")
        background_image_file=$(wslpath "${background_image_file_windows}")
        # change the property to trigger a hot reload of the background
        if [[ $(basename "${background_image_file}") == "background1.png" ]]; then
            background_image_file="${working_directory}/background2.png"
        else
            background_image_file="${working_directory}/background1.png"
        fi

        convert -size $CHEAT_SIZE \
            xc:transparent \
            -font "Noto-Mono" -pointsize $CHEAT_FONT_SIZE \
            -fill $CHEAT_COLOR \
            -antialias \
            -draw "text 0,0 '

${contents}'" \
            "${background_image_file}"

        _cheat_command_apply_file "${background_image_file}" "none"
    fi
}

function _cheat_command_clear() {
    _cheat_initialize withSettings

    cat "${windows_terminal_settings_file}" | \
        jq '(.profiles.list[] | select(.source=="Windows.Terminal.Wsl")) |= del(.backgroundImage)' \
        > "${setings_temporary_file}"
    mv "${setings_temporary_file}" "${windows_terminal_settings_file}"
}

function _cheat_command_apply_file() {
    background_image_file=$1
    background_image_strech_mode=$2

    background_image_file_windows=$(wslpath -w "${background_image_file}")
    cat "${windows_terminal_settings_file}" | \
        jq --arg CHEAT_ALIGNMENT "$CHEAT_ALIGNMENT" '(.profiles.list[] | select(.source=="Windows.Terminal.Wsl")).backgroundImageAlignment |= $CHEAT_ALIGNMENT' | \
        jq --arg CHEAT_OPACITY "$CHEAT_OPACITY" '(.profiles.list[] | select(.source=="Windows.Terminal.Wsl")).backgroundImageOpacity |= ($CHEAT_OPACITY | tonumber)' | \
        jq --arg background_image_strech_mode "$background_image_strech_mode" '(.profiles.list[] | select(.source=="Windows.Terminal.Wsl")).backgroundImageStretchMode |= $background_image_strech_mode' | \
        jq --arg background_image_file_windows "$background_image_file_windows" '(.profiles.list[] | select(.source=="Windows.Terminal.Wsl")).backgroundImage |= $background_image_file_windows' \
        > "${setings_temporary_file}"
    mv "${setings_temporary_file}" "${windows_terminal_settings_file}"
}

function _cheat_command_delete() {
    _cheat_initialize
    sheet=$1

    file="${sheets_directory}/${sheet}.txt"
    _cheat_verify_file_exists "sheet '${sheet}' not found" "${file}"

    read -p "sheet '${sheet}' will be deleted permanently. Are you sure? [y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        command rm "${file}"
    fi
}

function _cheat_command_edit() {
    _cheat_initialize
    sheet=$1

    file="${sheets_directory}/${sheet}.txt"
    editor="${VISUAL:-${EDITOR:-vi}}"
    $editor "${file}"
}

function _cheat_command_help() {
    echo "
Syntax:
    cheat [OPTION]

Options:
    -a SHEET
    --apply=SHEET            switch to SHEET

    -a IMAGE_FILE
    --apply=IMAGE_FILE       switch to IMAGE_FILE
    
    -c
    --clear                  clear applied sheet or image
    
    -d SHEET
    --delete=SHEET           delete SHEET

    -e SHEET
    --edit=SHEET             edit SHEET
    
    -h
    --help                   show help

    -l
    --list                   list all available sheets
"
}

function _cheat_command_list() {
    _cheat_initialize

    ls -1 "${sheets_directory}" | sed -e 's/\.txt$//'
}

function _cheat_initialize() {
    with=$1

    cheat_directory=${BASH_SOURCE%/*}
    sheets_directory="${cheat_directory}/sheets"
    working_directory="${cheat_directory}/working"
    setings_temporary_file="${working_directory}/settings.tmp"

    if [[ "${with}" == "withSettings" ]]; then
        local_app_data_directory=$(wslpath $(wslvar LOCALAPPDATA))
        windows_terminal_directory=$(find $local_app_data_directory/Packages/Microsoft.WindowsTerminal* -maxdepth 0 -mindepth 0 -print)
        windows_terminal_settings_file="${windows_terminal_directory}/LocalState/settings.json"
    fi
}

function _cheat_verify_file_exists() {
    message=$1
    file=$2

    if [ ! -f "${file}" ]; then
        echo -e "ERROR: ${message}"
        exit 1
    fi
}

function _cheat_verify_parameters() {
    actual=$1
    expected=$2
    message=$3

    if [[ $1 -lt $2 ]]; then
        echo -e "\n${message}"
    elif [[ $1 -gt $2 ]]; then
        echo -e "\nERROR: Too many options"
    else
        return;
    fi
    _cheat_command_help
    exit 1
}


case $1 in
    -a|--apply)
        _cheat_verify_parameters $# 2 "No sheet specified"
        _cheat_command_apply "$2"
        ;;
    -c|--clear)
        _cheat_verify_parameters $# 1
        _cheat_command_clear
        ;;
    -d|--delete)
        _cheat_verify_parameters $# 2 "No sheet specified"
        _cheat_command_delete "$2"
        ;;
    -e|--edit)
        _cheat_verify_parameters $# 2 "No sheet specified"
        _cheat_command_edit "$2"
        ;;
    -h|--help)
        _cheat_verify_parameters $# 1
        _cheat_command_help
        ;;
    -l|--list)
        _cheat_verify_parameters $# 1
        _cheat_command_list
        ;;
    -*|--*|*)
        echo -e "\nInvalid option"
        _cheat_command_help
        ;;
esac
