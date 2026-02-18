#!/bin/bash
# sand-notify — notification sound pack management for Sand
#
# Usage:
#   sand-notify use <pack>       Activate a pack (prout, warcraft, serieux...)
#   sand-notify current          Show the active pack
#   sand-notify packs            List available packs
#   sand-notify play [pack]      Listen to all sounds in a pack
#   sand-notify test [stop|question]  Test a notification
#   sand-notify add <pack> <stop|question> <file>  Add a sound
#   sand-notify notify <stop|question|tool>  Called by Claude Code hooks

SOUNDS_DIR="$HOME/.config/sand/sounds"
SYSTEM_DIR="$HOME/Library/Sounds"
CONFIG="$HOME/.config/sand/notify.conf"
SENDER="dev.arsis.sand.notify"

mkdir -p "$SOUNDS_DIR"

# Read the active pack
get_current() {
    if [ -f "$CONFIG" ]; then
        cat "$CONFIG"
    else
        echo "prout"
    fi
}

# Sync a pack to ~/Library/Sounds/
sync_pack() {
    local pack="$1"
    local pack_dir="$SOUNDS_DIR/$pack"

    # Clean all Sand sounds
    rm -f "$SYSTEM_DIR"/Sand_*.aiff

    # Stop sounds
    local i=0
    for f in "$pack_dir"/stop/*.aiff; do
        [ -f "$f" ] || continue
        i=$((i + 1))
        cp "$f" "$SYSTEM_DIR/Sand_${pack}_stop_${i}.aiff"
    done

    # Question sounds
    local j=0
    for f in "$pack_dir"/question/*.aiff; do
        [ -f "$f" ] || continue
        j=$((j + 1))
        cp "$f" "$SYSTEM_DIR/Sand_${pack}_question_${j}.aiff"
    done

    # Tool sounds (subtle sound when Claude wants to use a tool)
    local k=0
    for f in "$pack_dir"/tool/*.aiff; do
        [ -f "$f" ] || continue
        k=$((k + 1))
        cp "$f" "$SYSTEM_DIR/Sand_${pack}_tool_${k}.aiff"
    done

    # Fallback: copy Tink if no tool sound in the pack
    if [ "$k" -eq 0 ]; then
        cp /System/Library/Sounds/Tink.aiff "$SYSTEM_DIR/Sand_${pack}_tool_1.aiff"
        k=1
    fi

    # Restart NotificationCenter to detect new sounds
    killall usernoted 2>/dev/null
    sleep 1

    echo "$i stop, $j question, $k tool sound(s) synced"
}

# Play a random sound
play_random() {
    local type="$1"  # stop, question or tool
    local pack
    pack=$(get_current)
    local prefix="Sand_${pack}_${type}"

    local count
    count=$(ls "$SYSTEM_DIR"/${prefix}_*.aiff 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -eq 0 ] && return 1

    local n=$((RANDOM % count + 1))
    echo "${prefix}_${n}"
}

case "${1:-current}" in
    use)
        pack="${2:?Usage: sand-notify use <pack>}"
        if [ ! -d "$SOUNDS_DIR/$pack" ]; then
            echo "Unknown pack: $pack"
            echo "Available packs:"
            ls -1 "$SOUNDS_DIR" | grep -v '\.' | sed 's/^/  /'
            exit 1
        fi
        echo "$pack" > "$CONFIG"
        sync_pack "$pack"
        echo "Active pack: $pack"
        ;;

    current)
        echo "Active pack: $(get_current)"
        ;;

    packs)
        current=$(get_current)
        for d in "$SOUNDS_DIR"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            stops=$(ls "$d"/stop/*.aiff 2>/dev/null | wc -l | tr -d ' ')
            questions=$(ls "$d"/question/*.aiff 2>/dev/null | wc -l | tr -d ' ')
            tools=$(ls "$d"/tool/*.aiff 2>/dev/null | wc -l | tr -d ' ')
            marker=" "
            [ "$name" = "$current" ] && marker="●"
            tool_info=""
            [ "$tools" -gt 0 ] && tool_info=", $tools tool"
            echo " $marker $name  ($stops stop, $questions question${tool_info})"
        done
        ;;

    play)
        pack="${2:-$(get_current)}"
        pack_dir="$SOUNDS_DIR/$pack"
        if [ ! -d "$pack_dir" ]; then
            echo "Unknown pack: $pack"
            exit 1
        fi
        echo "Pack: $pack"
        echo "--- stop ---"
        for f in "$pack_dir"/stop/*.aiff; do
            [ -f "$f" ] || continue
            echo "  ▶ $(basename "$f")"
            afplay "$f"
            sleep 0.3
        done
        echo "--- question ---"
        for f in "$pack_dir"/question/*.aiff; do
            [ -f "$f" ] || continue
            echo "  ▶ $(basename "$f")"
            afplay "$f"
            sleep 0.3
        done
        if ls "$pack_dir"/tool/*.aiff &>/dev/null; then
            echo "--- tool ---"
            for f in "$pack_dir"/tool/*.aiff; do
                [ -f "$f" ] || continue
                echo "  ▶ $(basename "$f")"
                afplay "$f"
                sleep 0.3
            done
        else
            echo "--- tool --- (fallback: Tink)"
        fi
        ;;

    test)
        type="${2:-stop}"
        sync_pack "$(get_current)" > /dev/null
        sound=$(play_random "$type")
        if [ -z "$sound" ]; then
            echo "No '$type' sound in pack $(get_current)"
            exit 1
        fi
        if [ "$type" = "stop" ]; then
            terminal-notifier -title 'Sand ✅' -message "Test — $(get_current) — $type" -sound "$sound" -sender "$SENDER" 2>/dev/null
        else
            terminal-notifier -title 'Sand ❓' -message "Test — $(get_current) — $type" -sound "$sound" -sender "$SENDER" 2>/dev/null
        fi
        echo "$sound"
        ;;

    notify)
        # Called by Claude Code hooks
        type="${2:-stop}"
        sound=$(play_random "$type")
        [ -z "$sound" ] && sound="default"
        project=$(basename "$PWD")
        if [ "$type" = "tool" ]; then
            # Tool: just the sound, no banner (too frequent)
            afplay "$SYSTEM_DIR/${sound}.aiff" &>/dev/null &
        elif [ "$type" = "stop" ]; then
            terminal-notifier -title 'Sand ✅' -message "Claude finished in $project" -sound "$sound" -sender "$SENDER" 2>/dev/null
        else
            terminal-notifier -title 'Sand ❓' -message "Claude has a question in $project" -sound "$sound" -sender "$SENDER" 2>/dev/null
        fi
        ;;

    add)
        pack="${2:?Usage: sand-notify add <pack> <stop|question> <file>}"
        type="${3:?Usage: sand-notify add <pack> <stop|question> <file>}"
        file="${4:?Usage: sand-notify add <pack> <stop|question> <file>}"
        mkdir -p "$SOUNDS_DIR/$pack/$type"
        name=$(basename "${file%.*}")
        ext="${file##*.}"
        if [ "$ext" = "aiff" ]; then
            cp "$file" "$SOUNDS_DIR/$pack/$type/${name}.aiff"
        else
            ffmpeg -y -i "$file" "$SOUNDS_DIR/$pack/$type/${name}.aiff" 2>/dev/null
        fi
        echo "Added: $pack/$type/${name}.aiff"
        # Re-sync if it's the active pack
        [ "$pack" = "$(get_current)" ] && sync_pack "$pack" > /dev/null
        ;;

    *)
        echo "sand-notify — notification sound packs for Sand"
        echo ""
        echo "  use <pack>                    Activate a pack"
        echo "  current                       Active pack"
        echo "  packs                         List packs"
        echo "  play [pack]                   Listen to a pack"
        echo "  test [stop|question]          Test a notification"
        echo "  add <pack> <type> <file>      Add a sound"
        echo "  notify <stop|question>        (Claude Code hooks)"
        ;;
esac
