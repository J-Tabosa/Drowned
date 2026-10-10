# Passivas, habilidades e trilha dinâmica

Atualização de 9 de outubro de 2026. Integra as duas melhorias de interface
do GitHub (`5890303`) com os inimigos animados, navegação e feedback locais.
O merge conserva ambos os históricos; o conflito do HUD foi resolvido mantendo
o layout compacto, as missões recolhíveis e os avisos de combate.

## Controles

- WASD / setas: mover. Ctrl: correr.
- Espaço / J / clique esquerdo: segure para repetir o ataque, mirando no cursor.
- Shift: esquiva curta. E: investigar ecos opcionais. Veja [`gameplay_rhythm.md`](gameplay_rhythm.md).
- **Q / botão direito: habilidade especial**, com recarga independente.
- Esc: pausa. Configurações: volume da música, névoa e velocidade dos diálogos.
- Tab: árvore de habilidades do personagem; evolução permanente por XP do boss.
- Passe o cursor sobre a passiva ou especial na seleção e no HUD para ler os efeitos.

## Personagens

| Personagem | Passiva | Especial |
| --- | --- | --- |
| Quebra-Mar | **Maré de Ferro**: cada acerto de âncora adiciona uma carga de +10% de dano, até 3. As cargas duram 8 s desde o último acerto. Golpes no vazio não geram cargas. | **Âncora Giratória**: atinge inimigos num raio de 210, causando 90 de dano +15 por carga consumida, com forte recuo. Recarga: 7 s. |
| Vigia | **Mira Firme**: ficar parada por 1,2 s prepara o próximo ataque normal para +25% de dano e perfuração de 2 alvos. Movimento ou recuo cancela a preparação. | **Salva de Arpões**: 5 disparos em leque, 22 de dano cada; cada arpão atravessa até 3 alvos, acertando cada alvo apenas uma vez. Recarga: 6 s. |
| Mergulhador | **Segundo Fôlego**: acertar o retorno de um mergulho cura 6 de vida e concede +20% de velocidade por 2 s. A cura ocorre uma vez por mergulho, mesmo atingindo vários inimigos. | **Correnteza Abissal**: cria uma área no cursor, até 360 de distância; 5 pulsos espaçados em 0,65 s atingem um raio de 210, causando 16 de dano por pulso e puxando os inimigos. Recarga: 8 s. |

Ataques em área e arpões respeitam paredes e portões fechados. A habilidade não
interrompe ataques em andamento nem pode ser usada durante mergulho, morte ou
cinemáticas. As recargas e efeitos congelam na pausa. O HUD mostra as duas
recargas e o estado da passiva.

## Música

Composição instrumental original feita para o projeto, sem samples ou músicas
externas: **72 BPM, ré menor, 16 compassos, loop estéreo de 53,33 segundos**.
As três camadas começam juntas e permanecem sincronizadas:

- `assets/audio/music/cavern.wav`: sub-baixo lento e drones graves com tensão cromática, sem sinos ou arpejos agudos, nas cavernas, título, seleção e diálogos.
- `assets/audio/music/waves_drums.wav`: bumbo pesado e caixa entram no início dos confrontos.
- `assets/audio/music/boss_guitar.wav`: riff grave de guitarra elétrica sintetizada, com distorção, abafamento e power chords; entra junto de bateria mais presente na sala do Guardião.

As transições duram 1,5 s. Depois das ondas, a revelação retorna ao ambiente
calmo; ao entrar na sala do chefe, a guitarra entra antes da apresentação.
Derrota, vitória, saída após o chefe e retorno à seleção restauram a base calma.
O volume persiste em `user://preferences.cfg`; zero silencia todas as camadas.
A música continua nos diálogos enquanto o combate está pausado; o menu de
pausa suspende o áudio. O baixo usa notas fundamentais profundas e harmônicos
audíveis para criar tensão. No boss, o mix reduz o drone e destaca guitarra e bateria.

Para recriar os WAVs: `python tools/compose_soundtrack.py` (requer NumPy).
Os WAVs e suas configurações de importação estão incluídos no repositório;
Python não é necessário para jogar. A importação usa PCM de 16 bits para manter
os limites do loop idênticos em todas as camadas.

## Validação

Godot 4.7.2. Os scripts ficam em `tools/validators/` e podem ser executados com
`godot --headless --path . --script res://tools/validators/NOME.gd`:

- `abilities_music_test.gd`: acertos reais, cargas e expiração, cura única,
  perfuração, cinco arpões, cinco pulsos, recarga, bloqueio de controles,
  morte, pausa, limites dos loops, camadas por contexto e volume zero.
- `combat_smoke_test_v2.gd`: os três personagens, três ondas, Guardião, chaves e conclusão do prólogo.
- `enemy_smoke_test.gd`, `map_world_smoke_test.gd`, `feedback_smoke_test.gd`, `dialogue_smoke_test.gd`: regressões da integração.
- `ui_experience_test.gd`: seleção, HUD, missão recolhível, diálogos e configurações em diferentes resoluções.

Para capturas visuais, execute o último teste sem `--headless`, com a variável
`DROWNED_UI_CAPTURE=1`. As imagens ficam em `.godot/ui_review/`.
