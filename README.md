# kali-ormachy

Launcher open source para ferramentas de segurança (Kali/BlackArch) integrado ao ecossistema Omarchy/Hyprland.

## Visão geral

O **kali-ormachy** busca oferecer um catálogo categorizado de ferramentas de pentest/auditoria com foco em:

- execução nativa no host (Arch/BlackArch);
- carregamento rápido de configuração;
- padronização de presets de comandos;
- base preparada para integração com menus como Rofi/Wofi.

## Status do projeto

Projeto em desenvolvimento inicial (MVP).  
Atualmente o repositório já inclui:

- modelos de dados do catálogo (`TOML`/`JSON`);
- carregamento de configuração padrão embutida e configuração customizada do usuário;
- verificação de binários no `$PATH`;
- geração de comando de instalação via `pacman`;
- suíte de testes cobrindo os módulos principais.

## Requisitos

- Rust (toolchain estável)
- Cargo

## Instalação

```bash
git clone https://github.com/JoaoVictorOAS/kali-ormachy.git
cd kali-ormachy
cargo build --release
```

## Uso

No estágio atual, o binário principal ainda está em fase de evolução.  
Você pode executar:

```bash
cargo run
```

Para validar o comportamento já implementado:

```bash
cargo test
```

## Configuração

- Configuração padrão do projeto:  
  `/home/runner/work/kali-ormachy/kali-ormachy/config.default.toml`
- Caminho esperado para configuração de usuário (runtime):  
  `~/.config/ormachy-kali/config.toml` ou `~/.config/ormachy-kali/config.json`

## Estrutura do repositório

- `src/models.rs`: estruturas de configuração/catálogo
- `src/config_loader.rs`: carregamento e parse de configuração
- `src/checker.rs`: validação de binários e comando de instalação
- `tests/`: testes automatizados

## Contribuindo

Contribuições são bem-vindas.

1. Faça um fork do projeto
2. Crie uma branch para sua alteração
3. Rode os testes (`cargo test`)
4. Abra um Pull Request descrevendo claramente a mudança

## Uso responsável

As ferramentas e presets deste projeto devem ser usados apenas em ambientes autorizados e dentro da legislação aplicável.

## Licença

Este repositório ainda não possui um arquivo de licença definido.  
Se você pretende reutilizar o código, abra uma issue para discutirmos a licença open source adequada (ex.: MIT, Apache-2.0 ou GPL).
