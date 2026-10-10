# Árvores, XP e primeiro boss

Revisão de 9 de outubro de 2026, sobre a main sincronizada em d37b1e8.
Mantém esquiva, ataque mantido, ecos opcionais, emboscadas, chaves e apresentação
do boss. As escolhas automáticas entre ondas foram realocadas para árvores.

## Progressão

Tab ou o botão no canto inferior esquerdo abre a árvore. Tab/Esc/Voltar fecha
e restaura a pausa. São três caminhos, com dois nós cada, por personagem:
ataque, passiva/especial e sobrevivência. Descrições e pré-requisitos ficam
visíveis; o painel tem rolagem para janelas pequenas.

Cada raiz custa 100 XP. O nó seguinte custa 150 XP e exige sua raiz.
O Guardião concede 100 XP uma vez por encontro vencido, permitindo aprender
uma raiz. Enfrentá-lo de novo numa nova partida permite continuar a progressão.
Não existem fontes de XP por inimigos comuns, ecos ou ondas. O crédito acontece
na derrota do boss, preservando a recompensa se o jogador sair antes das partículas.

XP e habilidades são independentes por personagem e persistem em
user://progression.cfg. Tentar novamente preserva a evolução. A compra valida
saldo, personagem, habilidade, pré-requisito e duplicação. Aplica a evolução
imediatamente, sem curar novamente ao reabrir o painel.

| Personagem | Ataque (raiz) | Passiva (raiz) | Sobrevivência (raiz) |
| --- | --- | --- | --- |
| Quebra-Mar | Giro Sustentado: segurar Q gira por até 2,1 s; 27 de dano a cada 0,35 s, raio 150, movimento a 65% | Maré Persistente: até 4 cargas por 12 s | Esquiva em 0,8 s |
| Vigia | Tiro Duplo: dois arpões paralelos, 65% de dano cada | Mira Penetrante: disparo preparado perfura 3 alvos | Esquiva em 0,8 s |
| Mergulhador | Dois Ecos: dois impactos após o retorno, 35% do dano base cada | Fôlego Renovado: cura 9 e acelera por 3 s | Esquiva em 0,8 s |

Os nós seguintes preservam Maré Cortante (+20% dano), Maré Veloz (-20% recarga
do especial) e Fôlego Profundo (+25% vida máxima). O giro não dá invulnerabilidade
e termina ao soltar Q, morrer ou bloquear controles. Os ecos são independentes
do especial e respeitam paredes.

## Recursos e surgimento

Os brilhos comuns são fôlego, não XP: a cada dois inimigos, um orbe verde recupera
5 de vida e reduz a recarga do especial em 0,8 s. Possui pixels claros, rastro e
atração acelerada dentro de 260 unidades; respeita paredes, rotas e pausa.
Expira em 24 s. O boss libera seis partículas douradas que seguem até o jogador.

Emboscadas e ondas surgem do chão em 0,9 s, com botas/torso/cabeça aparecendo
progressivamente e fragmentos de lama. Não exibem nome nem círculo de spawn.
Não atacam nem recebem dano durante a emergência. Pausa congela a animação.

## Guardião e equilíbrio

O Guardião usa uma criatura própria: colosso afogado de braços enormes,
mandíbula aberta e rochas nas costas, atlas de 64 pixels ampliado 3×.
O Pesado tem outro sprite, com grandes punhos, colete rasgado e correntes,
além do afogado comum. Todos têm repouso, caminhada, ataque, dano e morte.

O boss tem 1100 de vida, investida marcada, golpes próximos e rugidos.
Rugidos criam sombras angulares na posição do jogador e nos lados. Após o
aviso de 1,1 s (0,85 s na segunda fase), estalactites caem e causam 24/28 de dano.
As posições ficam travadas: mover-se deixa a área segura. Há recuperação entre
ataques. Abaixo de 50% de vida, o boss acelera e derruba até cinco estalactites
por rugido, em vez de três. Morte cancela perigos; pausa congela tudo.
O boss ignora empurrões para não ser mantido longe por tiros repetidos.
Inimigos próximos esperam durante a apresentação e retomam ao devolver o controle.

Vigia: dano normal 44 → 32; recarga 0,68 → 0,78 s; Mira Firme 0,9 → 1,2 s,
bônus 40% → 25%; leque 36 → 22 por arpão; velocidade 1480 → 1160 e recuo
300 → 100. Arpões têm alcance 820 e colidem com paredes. Tiro Duplo aumenta
o dano total em 30%, sem duplicar o dano integral.

A dificuldade é verificada por comportamento: ficar parado toma a estalactite,
sair da sombra evita o dano, a segunda fase aumenta pressão. Há também uma
simulação com IA e projéteis reais: a Vigia parada, atirando e usando leque,
perde antes de matar o boss. O ajuste numérico
ainda pode ser refinado com partidas humanas.

## Artes e validação

Sprites gerados com ImageGen integrado; fontes e prompts em
enemy_art_generation.json. O boss passou por extração de fundo pela mesma
ferramenta. O pipeline Godot registra pés e reduz poses para 64/96 pixels.
As fontes são afogado_pesado_sheet_source.png e colosso_afogado_sheet_source.png.

Testes: progression_boss_test.gd (XP, pré-requisitos, persistência, três evoluções,
orbes e perigos), gameplay_rhythm_test.gd (ondas sem popup), abilities_music_test.gd,
combat_smoke_test_v2.gd, enemy_smoke_test.gd, ui_experience_test.gd e apresentação.
progression_visual_check.gd registra árvore em 640×360, 1152×648 e 800×1000,
os dois inimigos, surgimento, rugido e partículas em .godot/progression_review/.
