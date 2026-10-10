# Ritmo do prólogo

A partida alterna pequenos confrontos no caminho, três ondas com composição distinta e o Guardião. Movimento abre a primeira passagem após 220 unidades; corrida, ataque e os três ecos deixam de ser requisitos para prosseguir. A narrativa inicial e a apresentação do chefe continuam no fluxo. Em 9/10/2026, as escolhas entre ondas foram movidas para árvores permanentes por personagem; Tab abre a árvore e só o primeiro boss concede XP. Veja [skill_trees_and_boss.md](skill_trees_and_boss.md).

## Controles e decisões

- WASD / setas: mover; Ctrl: correr; **Shift: esquiva** de 0,18 s, invulnerável, com recarga de 1,1 s. Não atravessa paredes nem portões e não interrompe ataques ou especiais.
- Segure Espaço / J / clique esquerdo para continuar atacando na cadência do personagem. Q / botão direito mantém o especial independente.
- **E perto de um eco** investiga a história opcional, cura 10 e recarrega o especial. Requer caminho livre de inimigos; os ecos podem ser encontrados em qualquer ordem.
- Um pequeno indicador junto ao personagem segue os corredores e mostra a direção do próximo confronto, do chefe ou da saída.

## Encontros e recompensas

Duas emboscadas curtas ocupam o caminho até a câmara, e uma pequena guarda intercepta a aproximação ao fosso do chefe. Os inimigos da câmara aparecem perto do jogador, em piso aberto, saindo do chão em 0,9 s, com lama e revelação progressiva do sprite. A emergência congela na pausa e não usa nomes nem círculos. As ondas têm 4, 5 e 6 inimigos:

| Inimigo | Comportamento | Resposta do jogador |
| --- | --- | --- |
| Afogado | Persegue e anuncia golpes próximos | Acertar, afastar e usar área |
| Caçador | Mais rápido, menos vida, investida com faixa de aviso | Esquivar lateralmente; golpes interrompem a preparação |
| Pesado | Mais vida, movimento lento, golpe forte com antecipação longa | Aproveitar a abertura após o golpe; juntar alvos para o especial |

A cada dois inimigos comuns derrotados cai um orbe verde de fôlego. Ele é atraído dentro de 260 unidades, com rastro de partículas; respeita paredes, navegação e pausa. Ao chegar ao jogador, recupera 5 de vida e reduz a recarga do especial em 0,8 s. Expira após 24 s. Não concede XP de habilidade.

Após as duas primeiras ondas, o jogador recupera 12% de vida e o especial fica pronto. A próxima onda começa após uma breve pausa, sem menu obrigatório. As melhorias anteriores (+20% dano, -20% recarga e +25% vida) permanecem nos nós das árvores, compradas com XP e salvas entre partidas. Ao terminar a terceira onda, 20% de vida são recuperados e o especial fica pronto para o chefe. O resultado registra tempo, inimigos derrotados e habilidades aprendidas. O Guardião concede 100 XP, mas continua exigindo uma chave-bússola para abrir a saída.

## Verificação

`tools/validators/gameplay_rhythm_test.gd` cobre esquiva, portões, pausa, ataque mantido, ecos opcionais, emboscadas, emergência pausável, coleta, composição das ondas sem popup e XP do boss. `combat_smoke_test_v2.gd` mantém a regressão do prólogo completo. As capturas novas da árvore e do boss são geradas por `progression_visual_check.gd` em `.godot/progression_review/`.
