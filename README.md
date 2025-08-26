# NewsFlat

**NewsFlat** é um cliente de notícias **TUI (Terminal User Interface)** em **Bash**, com suporte a RSS/Atom.  
Permite ler artigos e comentários diretamente no terminal com **destaque de cores**, **suporte a Nerd Fonts**, **notificações de novos posts**, filtros e salvamento de itens.

---

## ✨ Recursos
- Interface em **fzf** + **less** para navegação fluida.
- Destaque de cores para manchetes, autores, categorias e badges.
- Ícones especiais para **startups YC** (se Nerd Fonts estiverem ativas).
- Marcação de artigos como **lidos** e **salvos**.
- Suporte a **RSS/Atom** e múltiplos feeds.
- Mesclagem de feeds com exibição unificada.
- Sistema de **alertas e notificações** (via `notify-send`).
- Personalização de **cores, largura de quadro, preview de linhas, fontes**.
- Daemon de atualização periódica com alertas automáticos.

---

## 📦 Instalação
Veja [INSTALL.md](INSTALL.md) para detalhes completos. Resumidamente:

```bash
git clone https://github.com/wcnunes/newsflat.git
cd newsflat
chmod +x newsflat.sh
sudo cp newsflat.sh /usr/local/bin/newsflat

## Instale dependências (Debian/Ubuntu)
sudo apt update
sudo apt install -y curl jq xmlstarlet fzf less w3m notify-osd libnotify-bin

## Configure
mkdir -p ~/.newsflat
cp -r .newsflat.example/* ~/.newsflat/

## Ajuda
newsflat help

# Manual de Uso - NewsFlat

## Comandos principais
- `newsflat add-feed <URL>` → adiciona novo feed
- `newsflat list-feeds` → lista feeds
- `newsflat update` → atualiza
- `newsflat show` → abre interface
- `newsflat help` → mostra ajuda

## Navegação
- Dentro do `newsflat show` (fzf):
  - `↑/↓` mover entre itens
  - `/texto` pesquisar
  - `Enter` abrir item

- Dentro de um item (`less`):
  - `q` sair
  - `/` pesquisar no conteúdo
  - `n` próximo resultado
  - `g` início
  - `G` fim

## Exemplos
```bash
newsflat add-feed https://news.ycombinator.com/rss
newsflat update
newsflat show


