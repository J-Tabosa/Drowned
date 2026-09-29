# Interface náutica e experiência de leitura

Implementação dos dois itens de UI & User Experience fornecidos em 29/09/2026.
O arquivo docs/MELHORIAS.md referenciado pelo gerador de documentos não está na main consultada; este registro não substitui o backlog original.

## Sistema visual

- Moldura gerada pelo ImageGen, integrada em assets/ui/nautical_panel.png como textura de nove fatias, reduzida em memória com filtro nearest para conservar pixels e bordas pequenas.
- Fundo azul profundo, detalhes de latão, ícones de bússola e texto claro. Saúde usa vermelho estável; identidade e recarga usam coral para Quebra-Mar, dourado para Vigia e ciano para Mergulhador.
- Tema compartilhado por HUD, pausa, configurações, resultados, seleção e diálogos, com estados de botão normal, hover, pressionado e foco visível.
- Informações permanentes na faixa esquerda: personagem, vida, habilidade e objetivo. Tutorial e chefe na faixa inferior direita; resultado ocupa o centro e oculta a HUD.
- Viewport de referência 960×540 com expansão para outras proporções. Contêineres fazem quebra de palavras; objetivos, instruções, resultados e falas extensas têm rolagem, sem reduzir a fonte para acomodar texto.

## Leitura

- Quatro velocidades: lenta (22 caracteres/s), normal (42), rápida (75), instantânea.
- Preferência salva em user://preferences.cfg, disponível na conversa inicial e na pausa → Configurações.
- Enter/Espaço revela a fala e depois avança; clique no texto também confirma.
- Botão “Pular diálogo” ou Esc encerra a sequência completa. Um pedido durante a entrada aguarda o término da transição e restaura o estado anterior de pausa.
- Roda do mouse/barra de rolagem e Page Up/Page Down permitem ler falas maiores que o espaço disponível.

## Validação

Com Godot 4.5.2:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/validators/dialogue_smoke_test.gd
godot --headless --path . --script tools/validators/combat_smoke_test_v2.gd
godot --headless --path . --script tools/validators/ui_experience_test.gd
DROWNED_UI_CAPTURE=1 godot --path . --script tools/validators/ui_experience_test.gd
```

O teste de UI cobre janelas de 640×360, 960×540, 1152×648, 1920×1080 e 800×1000, separação dos painéis, texto extenso acessível por rolagem, cores de recarga dos três personagens, quatro velocidades e restauração da pausa ao pular. Capturas ficam em .godot/ui_review e não são versionadas.

Prompt do asset (geração nativa ImageGen): “Production game UI panel texture for Drowned, a nautical underwater pixel-art RPG. One blank rectangular nine-slice panel, front view, axis aligned. Crisp chunky pixel art, midnight navy empty center, oxidized brass double border, turquoise accents, angular rope knots at corners and a compass diamond at top center. Edge-to-edge panel, no text, bars, characters or scene. Border-only decoration so center can stretch. Restrained 16-bit naval navigation instrument aesthetic.”
