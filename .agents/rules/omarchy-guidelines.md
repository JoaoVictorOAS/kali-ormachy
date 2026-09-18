# Regras de Desenvolvimento e Diretrizes Omarchy

Este arquivo estabelece as regras obrigatórias de conformidade arquitetural para o desenvolvimento do plugin `kali-ormachy`.

---

## 1. Prioridade e Desempenho
- **Execução Nativa Mandatória:** As ferramentas de segurança devem ser executadas no ambiente nativo do Arch Linux / BlackArch para evitar atrasos de inicialização e problemas de acesso a interfaces de rede (`wlan0`, `raw sockets`).
- **Core em Rust:** Todo o processamento de catálogos, checagens de binários (`std::process::Command`, validação em `$PATH`) e geração de menus deve ser feito em Rust com tempo de resposta imperceptível (< 5ms).

## 2. Terminal e Preservação de Sessão
- Nunca lance ferramentas interativas (ex: scanners, fuzzers) em um terminal que fecha automaticamente após o término.
- O terminal deve utilizar `--hold` ou executar um subshell persistente (`exec $SHELL`) para que o analista de segurança possa inspecionar o log e o resultado completo do comando.
- Respeitar a precedência do terminal configurado: `$TERMINAL` -> `kitty` -> `foot` -> `alacritty`.

## 3. Conformidade com Temas do Omarchy
- Proibido inserir cores hexadecimais estáticas nos templates de interface (`.rasi` ou `QML`).
- A interface deve importar o tema do sistema configurado pelo Omarchy (`@theme` ou paleta gerada pelo ecossistema do desktop).

## 4. Tratamento de Dependências
- Caso uma ferramenta não esteja presente no sistema, o launcher NÃO deve falhar em silêncio.
- Deve acionar:
  1. Notificação nativa no desktop via `notify-send`.
  2. Opção interativa no Rofi/UI permitindo ao usuário abrir o terminal com `sudo pacman -S <pacote>` ou copiar o comando.
