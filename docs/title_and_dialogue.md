# Abertura e apresentação dos diálogos

Revisão de 6 de outubro de 2026.

## Menu e abertura

A cena inicial `title_screen.tscn` mostra um barco pesqueiro vazio pela popa,
com convés, cabine, cordas, barris e casco de madeira. O barco balança em um
céu claro. À esquerda, a moldura náutica existente reúne **Jogar**,
**Configurações**, **Créditos** e **Sair**, com navegação por teclado e foco
visível. O título usa uma fonte serifada compacta com contorno escuro.

Configurações permite alterar a velocidade dos diálogos e o volume da música;
as duas preferências são salvas em `user://preferences.cfg`. Créditos abre
um painel próprio. Voltar ou Esc fecha os painéis e devolve o foco ao menu.

Jogar inicia 2,6 segundos de tempestade: céu e mar escurecem, o balanço se
intensifica, começa a chuva com som ambiente e dois trovões com relâmpagos.
O menu desaparece, e um fade de 0,65 segundo leva à seleção de personagens.
A sequência ignora entradas repetidas. A navegação posterior e os fades
entre seleção, introdução e partida continuam no autoload `SceneTransition`.

Durante a partida, Esc abre a pausa. Além de retornar à seleção de personagens,
o botão **Voltar à tela inicial** encerra a partida com fade, restaura a árvore
sem pausa e retorna ao barco e ao menu de abertura. A trilha ambiente já toca
na abertura; ao voltar da pausa, ela retoma respeitando o volume salvo.

## Apresentação do Guardião

O cartão mostrado ao entrar na sala usa a mesma sprite sheet do Guardião
Abissal usada no combate. A primeira linha de seis quadros é animada como
repouso, com transparência e filtro nearest. Cabeça e corpo provisórios em
retângulos foram removidos. A sprite mantém a proporção em resoluções distintas,
junto do nome, classificação e descrição do encontro. O Guardião permanece
inativo até a apresentação terminar; sua barra de vida e combate seguem intactos.

## Arte compacta e camadas

As artes foram criadas com o gerador de imagens integrado, usando a referência
de rochas em pixel art para orientar os blocos de cor e o nível de detalhe.
Somente as versões reduzidas e com paleta limitada entram no jogo:

| Arquivo em `assets/art/` | Resolução |
| --- | --- |
| `title/clear_sky.png` | 320 × 180 |
| `title/boat_stern.png` | 104 × 128 |
| `title/cloud.png` | 80 × 24 |
| `title/water_tile.png` | 160 × 64 |
| `dialogue/cave_crystals.png` | 320 × 180 |
| `dialogue/kelp.png` | 20 × 36 |

Os seis PNGs somam aproximadamente 41 KB. Os prompts estão em
`docs/title_art_prompts.json`, e a procedência está em `docs/art_generation.json`.
A fonte DejaVu Serif Bold foi reduzida aos caracteres do título; a licença
acompanha o arquivo em `assets/fonts/`.

A SubViewport de 320 × 180 usa filtro nearest. A imagem conserva a proporção
em telas largas. A ordem das camadas é céu → nuvens distantes → nuvens próximas
→ água distante → água intermediária → barco → água da frente → chuva/raios.
Nuvens deslizam em velocidades distintas; as três águas têm amplitude,
escala de textura e fase próprias. A água da frente oculta a linha de flutuação.
O balanço do barco completa um ciclo em 4,8 segundos. O GIF exportado é uma
prévia; a cena usa as camadas reais, não reproduz o GIF como fundo.

## Caverna dos diálogos

O fundo de todos os diálogos é uma caverna inundada em pixel art, com rochas
facetadas e profundidade discreta. Três pequenos grupos de cristais iluminam
somente seus arredores. Algas nas bordas se curvam linha a linha mantendo as
raízes fixas. Gotas nascem nas pontas de rocha em intervalos de 4,5 a 8,5 segundos
(primeira em 4,2 segundos), caem e formam pequenas ondulações no piso inundado.
A animação continua enquanto o mundo está pausado pelo diálogo.

A caixa ocupa 70% da largura e 41% da altura. Retratos, direção do olhar,
cores por personagem, velocidade do texto nas configurações e Esc para pular
mantêm o comportamento existente.

## Áudio de ações

`gameplay_feedback.gd` não gera mais os bipes senoidais nem o tom genérico para
um evento desconhecido. Pronto, bloqueado, missão concluída e aviso do chefe
permanecem visuais. Golpes, passagem de ar, dano, água, coleta e portões usam
apenas ruído filtrado com duração e envelope próprios. O mergulho dispara seu
som uma vez, sem duplicação pela indicação de invulnerabilidade.

## Validação

- `boss_presentation_and_menu_test.gd`: sprite real animada na entrada da sala,
  início da luta após o cartão, Esc, retorno à abertura com fade e música
  retomada; capturas do cartão e pausa em 640×360 e 1152×648 quando
  `DROWNED_FLOW_CAPTURE=1`.
- `title_flow_test.gd`: menu em 640×360, 960×540, 1280×720 e 1920×1080;
  configurações, créditos, barco sem personagens, balanço, chuva, tempestade,
  seleção, diálogos, gotas e pausa.
- `title_visual_check.gd`: capturas do menu, configurações, créditos,
  tempestade, seleção e diálogos; quadros da prévia GIF.
- `feedback_smoke_test.gd`: notificações silenciosas, ações com som e regressões
  de combate, coleta, recarga e pausa.
- `dialogue_smoke_test.gd`, `ui_experience_test.gd` e `combat_smoke_test_v2.gd`:
  leitura, proporções, controles e progressão.

Para exportar o GIF, execute o validador gráfico e depois
`python tools/export_title_gif.py`. As capturas temporárias ficam em
`.godot/title_review/`.
