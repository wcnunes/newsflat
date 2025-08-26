# Instalação do NewsFlat

O **NewsFlat** é um cliente TUI de notícias para o terminal, escrito em **Bash**.  
Siga os passos abaixo para instalar e configurar em seu sistema.

---

## 🔧 Dependências
Certifique-se de ter os seguintes pacotes instalados:

- `curl`
- `jq`
- `xmlstarlet`
- `fzf`
- `less`
- `w3m` (ou `lynx` para pré-visualizar links)
- `libnotify-bin` (para notificações)

### Instalação das dependências no Debian/Ubuntu
```bash
sudo apt update
sudo apt install -y curl jq xmlstarlet fzf less w3m notify-osd libnotify-bin
