#!/bin/bash
# sand-notify — gestion des packs de sons de notification Sand
#
# Usage:
#   sand-notify use <pack>       Active un pack (prout, warcraft, serieux...)
#   sand-notify current          Affiche le pack actif
#   sand-notify packs            Liste les packs disponibles
#   sand-notify play [pack]      Écoute tous les sons d'un pack
#   sand-notify test [stop|question]  Test une notification
#   sand-notify add <pack> <stop|question> <fichier>  Ajoute un son
#   sand-notify notify <stop|question|tool>  Appelé par les hooks Claude Code

SOUNDS_DIR="$HOME/.config/sand/sounds"
SYSTEM_DIR="$HOME/Library/Sounds"
CONFIG="$HOME/.config/sand/notify.conf"
SENDER="dev.arsis.sand.notify"

mkdir -p "$SOUNDS_DIR"

# Lire le pack actif
get_current() {
    if [ -f "$CONFIG" ]; then
        cat "$CONFIG"
    else
        echo "prout"
    fi
}

# Synchroniser un pack vers ~/Library/Sounds/
sync_pack() {
    local pack="$1"
    local pack_dir="$SOUNDS_DIR/$pack"

    # Nettoyer les anciens sons
    rm -f "$SYSTEM_DIR"/SandStop_*.aiff "$SYSTEM_DIR"/SandQuestion_*.aiff "$SYSTEM_DIR"/SandTool_*.aiff

    # Sons "stop"
    local i=0
    for f in "$pack_dir"/stop/*.aiff; do
        [ -f "$f" ] || continue
        i=$((i + 1))
        cp "$f" "$SYSTEM_DIR/SandStop_${i}.aiff"
    done

    # Sons "question"
    local j=0
    for f in "$pack_dir"/question/*.aiff; do
        [ -f "$f" ] || continue
        j=$((j + 1))
        cp "$f" "$SYSTEM_DIR/SandQuestion_${j}.aiff"
    done

    # Sons "tool" (son subtil quand Claude veut utiliser un outil)
    local k=0
    for f in "$pack_dir"/tool/*.aiff; do
        [ -f "$f" ] || continue
        k=$((k + 1))
        cp "$f" "$SYSTEM_DIR/SandTool_${k}.aiff"
    done

    # Fallback : copier Tink si aucun son tool dans le pack
    if [ "$k" -eq 0 ]; then
        cp /System/Library/Sounds/Tink.aiff "$SYSTEM_DIR/SandTool_1.aiff"
        k=1
    fi

    # Redémarrer NotificationCenter pour détecter les nouveaux sons
    killall usernoted 2>/dev/null
    sleep 1

    echo "$i son(s) stop, $j son(s) question, $k son(s) tool synchronisés"
}

# Jouer un son aléatoire
play_random() {
    local type="$1"  # stop, question ou tool
    local prefix
    case "$type" in
        stop) prefix="SandStop" ;;
        question) prefix="SandQuestion" ;;
        tool) prefix="SandTool" ;;
        *) prefix="SandStop" ;;
    esac

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
            echo "❌ Pack inconnu : $pack"
            echo "Packs disponibles :"
            ls -1 "$SOUNDS_DIR" | grep -v '\.' | sed 's/^/  /'
            exit 1
        fi
        echo "$pack" > "$CONFIG"
        sync_pack "$pack"
        echo "✅ Pack actif : $pack"
        ;;

    current)
        echo "Pack actif : $(get_current)"
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
            echo "❌ Pack inconnu : $pack"
            exit 1
        fi
        echo "🔊 Pack : $pack"
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
            echo "❌ Aucun son '$type' dans le pack $(get_current)"
            exit 1
        fi
        if [ "$type" = "stop" ]; then
            terminal-notifier -title 'Sand ✅' -message "Test — $(get_current) — $type" -sound "$sound" -sender "$SENDER" 2>/dev/null
        else
            terminal-notifier -title 'Sand ❓' -message "Test — $(get_current) — $type" -sound "$sound" -sender "$SENDER" 2>/dev/null
        fi
        echo "🔊 $sound"
        ;;

    notify)
        # Appelé par les hooks Claude Code
        type="${2:-stop}"
        sound=$(play_random "$type")
        [ -z "$sound" ] && sound="default"
        project=$(basename "$PWD")
        if [ "$type" = "tool" ]; then
            # Tool : juste le son, pas de bannière (trop fréquent)
            afplay "$SYSTEM_DIR/${sound}.aiff" &>/dev/null &
        elif [ "$type" = "stop" ]; then
            terminal-notifier -title 'Sand ✅' -message "Claude a terminé dans $project" -sound "$sound" -sender "$SENDER" 2>/dev/null
        else
            terminal-notifier -title 'Sand ❓' -message "Claude a une question dans $project" -sound "$sound" -sender "$SENDER" 2>/dev/null
        fi
        ;;

    add)
        pack="${2:?Usage: sand-notify add <pack> <stop|question> <fichier>}"
        type="${3:?Usage: sand-notify add <pack> <stop|question> <fichier>}"
        file="${4:?Usage: sand-notify add <pack> <stop|question> <fichier>}"
        mkdir -p "$SOUNDS_DIR/$pack/$type"
        name=$(basename "${file%.*}")
        ext="${file##*.}"
        if [ "$ext" = "aiff" ]; then
            cp "$file" "$SOUNDS_DIR/$pack/$type/${name}.aiff"
        else
            ffmpeg -y -i "$file" "$SOUNDS_DIR/$pack/$type/${name}.aiff" 2>/dev/null
        fi
        echo "✅ Ajouté : $pack/$type/${name}.aiff"
        # Re-sync si c'est le pack actif
        [ "$pack" = "$(get_current)" ] && sync_pack "$pack" > /dev/null
        ;;

    *)
        echo "sand-notify — packs de sons de notification Sand"
        echo ""
        echo "  use <pack>                    Active un pack"
        echo "  current                       Pack actif"
        echo "  packs                         Liste les packs"
        echo "  play [pack]                   Écoute un pack"
        echo "  test [stop|question]          Test une notification"
        echo "  add <pack> <type> <fichier>   Ajoute un son"
        echo "  notify <stop|question>        (hooks Claude Code)"
        ;;
esac
