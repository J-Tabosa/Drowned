# Abertura e apresentação dos diálogos

Atualização de 6 de outubro de 2026.

## Fluxo inicial

`title_screen.tscn` é a nova cena inicial: mar azul em pixel art e o trio num
pequeno barco pesqueiro. Água, espuma e balanço do barco formam um loop de
4,8 s. A animação é renderizada numa SubViewport de baixa resolução, ampliada
com filtro nearest. A exportação GIF está em
`assets/art/title/fishing_boat_loop.gif` (48 quadros, 100 ms por quadro).

Jogar inicia 2,6 s de mudança de clima: escurecimento do céu e do mar, balanço
mais forte, chuva, relâmpagos e dois sons de trovão sintetizados. Em seguida,
um fade de 0,65 s cobre a passagem para a seleção.

A seleção mostra somente três cards, cada um com o retrato grande, os nomes
da passiva e do especial, seus efeitos ao passar o cursor, e Escolher. Não
há títulos, explicações, controles fora dos cards ou faixa azul superior.
Setas e Enter continuam funcionando, com foco visível.

## Transições

O autoload `SceneTransition` mantém uma cortina preta acima dos diálogos e
sobrevive à liberação da cena anterior. Solicita a próxima cena em segundo
plano, cobre a imagem antes de trocar, aguarda a montagem da nova cena e
revela o resultado. Escolha → introdução e introdução → partida usam fades
de 0,45 s; cliques repetidos e confirmações durante o fade são ignorados.
O diálogo introdutório começa quando a cortina termina de abrir. Assim a
troca nunca expõe o fundo cinza do viewport.

## Diálogos

A moldura agora corresponde à área solicitada na captura de referência:
70% da largura, 41% da altura, centralizada horizontalmente, com o topo a
56% e o fundo a 97% da tela. Os retratos são maiores, ocupando slots de 34%
da largura e 78% da altura, e ficam parcialmente atrás do painel.

Quando alguém à esquerda fala, o sprite central olha para a esquerda;
quando alguém à direita fala, olha para a direita. Ao falar, conserva a
última direção. A posição da boca acompanha o flip. A faixa azul foi ocultada.

Todos os diálogos têm um ambiente de caverna submarina em pixel art. Algas
nas bordas balançam suavemente, e gotas nascem com intervalos entre 4,5 e
8,5 s (primeira gota em 4,2 s). Esse ambiente continua animando enquanto
o mundo jogável está pausado. As velocidades de texto e o comando de pular
preservam seu comportamento anterior.

## Artes e reprodução

Artes geradas pelo **ImageGen integrado**:

- `assets/art/title/blue_sea.png`: mar azul e céu claro.
- `assets/art/title/fishing_boat_trio.png`: barco com trio, fundo transparente.
- `assets/art/dialogue/underwater_cave.png`: caverna submarina.

Os prompts completos e os destinos estão em `docs/art_generation.json`.
Os PNGs estão incluídos no repositório; nenhum arquivo externo é necessário
para jogar. A tempestade, os movimentos, algas e gotas são animados no Godot.

Para reproduzir o GIF, execute o teste gráfico
`tools/validators/title_visual_check.gd` e depois
`python tools/export_title_gif.py` (requer Pillow). O Python apenas codifica
os quadros renderizados pelo jogo. As capturas ficam em `.godot/title_review/`.

Validações principais:

- `title_flow_test.gd`: sequência completa, clique duplo, proporções, flip,
  animação e música durante o diálogo, gotas e pausa do menu.
- `title_visual_check.gd`: capturas do título calmo, tempestade, seleção e
  diálogo olhando para ambos os lados; exportação dos quadros do GIF.
- `ui_experience_test.gd`: resoluções, cards, HUD, missões e velocidades de texto.
- `dialogue_smoke_test.gd`, `combat_smoke_test_v2.gd`,
  `abilities_music_test.gd`, `feedback_smoke_test.gd`: regressões de leitura,
  progressão, personagens, música e pausa.
