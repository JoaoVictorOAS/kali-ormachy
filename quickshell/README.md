# Kali-Ormachy - Widget Nativo Quickshell para Omarchy

Este diretório contém o frontend nativo em **QML / Quickshell** do plugin **kali-ormachy** para o ambiente desktop **Omarchy** (baseado em Arch Linux e Hyprland).

O widget atua como um launcher moderno, fluido e de alto desempenho, integrando diretamente com a CLI e o Core Engine em Rust (`kali-ormachy`) para renderizar categorias, ferramentas, presets de execução e status de instalação em tempo real com resposta inferior a **5ms**.

---

## 1. Arquitetura e Componentes

A interface é modular e dividida em três componentes QML:

| Componente | Arquivo | Responsabilidade |
| :--- | :--- | :--- |
| **`KaliLauncher`** | [`KaliLauncher.qml`](file:///home/JoaoVictor/dados/plugins/kali-ormachy/quickshell/KaliLauncher.qml) | Janela principal / overlay (`PanelWindow`). Gerencia o ciclo de vida dos processos Quickshell (`Process`), cache reativo em memória, barra de busca instantânea, paginação de categorias e despacho desacoplado de ferramentas. |
| **`CategoryButton`** | [`CategoryButton.qml`](file:///home/JoaoVictor/dados/plugins/kali-ormachy/quickshell/CategoryButton.qml) | Botão estilizável para abas e barra lateral de categorias. Exibe glifo Nerd Font, nome da categoria, badge com contagem de ferramentas e indicador visual de seleção ativa. |
| **`ToolCard`** | [`ToolCard.qml`](file:///home/JoaoVictor/dados/plugins/kali-ormachy/quickshell/ToolCard.qml) | Card de exibição da ferramenta de segurança. Mostra nome, binário, badge de modo (Terminal `󰞷` / GUI `󰍹`), badge de status (`✓ Instalado` ou `✗ Não instalado`), lista de chips de presets de comando e botão de execução/instalação direta. |

---

## 2. Pré-requisitos

1. **Quickshell**:
   Pacote instalado no sistema Arch / Omarchy (`quickshell` ou `quickshell-git`).
2. **Core Engine `kali-ormachy`**:
   Binário compilado e instalado no `$PATH` (geralmente em `~/.local/bin/kali-ormachy` ou `/usr/local/bin/kali-ormachy`).
3. **Nerd Font**:
   Recomendada a fonte `JetBrainsMono Nerd Font` (`ttf-jetbrains-mono-nerd`) para renderização dos ícones de segurança e status.

---

## 3. Protocolo de Comunicação CLI & JSON

O widget comunica-se de forma assíncrona e desacoplada com o binário `kali-ormachy` utilizando JSON estrito:

1. **Listagem de Categorias:**
   ```bash
   kali-ormachy categories --format json
   ```
   Retorna a árvore de categorias com `id`, `name`, `icon` e ferramentas catalogadas.
2. **Consulta Reativa com Status de Instalação:**
   ```bash
   kali-ormachy tools --category <id> --format json
   ```
   Retorna a lista de ferramentas da categoria com o campo booleano `"installed": true/false`, avaliado instantaneamente no `$PATH` via crate `which`.
3. **Lançamento de Ferramenta / Preset:**
   ```bash
   kali-ormachy launch-tool --name <tool_name> [--preset <preset_name>]
   ```
   O runner em Rust do `kali-ormachy` detecta se a ferramenta é GUI ou Terminal, resolve o emulador de terminal ativo do usuário (Kitty, Alacritty, Foot, Ghostty, etc.), aplica a flag de *hold de sessão* configurada e despacha o processo de forma desacoplada (`setsid`/`nohup`).

---

## 4. Como Integrar no Quickshell do Omarchy

### 4.1. Adicionar o Componente ao `shell.qml`

No seu arquivo de entrada do Quickshell (geralmente localizado em `~/.config/quickshell/shell.qml`):

```qml
import Quickshell
import "path/to/kali-ormachy/quickshell"

ShellRoot {
    // Outros componentes da barra e widgets...

    KaliLauncher {
        id: kaliLauncher
        visible: false // Inicia oculto, ativado via atalho global
        
        // Opcional: sobrescrever caminho do binário se não estiver no $PATH global
        // binPath: "/home/usuario/.local/bin/kali-ormachy"
    }

    // Exemplo de integração com IPC do Quickshell para abrir/fechar
    IpcHandler {
        target: "kali-launcher"
        onMessage: msg => {
            if (msg === "toggle") {
                kaliLauncher.visible = !kaliLauncher.visible;
            } else if (msg === "open") {
                kaliLauncher.visible = true;
            } else if (msg === "close") {
                kaliLauncher.visible = false;
            }
        }
    }
}
```

### 4.2. Configurar Atalho Global no Hyprland (`hyprland.conf`)

Para invocar o launcher nativo do Quickshell através de um atalho do Hyprland:

```ini
# ~/.config/hypr/hyprland.conf

# Abrir / alternar launcher nativo Quickshell via IPC
bind = $mainMod, K, exec, quickshell ipc call kali-launcher toggle

# Alternativa: se preferir usar o launcher dinâmico Rofi como fallback:
# bind = $mainMod SHIFT, K, exec, kali-ormachy-rofi
```

---

## 5. Recursos de Usabilidade

- **Busca em Tempo Real:** Conforme o usuário digita na barra de pesquisa, as ferramentas são filtradas instantaneamente por nome, binário, descrição ou presets em todas as categorias.
- **Navegação Rápida:** Pressione `Esc` para fechar a qualquer momento ou limpar a busca. Clicar fora do cartão principal (no fundo translúcido) também fecha a janela suavemente.
- **Teclado:** Ao abrir a janela, o campo de busca ganha foco imediatamente. Pressionar `Enter` executa automaticamente a primeira ferramenta correspondente nos resultados.
- **Presets Interativos:** Cada preset configurado na ferramenta é exibido como um chip clicável. Clicar diretamente no chip dispara o preset específico.
- **Alerta de Ferramentas Ausentes:** Ferramentas não instaladas exibem um badge `✗ Não instalado` e um botão direto para instalação (`sudo pacman -S <pacote>`).

---

## 6. Customização e Paleta de Cores

O widget utiliza a paleta oficial **Catppuccin Mocha / Omarchy**:

| Variável / Propriedade | Cor Padrão | Descrição |
| :--- | :--- | :--- |
| `mochaBase` | `#1e1e2e` | Fundo de painéis e cards internos |
| `mochaMantle` | `#181825` | Fundo da janela principal |
| `mochaCrust` | `#11111b` | Fundo do scrim/backdrop |
| `mochaSurface0` | `#313244` | Bordas e divisores |
| `mochaBlue` | `#89b4fa` | Cor de destaque primária / seleção ativa |
| `mochaGreen` | `#a6e3a1` | Badge de ferramenta instalada |
| `mochaRed` | `#f38ba8` | Badge de ferramenta ausente |
| `mochaMauve` | `#cba6f7` | Indicador de ferramenta GUI |

Todas as cores e dimensões podem ser customizadas diretamente nas propriedades QML do componente raiz [`KaliLauncher.qml`](file:///home/JoaoVictor/dados/plugins/kali-ormachy/quickshell/KaliLauncher.qml).
