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
