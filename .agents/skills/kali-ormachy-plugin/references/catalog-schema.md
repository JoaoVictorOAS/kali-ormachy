# Catálogo de Ferramentas e Esquema de Dados

Este documento descreve o esquema de dados do catálogo de ferramentas e o mapeamento das 6 categorias principais para pacotes nativos do Arch / BlackArch.

---

## Estrutura do Esquema (TOML)

```toml
[general]
terminal = "auto" # auto ($TERMINAL -> kitty -> foot -> alacritty) ou explícito
hold_session = true
notify_on_missing = true

[[categories]]
id = "recon"
name = "Reconhecimento & OSINT"
icon = "󰛐"

[[categories.tools]]
name = "Nmap"
binary = "nmap"
package = "nmap"
mode = "terminal"
description = "Scanner de portas e auditoria de rede"
presets = [
  { name = "Varredura Rápida de Portas", cmd = "nmap -T4 -F {target}" },
  { name = "Scan Completo com Scripts Padrão", cmd = "nmap -sC -sV -p- -T4 {target}" },
  { name = "Detecção de Versão e SO", cmd = "nmap -sV -O {target}" }
]
params = [
  { key = "target", prompt = "Alvo (IP ou Domínio):", default = "127.0.0.1" }
]

[[categories.tools]]
name = "Masscan"
binary = "masscan"
package = "masscan"
mode = "terminal"
description = "Scanner de portas de alta velocidade"
presets = [
  { name = "Scan Rápido Top 100 Portas", cmd = "sudo masscan {target} --top-ports 100 --rate 10000" }
]
params = [
  { key = "target", prompt = "Alvo (IP ou Subnet CIDR):", default = "" }
]

[[categories.tools]]
name = "theHarvester"
binary = "theHarvester"
package = "theharvester"
mode = "terminal"
description = "Coleta de e-mails, subdomínios e IPs via OSINT"
presets = [
  { name = "Busca Geral em Fontes Públicas", cmd = "theHarvester -d {domain} -b all" }
]
params = [
  { key = "domain", prompt = "Domínio alvo:", default = "" }
]

[[categories.tools]]
name = "Amass"
binary = "amass"
package = "amass"
mode = "terminal"
description = "Mapeamento e enumeração de superfície de ataque"
presets = [
  { name = "Enumeração Passiva de Subdomínios", cmd = "amass enum -passive -d {domain}" }
]
params = [
  { key = "domain", prompt = "Domínio alvo:", default = "" }
]

[[categories.tools]]
name = "Maltego"
binary = "maltego"
package = "maltego"
mode = "gui"
description = "Plataforma gráfica de inteligência e OSINT"
presets = []
params = []

# --- Auditoria Web ---
[[categories]]
id = "web"
name = "Auditoria Web"
icon = "󰖟"

[[categories.tools]]
name = "Burp Suite"
binary = "burpsuite"
package = "burpsuite"
mode = "gui"
description = "Proxy de interceptação e auditoria web avançada"

[[categories.tools]]
name = "OWASP ZAP"
binary = "zaproxy"
package = "zaproxy"
mode = "gui"
description = "Scanner de vulnerabilidades web da OWASP"

[[categories.tools]]
name = "ffuf"
binary = "ffuf"
package = "ffuf"
mode = "terminal"
description = "Fuzzing rápido de diretórios e parâmetros web"
presets = [
  { name = "Fuzzing Básico de Diretórios", cmd = "ffuf -u {url}/FUZZ -w /usr/share/wordlists/dirb/common.txt" },
  { name = "Fuzzing com Extensões (.php,.html,.js)", cmd = "ffuf -u {url}/FUZZ -w /usr/share/wordlists/dirb/common.txt -e .php,.html,.js" }
]
params = [
  { key = "url", prompt = "URL Base (ex: http://alvo.local):", default = "http://" }
]

[[categories.tools]]
name = "Gobuster"
binary = "gobuster"
package = "gobuster"
mode = "terminal"
description = "Enumeração de diretórios e DNS em Go"
presets = [
  { name = "Enumeração de Diretórios", cmd = "gobuster dir -u {url} -w /usr/share/wordlists/dirb/common.txt" }
]
params = [
  { key = "url", prompt = "URL Alvo:", default = "http://" }
]

[[categories.tools]]
name = "Nikto"
binary = "nikto"
package = "nikto"
mode = "terminal"
description = "Scanner de servidores e configurações web inseguras"
presets = [
  { name = "Varredura Padrão", cmd = "nikto -h {target}" }
]
params = [
  { key = "target", prompt = "Host / URL alvo:", default = "" }
]

[[categories.tools]]
name = "WPScan"
binary = "wpscan"
package = "wpscan"
mode = "terminal"
description = "Auditoria de segurança e plugins em WordPress"
presets = [
  { name = "Scan Básico de Temas e Plugins Vulneráveis", cmd = "wpscan --url {url} --enumerate vp,vt" }
]
params = [
  { key = "url", prompt = "URL do WordPress:", default = "http://" }
]

[[categories.tools]]
name = "sqlmap"
binary = "sqlmap"
package = "sqlmap"
mode = "terminal"
description = "Detecção e exploração automatizada de SQL Injection"
presets = [
  { name = "Scan com Batch Mode", cmd = "sqlmap -u \"{url}\" --batch --dbs" }
]
params = [
  { key = "url", prompt = "URL com parâmetro (ex: http://alvo/item?id=1):", default = "" }
]

# --- Redes & Wi-Fi ---
[[categories]]
id = "network"
name = "Redes & Wi-Fi"
icon = "󰛳"

[[categories.tools]]
name = "Wireshark"
binary = "wireshark"
package = "wireshark-qt"
mode = "gui"
description = "Analisador de pacotes de rede em tempo real"

[[categories.tools]]
name = "Aircrack-ng"
binary = "aircrack-ng"
package = "aircrack-ng"
mode = "terminal"
description = "Suite de auditoria de redes 802.11"
presets = [
  { name = "Crack de Captura .cap", cmd = "aircrack-ng -w /usr/share/wordlists/rockyou.txt {capfile}" }
]
params = [
  { key = "capfile", prompt = "Caminho do arquivo .cap:", default = "" }
]

[[categories.tools]]
name = "Bettercap"
binary = "bettercap"
package = "bettercap"
mode = "terminal"
description = "Framework de ataque MITM e reconhecimento de rede"
presets = [
  { name = "Iniciar Sessão Interativa", cmd = "sudo bettercap -iface {interface}" }
]
params = [
  { key = "interface", prompt = "Interface de rede (ex: wlan0, eth0):", default = "wlan0" }
]

[[categories.tools]]
name = "Kismet"
binary = "kismet"
package = "kismet"
mode = "terminal"
description = "Detector e sniffer wireless"
presets = [
  { name = "Iniciar Kismet Server", cmd = "kismet -c {interface}" }
]
params = [
  { key = "interface", prompt = "Interface sem fio:", default = "wlan0" }
]

[[categories.tools]]
name = "Responder"
binary = "responder"
package = "responder"
mode = "terminal"
description = "Poisoner LLMNR, NBT-NS e MDNS para redes Windows"
presets = [
  { name = "Modo Análise (Passive)", cmd = "sudo responder -I {interface} -A" },
  { name = "Poisoning Ativo", cmd = "sudo responder -I {interface} -rdwv" }
]
params = [
  { key = "interface", prompt = "Interface de rede:", default = "eth0" }
]

# --- Quebra de Senhas & Hashes ---
[[categories]]
id = "passwords"
name = "Quebra de Senhas & Hashes"
icon = "󰌋"

[[categories.tools]]
name = "John the Ripper"
binary = "john"
package = "john"
mode = "terminal"
description = "Quebrador de senhas e hashes multipropósito"
presets = [
  { name = "Quebra com Wordlist Padrão", cmd = "john --wordlist=/usr/share/wordlists/rockyou.txt {hashfile}" }
]
params = [
  { key = "hashfile", prompt = "Arquivo com hashes:", default = "" }
]

[[categories.tools]]
name = "Hashcat"
binary = "hashcat"
package = "hashcat"
mode = "terminal"
description = "Recuperador de senhas acelerado por GPU"
presets = [
  { name = "Benchmark de Algoritmos", cmd = "hashcat -b" }
]

[[categories.tools]]
name = "Hydra"
binary = "hydra"
package = "hydra"
mode = "terminal"
description = "Testador de força bruta rápido para protocolos de rede"
presets = [
  { name = "Brute Force SSH", cmd = "hydra -l {user} -P /usr/share/wordlists/rockyou.txt {target} ssh" }
]
params = [
  { key = "target", prompt = "Alvo (IP/Host):", default = "" },
  { key = "user", prompt = "Usuário:", default = "admin" }
]

# --- Engenharia Reversa & Binários ---
[[categories]]
id = "reverse"
name = "Engenharia Reversa"
icon = "󰘔"

[[categories.tools]]
name = "Ghidra"
binary = "ghidra"
package = "ghidra"
mode = "gui"
description = "Suite de descompilação e análise estática da NSA"

[[categories.tools]]
name = "Radare2"
binary = "r2"
package = "radare2"
mode = "terminal"
description = "Framework de linha de comando para análise reversa e depuração"
presets = [
  { name = "Analisar Binário", cmd = "r2 -A {binary_path}" }
]
params = [
  { key = "binary_path", prompt = "Caminho do binário:", default = "" }
]

[[categories.tools]]
name = "GDB"
binary = "gdb"
package = "gdb"
mode = "terminal"
description = "GNU Debugger"
presets = [
  { name = "Depurar Binário", cmd = "gdb -q {binary_path}" }
]
params = [
  { key = "binary_path", prompt = "Caminho do binário:", default = "" }
]

# --- Forense & Resposta ---
[[categories]]
id = "forensics"
name = "Forense & Resposta"
icon = "󰈔"

[[categories.tools]]
name = "Volatility"
binary = "vol"
package = "volatility3"
mode = "terminal"
description = "Framework avançado de análise de memória RAM"
presets = [
  { name = "Listar Processos (Windows pslist)", cmd = "vol -f {dump} windows.pslist" }
]
params = [
  { key = "dump", prompt = "Arquivo dump de memória (.raw/.vmem):", default = "" }
]

[[categories.tools]]
name = "Autopsy"
binary = "autopsy"
package = "autopsy"
mode = "gui"
description = "Plataforma gráfica forense digital de sistemas de arquivos"

[[categories.tools]]
name = "The Sleuth Kit"
binary = "fls"
package = "sleuthkit"
mode = "terminal"
description = "Ferramentas forenses de análise de volume e disco"
presets = [
  { name = "Listar Arquivos de Imagem de Disco", cmd = "fls -r {image}" }
]
params = [
  { key = "image", prompt = "Imagem de disco (.dd/.raw):", default = "" }
]
```
