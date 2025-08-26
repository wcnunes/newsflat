#!/usr/bin/env bash
# ==============================================
# NewsFlat - Cliente TUI de Notícias em Bash
# ==============================================
# Dependências: curl, jq, xmlstarlet, fzf, less, w3m (ou lynx), notify-send
# Configuração: ~/.newsflat/config.json

CONFIG_DIR="$HOME/.newsflat"
FEEDS_FILE="$CONFIG_DIR/feeds.txt"
CONFIG_FILE="$CONFIG_DIR/config.json"
SAVED_FILE="$CONFIG_DIR/saved.json"

mkdir -p "$CONFIG_DIR"

# Carregar config
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Arquivo de configuração não encontrado, copie de .newsflat.example/config.json"
        exit 1
    fi
    FRAME_WIDTH=$(jq -r '.frame_width' "$CONFIG_FILE")
    PREVIEW_LINES=$(jq -r '.preview_lines' "$CONFIG_FILE")
    COLOR_HEADLINE=$(jq -r '.colors.headline' "$CONFIG_FILE")
    COLOR_AUTHOR=$(jq -r '.colors.author' "$CONFIG_FILE")
    COLOR_CATEGORY=$(jq -r '.colors.category' "$CONFIG_FILE")
}

# Adicionar feed
add_feed() {
    echo "$1" >> "$FEEDS_FILE"
    echo "Feed adicionado: $1"
}

# Listar feeds
list_feeds() {
    nl -w2 -s". " "$FEEDS_FILE"
}

# Atualizar feeds
update_feeds() {
    mkdir -p "$CONFIG_DIR/cache"
    while read -r url; do
        file="$CONFIG_DIR/cache/$(echo "$url" | md5sum | cut -d' ' -f1).xml"
        curl -s "$url" -o "$file"
        echo "Atualizado: $url"
    done < "$FEEDS_FILE"
}

# Mostrar interface
show_feeds() {
    files=$(ls "$CONFIG_DIR/cache"/*.xml 2>/dev/null)
    if [[ -z "$files" ]]; then
        echo "Nenhum feed atualizado. Rode: newsflat update"
        exit 1
    fi

    choices=$(for f in $files; do
        xmlstarlet sel -t -m "//item" \
            -v "concat(title, ' | ', pubDate)" -n "$f" 2>/dev/null
    done)

    echo "$choices" | fzf --ansi --preview "echo {} | cut -d'|' -f1 | xargs -I{} grep -A20 {} $files | fold -w$FRAME_WIDTH | head -n$PREVIEW_LINES"
}

# Ajuda
help() {
cat <<EOF
NewsFlat - Cliente TUI de Notícias
Uso: newsflat [comando] [opções]

Comandos:
  add-feed <url>     Adiciona um novo feed
  list-feeds         Lista os feeds salvos
  update             Atualiza os feeds
  show               Mostra os artigos em interface TUI
  help               Mostra esta ajuda
EOF
}

case "$1" in
    add-feed) add_feed "$2" ;;
    list-feeds) list_feeds ;;
    update) update_feeds ;;
    show) load_config; show_feeds ;;
    help|*) help ;;
esac
