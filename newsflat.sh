#!/usr/bin/env bash
# NewsFlat - TUI RSS/News client in bash
# Dependencies: curl, jq, xmlstarlet, fzf, less, w3m (or lynx), notify-send
# Author: Gerado pelo ChatGPT (adaptar conforme desejar)

set -euo pipefail
IFS=$'\n\t'

# Paths
NF_DIR="${HOME}/.newsflat"
DB_DIR="${NF_DIR}/db"
FEEDS_FILE="${DB_DIR}/feeds.json"
ITEMS_FILE="${DB_DIR}/items.json"
SETTINGS_FILE="${DB_DIR}/settings.json"
SAVED_FILE="${DB_DIR}/saved.json"
READ_FILE="${DB_DIR}/read.json"

# Defaults
mkdir -p "${DB_DIR}"
: > "${FEEDS_FILE}" 2>/dev/null || true
: > "${ITEMS_FILE}" 2>/dev/null || true
: > "${SAVED_FILE}" 2>/dev/null || true
: > "${READ_FILE}" 2>/dev/null || true

default_settings='{
  "frame_width": 80,
  "preview_lines": 20,
  "colors": {
    "headline": "1;36",
    "author": "0;33",
    "category": "1;35",
    "badge": "1;32",
    "quote": "0;37",
    "code": "0;32",
    "background": ""
  },
  "use_nerd_font": true,
  "poll_interval": 300,
  "notify_on_new": true,
  "max_items_fetch": 50
}'

if [ ! -s "${SETTINGS_FILE}" ]; then
  echo "${default_settings}" > "${SETTINGS_FILE}"
fi

# util: read setting
get_setting() {
  jq -r "$1" "${SETTINGS_FILE}"
}

# color wrapper
c() {
  # c "1;36" "text"
  printf '\033[%sm%s\033[0m' "$1" "$2"
}

# Detect nerd font (basic heuristic)
has_nerd_font() {
  # user control: check setting first
  local use_nf
  use_nf=$(jq -r '.use_nerd_font' "${SETTINGS_FILE}")
  if [ "$use_nf" = "false" ]; then
    return 1
  fi
  # heuristics: if terminal font supports ✓ char width? can't be sure, so rely on user setting.
  return 0
}

# Add feed
add_feed() {
  local url="$1"
  if [ -z "$url" ]; then
    echo "Usage: newsflat.sh add-feed <RSS_URL>"
    exit 1
  fi
  if [ ! -s "${FEEDS_FILE}" ]; then
    echo '[]' > "${FEEDS_FILE}"
  fi
  jq --arg u "$url" '. + [$u]' "${FEEDS_FILE}" > "${FEEDS_FILE}.tmp" && mv "${FEEDS_FILE}.tmp" "${FEEDS_FILE}"
  echo "Feed adicionado: $url"
}

# List feeds
list_feeds() {
  jq -r '.[]' "${FEEDS_FILE}" 2>/dev/null || echo "(nenhum feed)"
}

# Fetch RSS using curl + xmlstarlet
fetch_feed() {
  local url="$1"
  local maxitems
  maxitems=$(jq -r '.max_items_fetch' "${SETTINGS_FILE}")
  # fetch
  local xml
  xml=$(curl -sL "$url" || echo "")
  if [ -z "$xml" ]; then return; fi
  # Determine whether RSS or Atom
  echo "$xml" | xmlstarlet sel -T -t -m "//item|//entry" \
    -v "normalize-space(title)" -o "§" \
    -v "normalize-space(link)" -o "§" \
    -v "normalize-space(pubDate|updated|published)" -o "§" \
    -v "normalize-space(author/name|author|dc:creator)" -o "§" \
    -v "normalize-space(category|categories/category)" -o "§" \
    -v "normalize-space(description|summary|content:encoded|content)" -n 2>/dev/null \
    | sed '/^\s*$/d' \
    | head -n "${maxitems}"
}

# Merge feeds into ITEMS_FILE (json array of items)
update_all_feeds() {
  jq -n '[]' > "${ITEMS_FILE}.tmp"
  local feeds
  feeds=$(jq -r '.[]' "${FEEDS_FILE}" 2>/dev/null || true)
  if [ -z "${feeds}" ]; then
    echo "Nenhum feed cadastrado. Use add-feed."
    return
  fi

  while IFS= read -r feed; do
    echo "Buscando: $feed" >&2
    # each item line: title§link§date§author§category§content
    while IFS= read -r line; do
      IFS='§' read -r title link date author category content <<<"${line}"
      # normalize
      title=$(echo "$title" | sed 's/"/\\"/g')
      content=$(echo "$content" | sed 's/"/\\"/g')
      # build item JSON
      item=$(jq -n --arg t "$title" --arg l "$link" --arg d "$date" --arg a "$author" --arg c "$category" --arg b "$feed" --arg cnt "$content" '{
        id: (.id // (now|tostring) + ("-" + ($l | @base64))),
        title: $t, link: $l, date: $d, author: $a, category: $c, feed: $b, content: $cnt
      }')
      # append to tmp array
      jq --argjson it "$item" '. + [$it]' "${ITEMS_FILE}.tmp" > "${ITEMS_FILE}.tmp2" && mv "${ITEMS_FILE}.tmp2" "${ITEMS_FILE}.tmp"
    done < <(fetch_feed "$feed")
  done <<<"$feeds"

  # deduplicate by link, keep latest (naive)
  jq -s 'add | unique_by(.link) | sort_by(.date) | reverse' "${ITEMS_FILE}.tmp" > "${ITEMS_FILE}"
  rm -f "${ITEMS_FILE}.tmp" || true
  echo "Atualizado: $(jq length "${ITEMS_FILE}") itens." >&2
}

# Format item for list output (colored)
format_item_line() {
  local idx="$1"
  local title author category date new_marker badge
  title=$(jq -r ".[$idx].title" "${ITEMS_FILE}")
  author=$(jq -r ".[$idx].author" "${ITEMS_FILE}")
  category=$(jq -r ".[$idx].category" "${ITEMS_FILE}")
  date=$(jq -r ".[$idx].date" "${ITEMS_FILE}")
  # new marker if not in read list
  local link
  link=$(jq -r ".[$idx].link" "${ITEMS_FILE}")
  if grep -Fq "$link" "${READ_FILE}" 2>/dev/null; then
    new_marker=" "
  else
    new_marker="*"
  fi
  # YC badge heuristic: show badge if title or content mention "Y Combinator" or "YC"
  local content
  content=$(jq -r ".[$idx].content" "${ITEMS_FILE}")
  if echo "${title}${content}" | grep -Ei "Y Combinator|\\bYC\\b|ycombinator" >/dev/null; then
    if has_nerd_font; then badge="  " ; else badge="[YC]"; fi
  else
    badge=""
  fi

  # color codes from settings
  local hcol acol ccol
  hcol=$(jq -r '.colors.headline' "${SETTINGS_FILE}")
  acol=$(jq -r '.colors.author' "${SETTINGS_FILE}")
  ccol=$(jq -r '.colors.category' "${SETTINGS_FILE}")

  printf "%s %s %s — %s %s\n" "$new_marker" "$(c "$hcol" "$title")" "$(c "$acol" "by $author")" "$(c "$ccol" "$category")" "$badge"
}

# Show main list with fzf
show_list() {
  if [ ! -s "${ITEMS_FILE}" ]; then
    echo "Cache vazio. Rode 'newsflat.sh update' para buscar feeds."
    return
  fi
  local count
  count=$(jq length "${ITEMS_FILE}")
  local menu=()
  for ((i=0;i<count;i++)); do
    menu+=("$(format_item_line "$i")|$i")
  done
  # Use fzf to select
  local selection
  selection=$(printf '%s\n' "${menu[@]}" | fzf --ansi --no-sort --preview-window=right:60% --preview 'bash -c "idx=$(echo {} | awk -F\"|\" '\''{print $2}'\''); newsflat.sh view $idx"' | awk -F'|' '{print $2}' || true)
  if [ -z "$selection" ]; then
    return
  fi
  newsflat.sh view "$selection"
}

# View an item (use less for pagination)
view_item() {
  local idx="$1"
  local title link date author category content
  title=$(jq -r ".[$idx].title" "${ITEMS_FILE}")
  link=$(jq -r ".[$idx].link" "${ITEMS_FILE}")
  date=$(jq -r ".[$idx].date" "${ITEMS_FILE}")
  author=$(jq -r ".[$idx].author" "${ITEMS_FILE}")
  category=$(jq -r ".[$idx].category" "${ITEMS_FILE}")
  content=$(jq -r ".[$idx].content" "${ITEMS_FILE}")

  # Build view
  {
    echo "$(c "$(jq -r '.colors.headline' "${SETTINGS_FILE}")" "$title")"
    echo "$(c "$(jq -r '.colors.author' "${SETTINGS_FILE}")" "By: $author  |  $date  |  $category")"
    echo "Link: $link"
    echo "------------------------------------------------------------"
    # Format content: strip HTML rudimentarily and highlight quotes/code
    # Use w3m to render HTML if available
    if command -v w3m >/dev/null 2>&1; then
      echo
      printf "%s\n" "$content" | w3m -T text/html -dump -cols 80
    else
      printf "%s\n" "$content" | sed -E 's/<[^>]+>//g'
    fi
    echo
    echo "------------------ Ações ------------------"
    echo "  [s] Salvar   [m] Marcar como lido   [o] Abrir no navegador   [q] Sair"
  } | less -R
}

# mark read
mark_read() {
  local idx="$1"
  local link
  link=$(jq -r ".[$idx].link" "${ITEMS_FILE}")
  grep -Fq "$link" "${READ_FILE}" 2>/dev/null || echo "$link" >> "${READ_FILE}"
  echo "Marcado como lido."
}

# save item
save_item() {
  local idx="$1"
  local item
  item=$(jq ".[$idx]" "${ITEMS_FILE}")
  if ! jq -e --argjson it "$item" '. | index($it)' "${SAVED_FILE}" >/dev/null 2>&1; then
    jq ". + [$item]" "${SAVED_FILE}" > "${SAVED_FILE}.tmp" && mv "${SAVED_FILE}.tmp" "${SAVED_FILE}"
  fi
  echo "Salvo para leitura futura."
}

# open in browser
open_item() {
  local idx="$1"
  local link
  link=$(jq -r ".[$idx].link" "${ITEMS_FILE}")
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$link" &>/dev/null &
  else
    echo "Abra manualmente: $link"
  fi
}

# CLI handling
case "${1-}" in
  add-feed)
    shift || true
    add_feed "$1"
    ;;

  list-feeds)
    list_feeds
    ;;

  update)
    echo "Atualizando feeds..."
    update_all_feeds
    echo "Atualização concluída."
    ;;

  show)
    show_list
    ;;

  view)
    # view by index, but provide small interactive within "less" - actions outside less are simpler as alternatives
    idx="$2"
    view_item "$idx"
    ;;

  mark-read)
    mark_read "$2"
    ;;

  save)
    save_item "$2"
    ;;

  open)
    open_item "$2"
    ;;

  daemon)
    # Polling daemon to check new items and optionally notify
    echo "Iniciando daemon (Ctrl+C para sair). Poll interval em segundos: $(jq -r '.poll_interval' "${SETTINGS_FILE}")"
    while true; do
      pre_count=$(jq length "${ITEMS_FILE}" 2>/dev/null || echo 0)
      update_all_feeds
      post_count=$(jq length "${ITEMS_FILE}" 2>/dev/null || echo 0)
      if [ "${post_count}" -gt "${pre_count}" ]; then
        if jq -r '.notify_on_new' "${SETTINGS_FILE}" | grep -q true; then
          notify-send "NewsFlat" "Você tem $(($post_count - $pre_count)) novos itens"
        fi
      fi
      sleep "$(jq -r '.poll_interval' "${SETTINGS_FILE}")"
    done
    ;;

  config)
    ${EDITOR:-nano} "${SETTINGS_FILE}"
    ;;

  help|--help|-h|"")
    cat <<EOF
NewsFlat - comandos:
  newsflat.sh add-feed <URL>    # adiciona RSS/Atom
  newsflat.sh list-feeds        # lista feeds
  newsflat.sh update            # busca e atualiza cache
  newsflat.sh show              # abre UI (fzf) para escolher item
  newsflat.sh view <index>      # visualiza item por índice
  newsflat.sh save <index>      # salva item para ler depois
  newsflat.sh mark-read <index> # marca item como lido
  newsflat.sh daemon            # roda em loop e notifica novos itens
  newsflat.sh config            # editar configurações
  newsflat.sh help              # este texto
EOF
    ;;
  *)
    echo "Comando inválido. Use newsflat.sh help"
    exit 1
    ;;
esac
