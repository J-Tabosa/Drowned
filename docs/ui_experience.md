# Interface náutica e experiência de leitura

Implementação dos dois itens de UI & User Experience fornecidos em 29/09/2026.
O arquivo docs/MELHORIAS.md referenciado pelo gerador de documentos não está na main consultada; este registro não substitui o backlog original.

## Sistema visual

- Moldura gerada pelo ImageGen, integrada em assets/ui/nautical_panel.png como textura de nove fatias, reduzida em memória com filtro nearest para conservar pixels e bordas pequenas.
- Fundo azul profundo, detalhes de latão, ícones de bússola e texto claro. Saúde usa vermelho estável; identidade e recarga usam coral para Quebra-Mar, dourado para Vigia e ciano para Mergulhador.
- Tema compartilhado por HUD, pausa, configurações, resultados, seleção e diálogos, com estados de botão normal, hover, pressionado e foco visível.
- HUD compacta com tamanho físico estável: personagem, vida e habilidade à esquerda; tutorial e chefe na faixa inferior direita; resultado ocupa o centro e oculta a HUD. Missão no topo, exibida por 5 segundos a cada atualização. Depois recolhe, reabrindo ao passar o mouse na aba “Missão” ou clicando para fixar; novo clique recolhe.
- Viewport de referência 960×540 com expansão para outras proporções. Contêineres fazem quebra de palavras; objetivos, instruções, resultados e falas extensas têm rolagem, sem reduzir a fonte para acomodar texto.

A seleção mantém os três cartões e botões alinhados na tela, sem rolagem. Em
6/10/2026, títulos, guias, descrições e faixa superior foram removidos; os cards
mantêm os retratos grandes, a passiva, o especial e o botão Escolher. A caixa
de diálogo ocupa 70% da largura e 41% da altura, começando em 56% da tela,
com texto extenso acessível por rolagem. Os retratos ocupam 78% da altura e o
personagem central vira para acompanhar o falante. Veja
[`title_and_dialogue.md`](title_and_dialogue.md) para a abertura e os fades.

## Leitura

- Quatro velocidades: lenta (22 caracteres/s), normal (42), rápida (75), instantânea.
- Preferência salva em user://preferences.cfg, alterada exclusivamente na pausa → Configurações. O diálogo lê a preferência salva sem exibir o seletor.
- Enter/Espaço revela a fala e depois avança; clique no texto também confirma.
- Esc encerra a sequência completa; seu aviso aparece como texto discreto com 45% de opacidade, sem botão. Um pedido durante a entrada aguarda o término da transição e restaura o estado anterior de pausa.
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

O teste de UI cobre janelas de 640×360, 960×540, 1152×648, 1920×1080 e 800×1000, separação dos painéis, texto extenso acessível por rolagem, cores de recarga dos três personagens, quatro velocidades e restauração da pausa ao pular. Também verifica cartões/botões inteiros sem rolagem, tamanho estável da HUD, missão recolhendo após 5 segundos, hover e clique para fixar/desfixar, e ausência de botões/seletor no diálogo. Capturas ficam em .godot/ui_review e não são versionadas.

Prompt do asset (geração nativa ImageGen): “Production game UI panel texture for Drowned, a nautical underwater pixel-art RPG. One blank rectangular nine-slice panel, front view, axis aligned. Crisp chunky pixel art, midnight navy empty center, oxidized brass double border, turquoise accents, angular rope knots at corners and a compass diamond at top center. Edge-to-edge panel, no text, bars, characters or scene. Border-only decoration so center can stretch. Restrained 16-bit naval navigation instrument aesthetic.”
